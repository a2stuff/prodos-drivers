        .setcpu "6502"

        .include "apple2.inc"
        .include "apple2.mac"

        .include "../inc/apple2.inc"
        .include "../inc/macros.inc"
        .include "../inc/prodos.inc"

;;; ************************************************************
        .include "../inc/driver_preamble.inc"
;;; ************************************************************

.proc maybe_install_driver
        bit     ROMIN2
        sta     CLR80VID
        sta     CLRALTCHAR
        sta     CLR80COL
        jsr     SETVID
        jsr     SETKBD
        jsr     SETNORM
        jsr     INIT
        jsr     HOME

        lda     #$0f            ; text: black on white
        sta     TBCOLOR
        lda     #$0f            ; border: white
        sta     CLOCKCTL

        rts
.endproc

;;; ************************************************************
        .include "../inc/driver_postamble.inc"
;;; ************************************************************
