;;; Disassembly of Bird's Better Bye, 40 column program selector
;;; (Found in a copy of ProDOS 1.8, but not believed to be original?)
;;;
;;; Installer wrapper added by Joshua Bell inexorabletash@gmail.com

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
        lda     (src_ptr)
        sta     (dst_ptr)
        sta     ALTZPOFF
        sta     ROMINWB1
        sta     ROMINWB1

        rts
.endproc


;;; ------------------------------------------------------------
;;; Selector
;;; ------------------------------------------------------------

        install_src := *

        pushorg $1000
.proc bbb


PREFIX  := $280

kMaxFilesDisplayed = 16

filename_table := $1700
        device   := $6          ; current device index (in DEVLST)
        name_len := $8
        index    := $9          ; current displayed file index
        name_ptr := $D
        num_files := $F         ; number of displayed files
        type_table := $10       ; one entry per line, high bit set if SYS

        ;; Copied from directory header
        entry_length      := $A5
        entries_per_block := $A6
        file_count        := $A7

        entry_index       := $A9 ; within "block"

        dir_buf := SYS_ADDR

;;; ============================================================
;;; Code
;;; ============================================================

        ;; Signal to ProDOS that this is modified.
        cld

        inc     $03F4           ; ???

        ;; Page in normal banks, reset screen to 40 columns.
        lda     ROMIN2
        jsr     SETTXT
        jsr     SETVID
        jsr     SETKBD
        jsr     SETNORM
        sta     CLR80VID
        sta     CLRALTCHAR
        sta     CLR80COL

        ;; Clear system bitmap.
        lda     #$01
        sta     BITMAP+BITMAP_SIZE-1
        lda     #$00
        ldx     #BITMAP_SIZE-2
:       sta     BITMAP,x
        dex
        bpl     :-
        lda     #$CF
        sta     BITMAP


        lda     default_devnum
        beq     :+              ; always?
        sta     DEVNUM
:       ldx     DEVCNT
:       stx     device
        lda     DEVLST,x
        and     #$F0
        cmp     DEVNUM
        beq     set_devnum
        dex
        bpl     :-

next_drive:
        ldx     device
        cpx     DEVCNT
        bcc     :+
        ldx     #$FF
:       inx
        stx     device

        lda     DEVLST,x
set_devnum:
        sta     on_line_unit_num
        sta     DEVNUM
        jsr     HOME
        MLI_CALL ON_LINE, on_line_params
        bcs     error_relay
        lda     PREFIX+1
        and     #$0F
        beq     error_relay
        adc     #$02
        sta     PREFIX
        tax
set_prefix_length:
        lda     #'/'
        sta     PREFIX+1
        sta     PREFIX,x
        lda     #0
        sta     PREFIX+1,x
        sta     index
        sta     read_request_count+1
        sta     set_mark_position+1
        sta     set_mark_position+2

        ldx     #msg_select_drive
        lda     #10             ; HTAB
        jsr     ShowMessage

        ldx     #msg_select_file
        lda     #9              ; HTAB
        jsr     ShowMessage

        ;; Show current prefix
        ldx     #0
:       lda     PREFIX+1,x
        beq     :+
        jsr     Cout
        inx
        bne     :-

:       MLI_CALL OPEN, open_params
error_relay:
        bcs     next_drive_on_error
        jsr     AssignRefNum
        lda     #.sizeof(SubdirectoryHeader)
        sta     read_request_count
        MLI_CALL READ, read_params
        bcs     next_drive_on_error

        ldx     #3
:       lda     dir_buf + SubdirectoryHeader::entry_length,x
        sta     entry_length,x
        dex
        bpl     :-

        sta     read_request_count
        lda     #1
        sta     entry_index
        lda     file_count      ; empty?
        ora     file_count+1
        bne     next_file
:       jmp     finish_dir      ; empty!

        ;; Loop over file entries
next_file:
        bit     file_count+1    ; negative?
        bmi     :-
skip:  lda     set_mark_position+1
        and     #$FE
        sta     set_mark_position+1
        ldy     entry_index
        lda     #0
        cpy     entries_per_block
        bcc     next_entry_in_block
        tay
        sty     entry_index
        inc     set_mark_position+1 ; next block - two pages
:       inc     set_mark_position+1
next_entry_in_block:
        dey
        clc
        bmi     next_block
        adc     entry_length
        bcc     next_entry_in_block
        bcs     :-              ; always

next_block:
        adc     #4              ; skip prev/next block pointers
        sta     set_mark_position
        MLI_CALL SET_MARK, get_eof_params

next_drive_on_error:
        bcs     do_next_drive

        MLI_CALL READ, read_params
        bcs     do_next_drive
        inc     entry_index
        lda     dir_buf
        beq     skip            ; deleted entry
        and     #NAME_LENGTH_MASK
        sta     dir_buf
        dec     file_count
        bne     :+
        dec     file_count+1
:       ror     dir_buf + FileEntry::access ; check low bit
        bcc     next_file

        lda     dir_buf + FileEntry::file_type
        cmp     #FT_DIRECTORY
        beq     :+
        cmp     #FT_SYSTEM
        bne     next_file
:       ldx     index
        cpx     #kMaxFilesDisplayed
        bcs     finish_dir
        sta     type_table,x
        jsr     SetNamePtrAndLen

        ldy     #$0F            ; max name length
:       lda     dir_buf,y
        sta     (name_ptr),y
        dey
        bpl     :-

        jsr     DisplayFilename
        inc     index
        jmp     next_file

;;; ============================================================

do_next_drive:
        jmp     next_drive

up_dir:
        ldx     PREFIX
:       dex
        beq     input_loop
        lda     PREFIX,x
        cmp     #'/'
        bne     :-
        dex
        beq     input_loop
        stx     PREFIX

set_new_prefix:
        inc     PREFIX
        jsr     HOME
        ldx     PREFIX
        jmp     set_prefix_length

select_next_file:
        jsr     DisplayFilename
        ldx     index
        inx
        cpx     num_files
        bcc     set_index
        ldx     #0
        beq     set_index           ; always

select_prev_file:
        jsr     DisplayFilename
        ldx     index
        bne     :+
        ldx     num_files
:       dex
set_index:
        stx     index
        jmp     redisplay_selection

finish_dir:
        MLI_CALL CLOSE, close_params
next_drive_relay:
        bcs     do_next_drive
        lda     index
        beq     do_next_drive
        sta     num_files
        lda     #0
        sta     index
redisplay_selection:
        jsr     SETINV
        jsr     DisplayFilename
        jsr     SETNORM
        ;; fall through

;;; ============================================================

input_loop:
        lda     KBD
        bpl     input_loop
        sta     KBDSTRB

        cmp     #HI(ASCII_TAB)
        beq     do_next_drive

        cmp     #HI(ASCII_LEFT)
        beq     select_prev_file
        cmp     #HI(ASCII_UP)
        beq     select_prev_file

        cmp     #HI(ASCII_RIGHT)
        beq     select_next_file
        cmp     #HI(ASCII_DOWN)
        beq     select_next_file

        cmp     #HI(ASCII_ESCAPE)
        beq     up_dir

        cmp     #HI(ASCII_CR)
        bne     input_loop
        lda     BUTN0
        bpl     SelectFile

        lda     ROMIN
        lda     ROMIN
        lda     DEVNUM
        sta     $D3A6
        lda     ROMIN2
        jmp     input_loop

;;; ============================================================

.proc SelectFile
        MLI_CALL SET_PREFIX, set_prefix_params
        bcs     next_drive_relay
        jsr     SetNamePtrAndLen
        ldx     PREFIX
:       iny
        lda     (name_ptr),y
        inx
        sta     PREFIX,x
        cpy     name_len
        bcc     :-
        stx     PREFIX
        ldy     index
        lda     type_table,y
        bmi     InvokeSystemFile
        jmp     set_new_prefix
.endproc

;;; ============================================================

.proc InvokeSystemFile
        MLI_CALL OPEN, open_params
:       bcs     next_drive_relay
        jsr     AssignRefNum
        MLI_CALL GET_EOF, get_eof_params
        bcs     :-
        lda     get_eof_eof
        sta     read_request_count
        lda     get_eof_eof+1
        sta     read_request_count+1
        MLI_CALL READ, read_params
        php
        MLI_CALL CLOSE, close_params
        bcc     :+
        pla
err:    jmp     do_next_drive

:       plp
        bcs     err
        jmp     SYS_ADDR
.endproc

;;; ============================================================
;;; Call with HTAB in A, message table offset in X

.proc ShowMessage
        sta     CH

:       lda     message_table,x
        beq     done
        jsr     Cout
        inx
        bne     :-
done:   rts
.endproc

;;; ============================================================

.proc Cout
        ora     #$80
        jmp     COUT1
.endproc

;;; ============================================================

.proc SetNamePtrAndLen
        lda     index
        asl     a               ; * 16 (name length)
        asl     a
        asl     a
        asl     a
        sta     name_ptr
        lda     #>filename_table
        sta     name_ptr+1
        ldy     #$00
        lda     (name_ptr),y
        sta     name_len
        rts
.endproc

;;; ============================================================

.proc DisplayFilename
        lda     #5
        sta     CH
        lda     index
        clc
        adc     #$05
        jsr     TABV
        jsr     space
        ldx     index
        lda     type_table,x    ; folder?
        bmi     :+              ; nope
        lda     #HI('/')        ; yes - suffix with '/'
        jsr     Cout
:       jsr     SetNamePtrAndLen

:       iny
        lda     (name_ptr),y
        jsr     Cout
        cpy     name_len
        bcc     :-

space:  lda     #HI(' ')
        jmp     Cout
.endproc

;;; ============================================================

.proc AssignRefNum
        lda     open_ref_num
        sta     read_ref_num
        sta     get_eof_ref_num ; also set_mark_position
        rts
.endproc

;;; ============================================================

default_devnum:
        .byte   0

;;; ============================================================
;;; Messages
;;; ============================================================

message_table:

        msg_select_drive := * - message_table
        scrcode "TAB: SELECT DRIVE\r"
        .byte   0

        msg_select_file := * - message_table
        scrcode "RETURN: SELECT FILE\r\r"
        .byte   0

;;; ============================================================
;;; Parameter Blocks
;;; ============================================================

;;; OPEN params

open_params:
        .byte   3
open_pathname:
        .addr   PREFIX
open_io_buffer:
        .addr   $1800
open_ref_num:
        .byte   0

;;; CLOSE params

close_params:
        .byte   1
        .byte   0

;;; ON_LINE params

on_line_params:
        .byte   $02
on_line_unit_num:
        .byte   $60
on_line_buffer:
        .addr   PREFIX+1

;;; READ params

read_params:
        .byte   4
read_ref_num:
        .byte   0
read_data_buffer:
        .addr   $2000
read_request_count:
        .word   0
read_transfer_count:
        .word   0

;;; SET_PREFIX params

set_prefix_params:
        .byte   1
        .addr   PREFIX

;;; GET_EOF params
;;; SET_MARK params

get_eof_params:
set_mark_params:
        .byte   2
get_eof_ref_num:
set_mark_ref_num:
        .byte   0
get_eof_eof:
set_mark_position:
        .faraddr        $A0A0A0


;;; ------------------------------------------------------------

.endproc
        .assert .sizeof(bbb) - bbb <= $300, error, "Must fit in $300 bytes"
        install_size = $300
        poporg

;;; ************************************************************
        .include "../inc/driver_postamble.inc"
;;; ************************************************************
