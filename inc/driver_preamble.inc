.define PRODUCT "Unknown"

;;; ------------------------------------------------------------

        ;; SYS files load at $2000; relocates self to $1000
        .org SYS_ADDR
        dst_addr := $1000

;;; ------------------------------------------------------------

        jmp     relocate

        .byte   MM, DD, YY      ; version date stamp

;;; ------------------------------------------------------------
;;; Relocate this code from $2000 (.SYSTEM start location) to $1000
;;; and start executing there. This is done so that the next .SYSTEM
;;; file can be loaded/run at $2000.

.proc relocate
        src := reloc_start
        dst := dst_addr

        ldx     #(reloc_end - reloc_start + $FF) / $100 ; pages
        ldy     #0
load:   lda     src,y           ; self-modified
        load_hi := *-1
        sta     dst,y           ; self-modified
        store_hi := *-1
        iny
        bne     load
        inc     load_hi
        inc     store_hi
        dex
        bne     load

        jmp     main
.endproc

;;; ============================================================
;;; Start of relocated code

        reloc_start := *
        pushorg dst_addr

;;; ============================================================
;;; Main routine
;;; ============================================================

.proc main
        jsr     save_chain_info
        jsr     init_system
        jsr     maybe_install_driver
        jmp     launch_next
.endproc

;;; ============================================================
;;; Preserve state needed to chain to next file
;;; ============================================================

.proc save_chain_info
        ;; --------------------------------------------------
        ;; Save most recent device for later, when chaining
        ;; to next .SYSTEM file.
        lda     DEVNUM
        sta     devnum

        ;; --------------------------------------------------
        ;; Identify the name of this SYS file, which should be present at
        ;; $280 with or without a path prefix. Search pathname buffer
        ;; backwards for '/', then copy name into `self_name`.

        ;; Find '/' (which may not be present, prefix is optional)
        ldx     PATHNAME
        beq     no_name
        ldy     #0              ; Y = length
:       lda     PATHNAME,x
        and     #$7f            ; ignore high bit
        cmp     #'/'
        beq     copy_name
        iny
        dex
        bne     :-

        ;; Copy name into `self_name` buffer
copy_name:
        cpy     #0
        beq     no_name
        sty     self_name

        ldx     PATHNAME
:       lda     PATHNAME,x
        sta     self_name,y
        dex
        dey
        bne     :-

        ;; Done
        rts

no_name:
        lda     #0
        sta     self_name
        rts
.endproc

devnum:         .byte   0
self_name:      .res    16

;;; ============================================================
;;; Init system state
;;; ============================================================

;;; Before installing, get the system to a known state.

.proc init_system
        cld
        bit     ROMIN2

        ;; Update reset vector - ProDOS QUIT
        lda     #<quit
        sta     RESETVEC
        lda     #>quit
        sta     RESETVEC+1
        eor     #$A5
        sta     RESETVEC+2

        ;; Quit 80-column firmware
        lda     #$95            ; Ctrl+U (quit 80 col firmware)
        jsr     COUT

        ;; Reset I/O
        sta     CLR80VID
        sta     CLRALTCHAR
        sta     CLR80COL
        jsr     SETNORM
        jsr     INIT
        jsr     SETVID
        jsr     SETKBD

        ;; Update System Bit Map
        ldx     #BITMAP_SIZE-1
        lda     #%00000001      ; protect page $BF
:       sta     BITMAP,x
        lda     #%00000000      ; nothing else protected until...
        dex
        bne     :-
        lda     #%11001111      ; ZP ($00), stack ($01), text page 1 ($04-$07)
        sta     BITMAP

        ;; Determine lowercase support
        lda     MACHID
        and     #$88            ; IIe or IIc (or IIgs) ?
        bne     :+
        lda     #$DF
        sta     lowercase_mask  ; lower case to upper case

:       rts
.endproc

;;; ============================================================
;;; Find and invoke the next .SYSTEM file
;;; ============================================================

online_buf      := $1C00
io_buf          := $1C00
dir_buf         := $2000
block_len       = $200

        DEFINE_ON_LINE_PARAMS on_line_params,,online_buf
        DEFINE_OPEN_PARAMS open_params, PATHNAME, io_buf
        DEFINE_READ_PARAMS read_params, SYS_ADDR, SYS_LEN
        DEFINE_READ_PARAMS read_block_params, dir_buf, block_len
        DEFINE_CLOSE_PARAMS close_params


.proc launch_next
        ;; Read directory and look for .SYSTEM files; find this
        ;; one, and invoke the following one.

        ptr := $A5
        num := $A7
        len := $A8

        ;; --------------------------------------------------
        ;; Own name found? If not, just quit
        lda     self_name
        bne     :+
        jmp     quit

        ;; --------------------------------------------------
        ;; Find name of boot device, copy into PATHNAME
:       lda     devnum
        sta     on_line_params::unit_num
        MLI_CALL ON_LINE, on_line_params
        bcc     :+
        jmp     on_error

:       lda     #'/'            ; Prefix by '/'
        sta     PATHNAME+1
        lda     online_buf
        and     #$0F            ; Mask off length
        sta     PATHNAME
        ldx     #0              ; Copy name
:       lda     online_buf+1,x
        sta     PATHNAME+2,x
        inx
        cpx     PATHNAME
        bne     :-
        inx                     ; One more for '/' prefix
        stx     PATHNAME

        ;; Open directory
        MLI_CALL OPEN, open_params
        bcc     :+
        jmp     on_error
:       lda     open_params::ref_num
        sta     read_block_params::ref_num
        sta     close_params::ref_num

        ;; Read first "block"
        MLI_CALL READ, read_block_params
        bcc     :+
        MLI_CALL CLOSE, close_params
        jmp     on_error

        ;; Get sizes out of header
:       lda     dir_buf + VolumeDirectoryHeader::entry_length
        sta     entry_length_mod
        lda     dir_buf + VolumeDirectoryHeader::entries_per_block
        sta     entries_per_block_mod
        lda     #1
        sta     num

        ;; Set up pointers to entry
        lda     #<(dir_buf + .sizeof(VolumeDirectoryHeader))
        sta     ptr
        lda     #>(dir_buf + .sizeof(VolumeDirectoryHeader))
        sta     ptr+1

        ;; Process directory entry
entry:  ldy     #FileEntry::file_type      ; file_type
        lda     (ptr),y
        cmp     #$FF            ; type=SYS
        bne     next
        ldy     #FileEntry::storage_type_name_length
        lda     (ptr),y
        and     #$30            ; regular file (not directory, pascal)
        beq     next
        lda     (ptr),y
        and     #$0F            ; name_length
        sta     len
        tay

        ;; Compare suffix - is it .SYSTEM?
        ldx     suffix
:       lda     (ptr),y
        cmp     suffix,x
        bne     next
        dey
        dex
        bne     :-

        ;; Yes; is it *this* .SYSTEM file?
        ldy     self_name
        cpy     len
        bne     handle_sys_file
:       lda     (ptr),y
        cmp     self_name,y
        bne     handle_sys_file
        dey
        bne     :-
        sec
        ror     found_self_flag

        ;; Move to the next entry
next:   lda     ptr
        clc
        adc     #$27            ; self-modified: entry_length
        entry_length_mod := *-1
        sta     ptr
        bcc     :+
        inc     ptr+1
:       inc     num
        lda     num
        cmp     #$0D            ; self-modified: entries_per_block
        entries_per_block_mod := *-1
        bcc     entry

        ;; Read next "block"
        MLI_CALL READ, read_block_params
        bcs     not_found

        ;; Set up pointers to entry
        lda     #0
        sta     num
        lda     #<(dir_buf + $04)
        sta     ptr
        lda     #>(dir_buf + $04)
        sta     ptr+1
        jmp     entry

        ;; --------------------------------------------------
        ;; Found a .SYSTEM file which is not this one; invoke
        ;; it if follows this one.
handle_sys_file:
        bit     found_self_flag
        bpl     next

        MLI_CALL CLOSE, close_params

        ;; Compose the path to invoke.
        ldx     PATHNAME
        inx
        lda     #'/'
        sta     PATHNAME,x
        ldy     #0
:       iny
        inx
        lda     (ptr),y
        sta     PATHNAME,x
        cpy     len
        bcc     :-
        stx     PATHNAME

        jmp     invoke_system_file

not_found:
        MLI_CALL CLOSE, close_params
        jmp     quit
.endproc

;;; ------------------------------------------------------------
;;; Load/execute the system file in PATHNAME

.proc invoke_system_file
        MLI_CALL OPEN, open_params
        bcs     on_error

        lda     open_params::ref_num
        sta     read_params::ref_num
        sta     close_params::ref_num

        MLI_CALL READ, read_params
        php
        MLI_CALL CLOSE, close_params
        plp
        bcs     on_error

        jmp     SYS_ADDR        ; Invoke loaded SYSTEM file
.endproc

;;; ------------------------------------------------------------
;;; Error handler - invoked if any ProDOS error occurs.

.proc on_error
        pha
        jsr     zstrout
        scrcode "\r\r*  Disk Error $"
        .byte   0

        pla
        jsr     PRBYTE

        jsr     zstrout
        scrcode "  *\r"
        .byte   0

        bit     KBDSTRB
:       lda     KBD
        bpl     :-
        bit     KBDSTRB
        jmp     quit
.endproc

.proc quit
        MLI_CALL QUIT, quit_params
        brk                     ; crash if QUIT fails

        DEFINE_QUIT_PARAMS quit_params
.endproc

;;; ============================================================
;;; Data

suffix:
        PASCAL_STRING ".SYSTEM"

found_self_flag:
        .byte   0

;;; ============================================================
;;; Common Routines
;;; ============================================================

;;; ------------------------------------------------------------
;;; Use this for logging the result of a driver. Uses `zstrout`.

.proc log_message
        jsr     CROUT
        jsr     CROUT
        ;; fall through
.endproc

;;; ------------------------------------------------------------
;;; Output a high-ascii, null-terminated string.
;;; String immediately follows the JSR.

.proc zstrout
        ptr := $A5

        pla                     ; read address from stack
        sta     ptr
        pla
        sta     ptr+1
        bne     skip            ; always (since data not on ZP)

next:   cmp     #HI('a')        ; lower-case?
        bcc     :+
        and     lowercase_mask  ; make upper-case if needed
:       jsr     COUT
skip:   inc     ptr
        bne     :+
        inc     ptr+1
:       ldy     #0
        lda     (ptr),y
        bne     next

        lda     ptr+1           ; restore address to stack
        pha
        lda     ptr
        pha
        rts
.endproc

lowercase_mask:
        .byte   $FF             ; Set to $DF on systems w/o lower-case

;;; ------------------------------------------------------------
;;; COUT a 2-digit number in A

.proc cout_number
        ldx     #HI('0')
        cmp     #10             ; >= 10?
        bcc     tens

        ;; divide by 10, dividend(+'0') in x remainder in a
:       sbc     #10
        inx
        cmp     #10
        bcs     :-

tens:   pha
        cpx     #HI('0')
        beq     units
        txa
        jsr     COUT

units:  pla
        ora     #HI('0')
        jsr     COUT
        rts
.endproc

;;; ------------------------------------------------------------
;;; COUT the current ProDOS date

.proc cout_date
        lda     DATELO+1        ; month
        ror     a
        pha
        lda     DATELO
        pha
        rol     a
        rol     a
        rol     a
        rol     a
        and     #%00001111
        jsr     cout_number

        lda     #HI('/')        ; /
        jsr     COUT

        pla                     ; day
        and     #%00011111
        jsr     cout_number

        lda     #HI('/')        ; /
        jsr     COUT

        pla                     ; year
        jsr     cout_number

        rts
.endproc
