;;; Disassembly of BYE.SYSTEM (Bird's Better Bye)

        .setcpu "65C02"
        .include "apple2.inc"
        .include "prodos.inc"

RESETVEC        := $3F2

RAMRDOFF        := $C002
RAMRDON         := $C003
RAMWRTOFF       := $C004
RAMWRTON        := $C005
ALTZPOFF        := $C008
ALTZPON         := $C009
ROMINNW         := $C082
ROMINWB1        := $C089
SLOT3           := $C300

MON_SETTXT      := $FB39
MON_TABV        := $FB5B
SETPWRC         := $FB6F
BELL1           := $FBDD
MON_HOME        := $FC58
COUT            := $FDED
SETINV          := $FE80
SETNORM         := $FE84

COL80HPOS       := $057B

;;; ProDOS
BITMAP          := $BF58
BITMAP_SIZE     := $18          ; Bits for pages $00 to $BF
DEVNUM          := $BF30        ; Most recent accessed device
DEVCNT          := $BF31        ; Number of on-line devices minus 1
DEVLST          := $BF32        ; Up to 14 units

;;; ASCII
ASCII_TAB       := $9
ASCII_DOWN      := $A           ; down arrow
ASCII_UP        := $B           ; up arrow
ASCII_CR        := $D
ASCII_RIGHT     := $15          ; right arrow
ASCII_SYN       := $16          ; scroll up
ASCII_ETB       := $17          ; scroll down
ASCII_EM        := $19          ; move cursor to upper left
ASCII_ESCAPE    := $1B

;;; ------------------------------------------------------------

.define HI(char)        (char|$80)

.macro  HIASCII arg
        .repeat .strlen(arg), i
        .byte   .strat(arg, i) | $80
        .endrep
.endmacro

.macro  HIASCIIZ arg
        HIASCII arg
        .byte   0
.endmacro


;;; ------------------------------------------------------------

;;; ProDOS Technical Reference Manual, 5.1.5.2:
;;;
;;; ProDOS MLI call $65, the QUIT call, moves addresses $D100 through
;;; $D3FF from the second 4K bank of RAM of the language card to
;;; $1000, and executes a JMP to $1000. What initially resides in that
;;; area is Apple's dispatcher code.

;;; ------------------------------------------------------------
;;; Entry point
;;; ------------------------------------------------------------

        ;; Loads at $2000 but executed at $1000.

        .org    $2000

        jmp     install_and_quit
        install_src := *

;;; ------------------------------------------------------------
;;; Selector
;;; ------------------------------------------------------------

        .org    $1000
.proc bbb

        prefix  := $280         ; length-prefixed

        filenames       := $1400 ; each is length + 15 bytes
        read_buffer     := $2000 ; Also, start location for launched SYS files

        mark_params     := $60
        mark_ref_num    := $61
        mark_position   := $62  ; 3-bytes

        next_device_num := $65  ; next device number to try

        current_entry   := $67  ; index of current entry
        num_entries     := $68  ; length of |filenames|
        curr_len        := $69  ; length of current entry name
        curr_ptr        := $6C  ; address of current entry name (in |filenames|)
        page_start      := $73  ; index of first entry shown on screen

        prefix_depth    := $6B  ; 0 = root

        max_entries     := 128  ; max # of entries; more are ignored
        types_table     := $74  ; high bit clear = dir, set = sys

        top_row         := 2    ; first row used on screen
        bottom_row      := 21   ; last row used on screen

;;; ------------------------------------------------------------

        cld                     ; ProDOS protocol for QUIT routine
        lda     ROMINNW         ; Page in ROM for reads, writes ignored

        ;; Point reset vector at this routine
        stz     RESETVEC
        lda     #>bbb
        sta     RESETVEC+1

        jsr     SETPWRC
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
        lda     #2
        sta     $60
        ldx     DEVCNT          ; max device num
        stx     next_device_num
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
        sta     prefix+1
        sta     prefix,x
        stz     prefix+1,x

        MLI_CALL OPEN, open_params
        bcc     :+

        ;; Open failed
        lda     prefix_depth    ; root?
        beq     next_device
        jsr     BELL1           ; no, but failed; beep
        jsr     pop_prefix      ; and go up a level
        stx     prefix
        jmp     keyboard_loop


        directory_header_size   := $2B

        ;; Open succeeded
:       inc     prefix_depth
        stz     num_entries
        lda     open_params_ref_num
        sta     read_params_ref_num
        sta     mark_ref_num
        lda     #directory_header_size
        sta     read_params_request
        stz     read_params_request+1
        jsr     do_read
        bcs     L10B3

        ldx     #3
L109A:  lda     $2023,x
        sta     $6E,x
        dex
        bpl     L109A
        sta     read_params_request
        lda     #$01
        sta     $72
        stz     mark_position+1
        stz     mark_position+2
        lda     $70
        ora     $71
        bne     L10B5

L10B3:  bra     finish_read

L10B5:  bit     $71
        bmi     L10B3
L10B9:  lda     mark_position+1
        and     #$FE
        sta     mark_position+1
        ldy     $72
        lda     #$00
        cpy     $6F
        bcc     L10CE
        tay
        sty     $72
        inc     mark_position+1
L10CC:  inc     mark_position+1
L10CE:  dey
        clc
        bmi     L10D8
        adc     $6E
        bcc     L10CE
        bcs     L10CC
L10D8:  adc     #$04
        sta     mark_position
        MLI_CALL SET_MARK, mark_params
        bcs     L10B3
        jsr     do_read
        bcs     L10B3
        inc     $72
        lda     read_buffer
        and     #$F0
        beq     L10B9
        dec     $70
        bne     L10F8
        dec     $71
L10F8:  ror     $201E
        bcc     L10B5
        lda     $2010
        cmp     #$0F
        beq     L1108
        cmp     #$FF
        bne     L10B5
L1108:  ldx     num_entries
        cpx     #max_entries
        bcs     finish_read
        sta     types_table,x
        jsr     update_curr_ptr

        ldy     #$0F            ; name length
:       lda     read_buffer,y
        sta     (curr_ptr),y
        dey
        bpl     :-

        iny                     ; Y = 0
        and     #$0F
        sta     (curr_ptr),y    ; store length
        inc     num_entries
        bne     L10B5
next:   jmp     next_device

finish_read:
        MLI_CALL CLOSE, close_params
        bcs     next
        ;; fall through
.endproc

;;; ------------------------------------------------------------

.proc draw_screen
        jsr     MON_SETTXT      ; TEXT
        jsr     MON_HOME        ; HOME
        lda     #23             ; VTAB 23
        jsr     MON_TABV

        ;; Print help text
        ldy     #0
        lda     #20             ; HTAB 20
        jsr     cout_string_hpos

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
        beq     keyboard_loop   ; no entries (empty directory)

        row_count := $6A

        cmp     #bottom_row     ; more entries than fit?
        bcc     :+
        lda     #(bottom_row - top_row + 1)
:       sta     row_count
        lda     #2
        sta     WNDTOP
        sta     WNDLFT
        lda     #22
        sta     WNDWDTH
        sta     WNDBTM
loop:   jsr     draw_current_line
        inc     current_entry
        dec     row_count
        bne     loop
        stz     current_entry
        beq     draw_current_line_inv
.endproc

;;; ------------------------------------------------------------

.proc on_up
        jsr     draw_current_line ; clear inverse selection

        ldx     current_entry
        beq     draw_current_line_inv ; first one? just redraw
        dec     current_entry         ; go to previous

        lda     CV
        cmp     #top_row        ; at the top?
        bne     draw_current_line_inv ; if not, just draw
        dec     page_start      ; yes, adjust page and
        lda     #ASCII_SYN      ; scroll screen up
        bne     draw_current_line_with_char
.endproc

;;; ------------------------------------------------------------

.proc on_down
        jsr     draw_current_line ; clear inverse selection

        ldx     current_entry
        inx
        cpx     num_entries           ; past the limit?
        bcs     draw_current_line_inv ; yes, just redraw
        stx     current_entry         ; go to next

        lda     CV
        cmp     #bottom_row     ; at the bottom?
        bne     draw_current_line_inv ; if not, just draw
        inc     page_start      ; yes, adjust page and
        lda     #ASCII_ETB      ; scroll screen down
        ;; fall through
.endproc

;;; ------------------------------------------------------------

draw_current_line_with_char:
        jsr     COUT

draw_current_line_inv:
        jsr     SETINV
        jsr     draw_current_line
        ;; fall through

;;; ------------------------------------------------------------

.proc keyboard_loop
        lda     KBD
        bpl     keyboard_loop
        sta     KBDSTRB
        jsr     SETNORM
        ldx     num_entries
        beq     :+              ; no up/down/return if empty

        cmp     #HI(ASCII_CR)
        beq     on_return
        cmp     #HI(ASCII_DOWN)
        beq     on_down
        cmp     #HI(ASCII_UP)
        beq     on_up

:       cmp     #HI(ASCII_TAB)
        beq     next_drive
        cmp     #HI(ASCII_ESCAPE)
        bne     keyboard_loop
        ;; fall through
.endproc

;;; ------------------------------------------------------------

.proc on_escape
        jsr     pop_prefix      ; leaves length in X
        dec     prefix_depth
        bra     resize_prefix_and_open_jmp
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
done:   rts
.endproc

;;; ------------------------------------------------------------

next_drive:
        jmp     next_device

dec_resize_prefix_and_open:
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
        bpl     dec_resize_prefix_and_open ; is directory???
        ;; nope, system file, so...

        ;; fall through
.endproc

;;; ------------------------------------------------------------

.proc launch_sys_file
        jsr     MON_SETTXT
        jsr     MON_HOME
        lda     #HI(ASCII_RIGHT) ; Right arrow
        jsr     COUT

        MLI_CALL OPEN, open_params
        bcs     next_drive
        lda     open_params_ref_num
        sta     read_params_ref_num
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

cout_string_hpos:
        sta     CH

.proc cout_string
        lda     help_string,y
        beq     done
        jsr     COUT
        iny
        bne     cout_string
done:   rts
.endproc

;;; ------------------------------------------------------------

;; Compute address/length of curr_ptr/curr_len
;; Call with entry index in X.

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
        rts
.endproc

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
        jsr     MON_TABV

        lda     types_table,x
        bmi     name            ; is sys file?

        ;; Draw folder glyph
        stz     COL80HPOS
        lda     INVFLG
        pha
        ldy     #(folder_string - string_start) ; Draw folder glyphs
        jsr     cout_string
        pla
        sta     INVFLG

        ;;  Draw the name
name:   jsr     space
        jsr     update_curr_ptr
loop:   iny
        lda     (curr_ptr),y
        jsr     ascii_cout
        cpy     curr_len
        bcc     loop

space:  lda     #HI(' ')
        bne     cout            ; implicit RTS
        ;; fall through
.endproc

home:   lda     #HI(ASCII_EM)   ; move cursor to top left

        ;; Sets high bit before calling COUT
ascii_cout:
        ora     #$80
cout:   jmp     COUT

;;; ------------------------------------------------------------

.proc do_read
        MLI_CALL READ, read_params
        rts
.endproc

;;; ------------------------------------------------------------

        string_start := *
.proc help_string
        HIASCIIZ "RETURN: Select | TAB: Chg Vol | ESC: Back"
.endproc

        ;; Mousetext sequence: Enable, folder left, folder right, disable
.proc folder_string
        .byte   $0F,$1B,$D8,$D9,$18,$0E
        .byte   0               ; null terminated
.endproc

;;; ------------------------------------------------------------

.proc open_params
params: .byte   3
path:   .addr   prefix
buffer: .addr   $1C00
ref_num:.byte   0
.endproc
        open_params_ref_num := open_params::ref_num

.proc close_params
params: .byte   1
ref_num:.byte   0
.endproc

.proc on_line_params
params: .byte   2
unit:   .byte   $60
buffer: .addr   prefix+1
.endproc
        on_line_params_unit := on_line_params::unit

.proc set_prefix_params
params: .byte   1
path:   .addr   prefix
.endproc

.proc read_params
params: .byte   4
ref_num:.byte   1
buffer: .word   read_buffer
request:.word   0
trans:  .word   0
.endproc
        read_params_ref_num := read_params::ref_num
        read_params_request := read_params::request

;;; ------------------------------------------------------------

        .res    $13FF-*-2, 0
        .byte   $48,$AD         ; 72, 173 ???

.endproc
        .assert .sizeof(bbb) = $3FF, error, "Expected size is $3FF"

;;; ------------------------------------------------------------
;;; Installer
;;; ------------------------------------------------------------

        .org    $2402

.proc install_and_quit
        jsr     install
        MLI_CALL QUIT, params

.proc params
params: .byte   4
type:   .byte   0
res1:   .word   0
res2:   .byte   0
res3:   .addr   0
.endproc
.endproc

;;; ------------------------------------------------------------

.proc install
        src := install_src
        end := install_src + .sizeof(bbb)
        dst := $D100            ; Install location in ProDOS (bank 2)

        src_ptr := $19
        dst_ptr := $1B

        sta     ALTZPOFF
        lda     ROMIN
        lda     ROMIN
        lda     #>src
        sta     src_ptr+1
        lda     #<src
        sta     src_ptr
        lda     #>dst
        sta     dst_ptr+1
        lda     #<dst
        sta     dst_ptr

loop:   lda     (src_ptr)
        sta     (dst_ptr)
        inc     src_ptr
        bne     :+
        inc     src_ptr+1
:       inc     dst_ptr
        bne     :+
        inc     dst_ptr+1
:       lda     src_ptr+1
        cmp     #>end
        bne     loop
        lda     src_ptr
        cmp     #<end
        bne     loop
        lda     (src_ptr)       ; WTF??
        sta     (dst_ptr)
        sta     ALTZPOFF
        sta     ROMINWB1
        sta     ROMINWB1
        rts
.endproc
