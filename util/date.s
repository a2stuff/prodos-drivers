;;; Query ProDOS and print the current date/time

;;; Output is: MM/DD/YY  HH:MM

        .setcpu "6502"
        .org    $2000

        .include "apple2.inc"

        .include "../inc/apple2.inc"
        .include "../inc/macros.inc"
        .include "../inc/prodos.inc"

start:
        MLI_CALL GET_TIME, 0

;;;           DATEHI ($BF91)    DATELO ($BF90)
;;;           7 6 5 4 3 2 1 0   7 6 5 4 3 2 1 0
;;;          +-+-+-+-+-+-+-+-+ +-+-+-+-+-+-+-+-+
;;; DATE:    |    year     |  month  |   day   |
;;;          +-+-+-+-+-+-+-+-+ +-+-+-+-+-+-+-+-+
;;;
;;;           TIMEHI ($BF93)    TIMELO ($BF92)
;;;           7 6 5 4 3 2 1 0   7 6 5 4 3 2 1 0
;;;          +-+-+-+-+-+-+-+-+ +-+-+-+-+-+-+-+-+
;;; TIME:    |0 0 0|   hour  | |0 0|  minute   |
;;;          +-+-+-+-+-+-+-+-+ +-+-+-+-+-+-+-+-+

        ;; Date

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

        lda     #HI('/')       ; /
        jsr     COUT

        pla                     ; day
        and     #%00011111
        jsr     cout_number

        lda     #HI('/')       ; /
        jsr     COUT

        pla                     ; year
        jsr     cout_number

        lda     #HI(' ')
        jsr     COUT
        jsr     COUT

        ;; Time

        lda     TIMELO+1        ; hour
        and     #%00011111
        jsr     cout_number

        lda     #HI(':')        ; ':'
        jsr     COUT

        lda     TIMELO          ; minute
        and     #%00111111
        jsr     cout_number

        jsr     CROUT

        rts

;;; ------------------------------------------------------------

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
        txa
        jsr     COUT

units:  pla
        ora     #HI('0')
        jsr     COUT
        rts
.endproc
