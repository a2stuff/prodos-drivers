        .setcpu "6502"
        .linecont +
        .feature string_escapes

        .include "apple2.inc"
        .include "apple2.mac"
        .include "opcodes.inc"

        .include "../inc/apple2.inc"
        .include "../inc/macros.inc"
        .include "../inc/prodos.inc"

;;; ************************************************************
        .include "../inc/driver_preamble.inc"
;;; ************************************************************

;;; ============================================================
;;; Ensure there is not a previous clock driver installed.

.proc maybe_install_driver
        lda     MACHID
        and     #$01            ; existing clock card?
        beq     prompt          ; no, prompt for date/time

        rts                     ; yes, done!
.endproc

.proc prompt

date:
        jsr     log_message
        scrcode "Date: MM/DD/YY\x08\x08\x08\x08\x08\x08\x08\x08"
        ;; Offsets: .....01234567
        .byte   0

        jsr     GETLN2

        lda     INPUT_BUFFER+1
        jsr     shift_into_tmp
        lda     INPUT_BUFFER+0
        jsr     shift_into_tmp
        jsr     bcd_to_binary
        beq     date
        cmp     #13
        bcs     date
        sta     set_month

        lda     INPUT_BUFFER+4
        jsr     shift_into_tmp
        lda     INPUT_BUFFER+3
        jsr     shift_into_tmp
        jsr     bcd_to_binary
        beq     date
        cmp     #32
        bcs     date
        sta     set_day

        lda     INPUT_BUFFER+7
        jsr     shift_into_tmp
        lda     INPUT_BUFFER+6
        jsr     shift_into_tmp
        jsr     bcd_to_binary
        sta     set_year

        ;; --------------------------------------------------
        ;; Prompt for Time

time:
        jsr     log_message
        scrcode "Time: HH:MM\x08\x08\x08\x08\x08"
        ;; Offsets: .....01234567
        .byte   0

        jsr     GETLN2

        lda     INPUT_BUFFER+1
        jsr     shift_into_tmp
        lda     INPUT_BUFFER+0
        jsr     shift_into_tmp
        jsr     bcd_to_binary
        cmp     #24
        bcs     time
        sta     set_hours

        lda     INPUT_BUFFER+4
        jsr     shift_into_tmp
        lda     INPUT_BUFFER+3
        jsr     shift_into_tmp
        jsr     bcd_to_binary
        cmp     #60
        bcs     time
        sta     set_minutes

        ;; --------------------------------------------------
        ;; Set date/time

        ;; |     DATEHI    | |    DATELO     |
        ;;  7 6 5 4 3 2 1 0   7 6 5 4 3 2 1 0
        ;; +-+-+-+-+-+-+-+-+ +-+-+-+-+-+-+-+-+
        ;; |    Year     |  Month  |   Day   |
        ;; +-+-+-+-+-+-+-+-+ +-+-+-+-+-+-+-+-+


        lda     set_month
        asl
        asl
        asl
        asl
        asl
        ora     set_day
        sta     DATELO
        lda     set_year
        rol
        sta     DATEHI

        lda     set_minutes
        sta     TIMELO
        lda     set_hours
        sta     TIMEHI

;;; --------------------------------------------------

bcd_to_binary:
        ldy     #$FF            ; result = -1
        sec
        sed
:       iny                     ; result += 1
        sbc     #1              ; value -= 1
        bcs     :-
        cld
        tya                     ; A = result
        rts

;;; --------------------------------------------------

shift_into_tmp:
        and     #$0F
        ror
        ror     tmp
        ror
        ror     tmp
        ror
        ror     tmp
        ror
        ror     tmp

        lda     tmp
        rts

tmp:    .byte   0
.endproc

;;; ------------------------------------------------------------

set_year:       .byte   0
set_month:      .byte   0
set_day:        .byte   0
set_hours:      .byte   0
set_minutes:    .byte   0
set_seconds:    .byte   0

;;; ************************************************************
        .include "../inc/driver_postamble.inc"
;;; ************************************************************
