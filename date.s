;;; Query ProDOS and print the current date/time
;;; (No dependency on Cricket clock)

;;; Output is: MM/DD/YY  HH:MM

        .setcpu "6502"
        .org    $2000

        .include "apple2.inc"
        .include "common.inc"

start:
        PRODOS_CALL MLI_GET_TIME, 0

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
        jsr     cout_number

        lda     #HI(':')        ; ':'
        jsr     COUT

        lda     TIMELO          ; minute
        jsr     cout_number

        jsr     CROUT

        rts

pm_flag:
        .byte   0

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
