;;; Disassembly of ProDOS QUIT handler (program selector)
;;; This is a 40-column selector that prompts for prefix/pathname,
;;; installed by default except on 80-column systems in 1.9 and
;;; later.
;;;
;;; Installer wrapper added by Joshua Bell inexorabletash@gmail.com

        .setcpu "6502"
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

loop:   ldy     #0
        lda     (src_ptr),y
        sta     (dst_ptr),y
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
        lda     (src_ptr),y
        sta     (dst_ptr),y
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

.proc selector

PREFIX  := $280

;;; ============================================================
;;; Code
;;; ============================================================

        ;; Page in normal banks, reset screen to 40 columns.
        lda     ROMIN2
        sta     CLR80VID
        sta     CLRALTCHAR
        sta     CLR80COL
        jsr     SETNORM
        jsr     INIT
        jsr     SETVID
        jsr     SETKBD

        ;; Clear system bitmap
        ldx     #$17
        lda     #$01
        sta     BITMAP,x
        dex
        lda     #$00
:       sta     BITMAP,x
        dex
        bpl     :-
        lda     #$CF
        sta     BITMAP

;;; ============================================================

.proc PromptForPrefix
        jsr     HOME
        jsr     CROUT
        ldx     #msg_enter_prefix
        jsr     ShowMessage
        lda     #$03
        sta     CV
        jsr     CROUT
        MLI_CALL GET_PREFIX, get_prefix_params
        ldx     PREFIX
        lda     #$00
        sta     $0281,x
        ldx     PREFIX
        beq     L105D
L1052:  lda     PREFIX,x
        ora     #$80
        sta     $05FF,x
        dex
        bne     L1052
L105D:  ldx     #$00
        dec     CV
        jsr     CROUT

input_loop:
        jsr     RDKEY
        cmp     #HI(ASCII_CR)
        beq     try_set_prefix
        pha
        jsr     CLREOL
        pla
        cmp     #HI(ASCII_ESCAPE)
        beq     PromptForPrefix
        cmp     #HI(ASCII_CLEAR)
reprompt_for_prefix:            ; used as a relay
        beq     PromptForPrefix
        cmp     #HI(ASCII_TAB)
        beq     bad_prefix_key
        cmp     #HI(ASCII_DELETE)
        beq     :+
        cmp     #HI(ASCII_LEFT)
        bne     not_backspace
:       cpx     #$00
        beq     :+
        dec     CH
        dex
:       jsr     CLREOL
        jmp     input_loop

not_backspace:
        bcs     maybe_alphanumeric
bad_prefix_key:
        jsr     BELL
        jmp     input_loop

maybe_alphanumeric:
        cmp     #HI('Z')+1
        bcc     :+
        and     #%11011111      ; convert uppercase to lowercase
:       cmp     #HI('.')
        bcc     bad_prefix_key
        cmp     #HI('Z')+1
        bcs     bad_prefix_key
        cmp     #HI('9')+1
        bcc     :+
        cmp     #HI('A')
        bcc     bad_prefix_key

        ;; Place character, if it fits
:       inx
        cpx     #39             ; screen max
        bcs     reprompt_for_prefix
        sta     PREFIX,x
        jsr     COUT
        jmp     input_loop

try_set_prefix:
        cpx     #0
        beq     PromptForPathname
        stx     PREFIX
        MLI_CALL SET_PREFIX, get_prefix_params
        bcc     PromptForPathname
        jsr     BELL
        lda     #$00

reprompt_for_prefix_relay:
        beq     reprompt_for_prefix ; used as a relay

.endproc

;;; ============================================================

.proc PromptForPathname
        jsr     HOME
        jsr     CROUT
        ldx     #msg_enter_pathname
        jsr     ShowMessage
reset_pathname:
        lda     #3
        sta     CV
        jsr     CROUT
        ldx     #0

input_loop:
        jsr     RDKEY
        cmp     #HI(ASCII_ESCAPE)
        bne     :+
        lda     CH
        bne     PromptForPathname
        beq     PromptForPrefix::reprompt_for_prefix_relay

:       cmp     #HI(ASCII_CLEAR)
reprompt_for_pathname:          ; used as a relay
        beq     PromptForPathname
        cmp     #HI(ASCII_TAB)
        beq     bad_pathname_key
        cmp     #HI(ASCII_DELETE)
        beq     :+
        cmp     #HI(ASCII_LEFT)
        bne     not_backspace2
:       jmp     backspace

not_backspace2:
        bcs     maybe_alphanumeric2
bad_pathname_key:
        jsr     BELL
        jmp     input_loop

maybe_alphanumeric2:
        cmp     #HI(ASCII_CR)
        beq     try_launch_file

        cmp     #HI('Z')+1
        bcc     :+
        and     #%11011111      ; convert uppercase to lowercase
:       cmp     #HI('.')
        bcc     bad_pathname_key
        cmp     #HI('Z')+1
        bcs     bad_pathname_key
        cmp     #HI('9')+1
        bcc     :+
        cmp     #HI('A')
        bcc     bad_pathname_key

        ;; Place character, if it fits
:       pha
        jsr     CLREOL
        pla
        jsr     COUT
        inx
        cpx     #39             ; screen max
        bcs     reprompt_for_pathname
        sta     PREFIX,x
        jmp     input_loop

;;; --------------------------------------------------

try_launch_file:
        lda     #HI(' ')
        jsr     COUT
        stx     PREFIX
        MLI_CALL GET_FILE_INFO, get_file_info_params
        bcc     :+
        jmp     HandleError

:       lda     get_file_info_file_type
        cmp     #FT_SYSTEM
        beq     :+
        lda     #$01
        jmp     HandleError

:       lda     #$00
        sta     close_ref_num
        MLI_CALL CLOSE, close_params
        bcc     :+
        jmp     HandleError

:       lda     get_file_info_access
        and     #$01
        bne     :+
        lda     #ERR_IO_ERROR
        jmp     HandleError

:       MLI_CALL OPEN, open_params
        bcc     :+
        jmp     HandleError

:       lda     open_ref_num
        sta     read_ref_num
        sta     get_eof_ref_num
        MLI_CALL GET_EOF, get_eof_params
        bcs     HandleError
        lda     get_eof_eof+2
        beq     :+
        lda     #ERR_IO_ERROR
        bne     HandleError

:       lda     get_eof_eof
        sta     read_request_count
        lda     get_eof_eof+1
        sta     read_request_count+1
        MLI_CALL READ, read_params
        php
        MLI_CALL CLOSE, close_params
        bcc     launch
:       plp
        bne     HandleError
        plp
launch: bcs     :-
        jmp     SYS_ADDR

backspace:
        lda     CH
        beq     :+
        dex
        lda     #HI(' ')
        jsr     COUT
        dec     CH
        dec     CH
        jsr     COUT
        dec     CH
:       jmp     input_loop

.endproc

;;; ============================================================

.proc ShowMessage
loop:   lda     message_table,x
        beq     done
        jsr     COUT
        inx
        bne     loop
done:   rts
.endproc

;;; ============================================================

.proc HandleError
        tmp := $DE

        sta     tmp
        lda     #12
        sta     CV
        jsr     CROUT
        lda     tmp

        cmp     #$01
        bne     :+
        ldx     #msg_not_sys
        bne     show            ; always

:       cmp     #ERR_INVALID_PATHNAME
        beq     not_found
        cmp     #ERR_PATH_NOT_FOUND
        beq     not_found
        cmp     #ERR_VOL_NOT_FOUND
        beq     not_found
        cmp     #ERR_FILE_NOT_FOUND
        beq     not_found
        ldx     #msg_io_error
        bne     show

not_found:
        ldx     #msg_not_found

show:   jsr     ShowMessage
        jmp     PromptForPathname::reset_pathname
.endproc

;;; ============================================================
;;; Messages
;;; ============================================================

message_table:

msg_enter_prefix := * - message_table
        scrcode "ENTER PREFIX (PRESS \"RETURN\" TO ACCEPT)"
        .byte   0

msg_enter_pathname := * - message_table
        scrcode "ENTER PATHNAME OF NEXT APPLICATION"
        .byte   0

msg_not_sys := * - message_table
        .byte   HI(ASCII_BELL)
        scrcode "NOT A TYPE \"SYS\" FILE"
        .byte   0

msg_io_error := * - message_table
        .byte   HI(ASCII_BELL)
        scrcode "I/O ERROR            "
        .byte   0

msg_not_found := * - message_table
        .byte   HI(ASCII_BELL)
        scrcode "FILE/PATH NOT FOUND  "
        .byte   0

;;; ============================================================
;;; ProDOS MLI Call Parameters
;;; ============================================================

;;; GET_FILE_INFO params

get_file_info_params:
        .byte   $A
get_file_info_pathname:
        .addr   PREFIX
get_file_info_access:
        .byte    0
get_file_info_file_type:
        .byte   0
get_file_info_aux_type:       .word   0
get_file_info_storage_type:   .byte   0
get_file_info_blocks_used:    .word   0
get_file_info_mod_date:       .word   0
get_file_info_mod_time:       .word   0
get_file_info_create_date:    .word   0
get_file_info_create_time:    .word   0

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
close_ref_num:
        .byte   0

;;; READ params

read_params:
        .byte   4
read_ref_num:
        .byte   0
read_data_buffer:
        .addr   SYS_ADDR
read_request_count:
        .word   0
read_trans_count:
        .word   0

;;; GET_EOF params

get_eof_params:
        .byte   2
get_eof_ref_num:
        .byte   0
get_eof_eof:
        .faraddr 0

;;; GET_PREFIX params

get_prefix_params:
        .byte   1
get_prefix_pathname:
        .addr   PREFIX

;;; ============================================================

.endproc
        install_size = $300
        poporg

;;; ************************************************************
        .include "../inc/driver_postamble.inc"
;;; ************************************************************
