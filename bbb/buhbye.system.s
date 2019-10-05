;;; Disassembly of BYE.SYSTEM (Bird's Better Bye)
;;; Modifications by Joshua Bell inexorabletash@gmail.com
;;; (so this is Bell's Better Bird's Better Bye - Buh-Bye)
;;;  * alpha key advances to next matching filename
;;;  * replaced directory enumeration (smaller, per PDTRM)
;;;  * installs, then chains to next .SYSTEM file

        .setcpu "65C02"
        .linecont +
        .feature string_escapes

        .include "apple2.inc"
        .include "apple2.mac"

        .include "../inc/apple2.inc"
        .include "../inc/macros.inc"
        .include "../inc/prodos.inc"
        .include "../inc/ascii.inc"

;;; ************************************************************
        .include "../inc/driver_preamble.inc"
;;; ************************************************************

;;; ------------------------------------------------------------

;;; ProDOS Technical Reference Manual, 5.1.5.2:
;;;
;;; ProDOS MLI call $65, the QUIT call, moves addresses $D100 through
;;; $D3FF from the second 4K bank of RAM of the language card to
;;; $1000, and executes a JMP to $1000. What initially resides in that
;;; area is Apple's dispatcher code.

;;; ------------------------------------------------------------
;;; Installer
;;; ------------------------------------------------------------

        max_size = $300

.proc maybe_install_driver

        src := install_src
        end := install_src + install_size
        dst := $D100            ; Install location in ProDOS (bank 2)

        src_ptr := $19
        dst_ptr := $1B

        sta     ALTZPOFF        ; TODO: Necessary?
        lda     ROMIN           ; write bank 2
        lda     ROMIN

        lda     #<src           ; src_ptr = src
        sta     src_ptr
        lda     #>src
        sta     src_ptr+1

        lda     #<dst           ; dst_ptr = dst
        sta     dst_ptr
        lda     #>dst
        sta     dst_ptr+1

loop:   lda     (src_ptr)       ; *src_ptr = *dst_ptr
        sta     (dst_ptr)

        inc     src_ptr         ; src_ptr++
        bne     :+
        inc     src_ptr+1

:       inc     dst_ptr         ; dst_ptr++
        bne     :+
        inc     dst_ptr+1

:       lda     src_ptr+1       ; src_ptr == end ?
        cmp     #>end
        bne     loop
        lda     src_ptr
        cmp     #<end
        bne     loop

        sta     ALTZPOFF        ; TODO: Necessary?
        sta     ROMINWB1
        sta     ROMINWB1

        rts
.endproc

;;; ------------------------------------------------------------
;;; Selector
;;; ------------------------------------------------------------

        install_src := *

        pushorg $1000
.proc selector

        prefix          := $280 ; length-prefixed

        filenames       := $1400 ; each is length + 15 bytes
        read_buffer     := $2000 ; Also, start location for launched SYS files

        ;; Device/Prefix enumeration
        next_device_num := $65  ; next device number to try
        prefix_depth    := $6B  ; 0 = root

        ;; Directory enumeration
        entry_pointer   := $60  ; 2 bytes
        block_entries   := $62
        active_entries  := $63  ; 2 bytes

        entry_length    := $6E
        entries_per_block := $6F
        file_count      := $70  ; 2 bytes

        ;; Found entries
        current_entry   := $67  ; index of current entry
        num_entries     := $68  ; length of |filenames| (max 128)
        curr_len        := $69  ; length of current entry name
        curr_ptr        := $6C  ; address of current entry name (in |filenames|)
        types_table     := $74  ; high bit clear = dir, set = sys

        ;; Entry display
        page_start      := $73  ; index of first entry shown on screen
        row_count       := $6A  ; number of rows in this page
        top_row         := 2    ; first row used on screen
        bottom_row      := 21   ; last row used on screen


;;; ------------------------------------------------------------

        cld                     ; ProDOS protocol for QUIT routine

        lda     #$A0
        jsr     SLOT3           ; Activate 80-Column Firmware

        ;; Update system bitmap
        ldx     #BITMAP_SIZE-1  ; zero it all out
:       stz     BITMAP,x
        dex
        bpl     :-
        inc     BITMAP+BITMAP_SIZE-1 ; protect ProDOS global page
        lda     #%11001111           ; protect zp, stack, text page 1
        sta     BITMAP

        ;; Find device
        lda     DEVCNT          ; max device num
        sta     next_device_num
        lda     DEVNUM
        bne     check_device

next_device:
        ldx     next_device_num
        lda     DEVLST,x
        cpx     #1
        bcs     :+
        ldx     DEVCNT
        inx
:       dex
        stx     next_device_num

check_device:
        sta     on_line_params_unit
        MLI_CALL ON_LINE, on_line_params
        bcs     next_device

        stz     prefix_depth
        lda     prefix+1
        and     #$0F
        beq     next_device
        adc     #2
        tax

        ;; Resize prefix to length x and open the directory for reading
.proc resize_prefix_and_open
        stx     prefix
        lda     #'/'
        sta     prefix+1        ; ensure prefix is at least '/'
        sta     prefix,x        ; and ends with '/'
        stz     prefix+1,x      ; and is null terminated

        stz     num_entries

;;; Enumerate directory
;;; Algorithm from ProDOS Technical Reference Manual B.2.5

        ;; Open the directory
        jsr     do_open
        bcc     :+

        ;; Open failed
fail:   lda     prefix_depth    ; root?
        beq     next_device
        jsr     pop_prefix      ; and go up a level
        bra     resize_prefix_and_open

        ;; Open succeeded
:       inc     prefix_depth

        ;; Read a block (512 bytes) into buffer
        stz     read_params_request
        lda     #2
        sta     read_params_request+1
        jsr     do_read
        bcs     fail

        ;; Store entry_length (byte), entries_per_block (byte), file_count (word)
        ldx     #3
:       lda     read_buffer + SubdirectoryHeader::entry_length,x
        sta     entry_length,x
        dex
        bpl     :-

        ;; Any entries?
        lda     file_count
        ora     file_count+1
        beq     close_dir

        ;; Skip header entry
        clc
        lda     #<(read_buffer+4) ; 4 bytes for prev/next pointers
        adc     entry_length
        sta     entry_pointer
        lda     #>(read_buffer+4)
        adc     #0              ; TODO: Can skip this if entry_length << 256
        sta     entry_pointer+1

        ;; Prepare to process entry two (first "entry" is header)
        lda     #2
        sta     block_entries

while_loop:
        ;; Check if entry is active
        lda     (entry_pointer)
        beq     done_entry

        ;; Check file type
        ldy     #FileEntry::file_type
        lda     (entry_pointer),y
        cmp     #FT_DIRECTORY
        beq     store_entry
        cmp     #FT_SYSTEM
        bne     done_active_entry

store_entry:
        ;; Store type
        ldx     num_entries
        sta     types_table,x

        ;; Copy name into |filenames|
        jsr     update_curr_ptr ; current entry in X
        ldy     #15             ; max name length (length byte copied too)
:       lda     (entry_pointer),y
        sta     (curr_ptr),y
        dey
        bpl     :-
        iny                     ; Y = 0; storage_type/name_length in A
        and     #%00001111      ; mask off name_length (remove storage_type)
        sta     (curr_ptr),y    ; store length

        inc     num_entries

done_active_entry:
        dec     file_count
        bpl     :+
        dec     file_count+1
:

done_entry:
        ;;  Seen all active entries?
        lda     file_count
        ora     file_count+1
        beq     close_dir

        ;; Seen all entries in this block?
        lda     block_entries
        cmp     entries_per_block
        bne     next_in_block

        ;; Grab next block
next_block:
        jsr     do_read         ; read another block
        bcs     fail

        lda     #1              ; first entry in non-key block
        sta     block_entries

        lda     #<(read_buffer+4) ; 4 bytes for prev/next pointers
        sta     entry_pointer
        lda     #>(read_buffer+4)
        sta     entry_pointer+1

        bra     end_while

        ;; Next entry in current block
next_in_block:
        clc
        lda     entry_pointer
        adc     entry_length
        sta     entry_pointer
        lda     entry_pointer+1
        adc     #0
        sta     entry_pointer+1

        inc     block_entries

end_while:
        ;; Check to see if we have room
        bit     num_entries     ; max is 128
        bpl     while_loop

close_dir:
        MLI_CALL CLOSE, close_params
        ;; fall through
.endproc

;;; ------------------------------------------------------------

.proc draw_screen
        jsr     SETTXT          ; TEXT
        jsr     HOME            ; HOME
        lda     #23             ; VTAB 23
        jsr     TABV

        ;; Print help text
        lda     #20             ; HTAB 20
        sta     CH
        ldy     #(help_string - text_resources)
        jsr     cout_string

        ;; Draw prefix
        jsr     home
        ldx     #0
:       lda     prefix+1,x
        beq     :+
        jsr     ascii_cout
        inx
        bne     :-

:       stz     current_entry
        stz     page_start
        lda     num_entries
        beq     selection_loop_keyboard_loop   ; no entries (empty directory)

        ;; Draw entries
        cmp     #bottom_row     ; more entries than fit?
        bcc     :+
        lda     #(bottom_row - top_row + 1)
:       sta     row_count
        lda     #top_row
        sta     WNDTOP
        sta     WNDLFT
        lda     #bottom_row+1
        sta     WNDWDTH
        sta     WNDBTM
loop:   jsr     draw_current_line
        inc     current_entry
        dec     row_count
        bne     loop
        stz     current_entry
        beq     selection_loop
.endproc

;;; ------------------------------------------------------------

        ;; Remove level from prefix; returns new length in X
.proc pop_prefix
        ldx     prefix
loop:   dex
        lda     prefix,x
        cmp     #'/'
        bne     loop
        cpx     #1
        bne     done
        ldx     prefix
done:
        ;; Fall through...
.endproc

handy_rts:
        rts

;;; ------------------------------------------------------------

.proc on_down
        jsr     down_common
        bra     selection_loop
.endproc

;;; ------------------------------------------------------------

.proc on_up
        ldx     current_entry   ; first one?
        beq     selection_loop
        dec     current_entry   ; go to previous

        lda     CV
        cmp     #top_row        ; at the top?
        bne     selection_loop
        dec     page_start      ; yes, adjust page and
        lda     #ASCII_SYN      ; scroll screen up
        jsr     COUT
        ;; fall through
.endproc

;;; ------------------------------------------------------------

.proc selection_loop
        jsr     SETINV
        jsr     draw_current_line

keyboard_loop:
        lda     KBD
        bpl     keyboard_loop
        sta     KBDSTRB
        jsr     SETNORM

        cmp     #HI(ASCII_TAB)
        beq     next_drive
        cmp     #HI(ASCII_ESCAPE)
        beq     on_escape

        ldx     num_entries
        beq     keyboard_loop   ; if empty, no navigation

        pha
        jsr     draw_current_line
        pla

        cmp     #HI(ASCII_CR)
        beq     on_return
        cmp     #HI(ASCII_DOWN)
        beq     on_down
        cmp     #HI(ASCII_UP)
        beq     on_up
        ;; fall through
.endproc
        selection_loop_keyboard_loop := selection_loop::keyboard_loop

;;; ------------------------------------------------------------

.proc on_alpha
loop:   jsr     down_common
        jsr     draw_current_line
        lda     KBD
        and     #$5F            ; make ASCII and uppercase
        ldy     #1
        cmp     (curr_ptr),y    ; key = first char ?
        beq     selection_loop
        bra     loop
.endproc

;;; ------------------------------------------------------------

.proc on_escape
        jsr     pop_prefix      ; leaves length in X
        dec     prefix_depth
        bra     resize_prefix_and_open_jmp
.endproc

;;; ------------------------------------------------------------
.proc down_common
        lda     current_entry
        inc     a
        cmp     num_entries     ; past the limit?
        bcc     :+
        pla                     ; yes - abort subroutine
        pla
        bra     selection_loop

:       sta     current_entry   ; go to next

        lda     CV
        cmp     #bottom_row     ; at the bottom?
        bne     handy_rts
        inc     page_start      ; yes, adjust page and
        lda     #ASCII_ETB      ; scroll screen down
        jmp     COUT            ; implicit rts
.endproc

;;; ------------------------------------------------------------

next_drive:                     ; relay for branches
        jmp     next_device

inc_resize_prefix_and_open:
        inx

resize_prefix_and_open_jmp:
        jmp     resize_prefix_and_open

;;; ------------------------------------------------------------

.proc on_return
        MLI_CALL SET_PREFIX, set_prefix_params
        bcs     next_drive
        ldx     current_entry
        jsr     update_curr_ptr

        ldx     prefix
:       iny
        lda     (curr_ptr),y
        inx
        sta     prefix,x
        cpy     curr_len
        bcc     :-
        stx     prefix

        ldy     current_entry
        lda     types_table,y
        bpl     inc_resize_prefix_and_open ; is directory???
        ;; nope, system file, so...

        ;; fall through
.endproc

;;; ------------------------------------------------------------

.proc launch_sys_file
        jsr     SETTXT
        jsr     HOME
        lda     #HI(ASCII_RIGHT) ; Right arrow ???
        jsr     COUT

        jsr     do_open
        bcs     next_drive
        lda     #$FF            ; Load up to $FFFF bytes
        sta     read_params_request
        sta     read_params_request+1
        jsr     do_read
        php
        MLI_CALL CLOSE, close_params
        plp
        bcs     next_drive
        jmp     read_buffer     ; Invoke the loaded code
.endproc

;;; ------------------------------------------------------------

.proc cout_string
loop:   lda     help_string,y
        beq     handy_rts2
        jsr     COUT
        iny
        bra     loop
.endproc

;;; ------------------------------------------------------------

;; Compute address/length of curr_ptr/curr_len
;; Call with entry index in X. Returns with Y = 0

.proc update_curr_ptr
        stz     curr_ptr+1
        txa
        asl     a
        rol     curr_ptr+1
        asl     a
        rol     curr_ptr+1
        asl     a
        rol     curr_ptr+1
        asl     a
        rol     curr_ptr+1
        sta     curr_ptr
        lda     #>filenames
        clc
        adc     curr_ptr+1
        sta     curr_ptr+1
        ldy     #0
        lda     (curr_ptr),y
        sta     curr_len
        ;; fall through
.endproc

handy_rts2:
        rts

;;; ------------------------------------------------------------

.proc draw_current_line
        lda     #2              ; hpos = 2
        sta     COL80HPOS

        ldx     current_entry   ; vpos = entry - page_start + 2
        txa
        sec
        sbc     page_start
        inc     a
        inc     a
        jsr     TABV

        lda     types_table,x
        bmi     name            ; is sys file?

        ;; Draw folder glyph
        stz     COL80HPOS
        lda     INVFLG
        pha
        ldy     #(folder_string - text_resources) ; Draw folder glyphs
        jsr     cout_string
        pla
        sta     INVFLG

        ;; Draw the name
name:   jsr     space
        jsr     update_curr_ptr
loop:   iny
        lda     (curr_ptr),y
        jsr     ascii_cout
        cpy     curr_len
        bcc     loop

space:  lda     #HI(' ')
        bne     cout            ; implicit RTS
.endproc

home:   lda     #HI(ASCII_EM)   ; move cursor to top left

        ;; Sets high bit before calling COUT
ascii_cout:
        ora     #$80
cout:   jmp     COUT

;;; ------------------------------------------------------------

.proc do_open
        MLI_CALL OPEN, open_params
        lda     open_params_ref_num
        sta     read_params_ref_num
        rts
.endproc

.proc do_read
        MLI_CALL READ, read_params
        rts
.endproc

;;; ------------------------------------------------------------

        text_resources := *

.proc help_string
        scrcode "RETURN: Select | TAB: Chg Vol | ESC: Back"
        .byte   0
.endproc

        ;; Mousetext sequence: Enable, folder left, folder right, disable
.proc folder_string
        .byte   $0F,$1B,$D8,$D9,$18,$0E
        .byte   0               ; null terminated
.endproc

;;; ------------------------------------------------------------

        DEFINE_OPEN_PARAMS open_params, prefix, $1C00
        open_params_ref_num := open_params::ref_num

        DEFINE_CLOSE_PARAMS close_params

        DEFINE_ON_LINE_PARAMS on_line_params, $60, prefix+1
        on_line_params_unit := on_line_params::unit_num

        DEFINE_SET_PREFIX_PARAMS set_prefix_params, prefix

        DEFINE_READ_PARAMS read_params, read_buffer, 0
        read_params_ref_num := read_params::ref_num
        read_params_request := read_params::request_count

;;; ------------------------------------------------------------

.endproc
        .assert .sizeof(selector) <= max_size, error, "Must fit in $300 bytes"
        install_size = .sizeof(selector)
        poporg

;;; ************************************************************
        .include "../inc/driver_postamble.inc"
;;; ************************************************************
