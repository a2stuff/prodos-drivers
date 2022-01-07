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
        lda     #$5a            ; text: dark gray on light gray
        sta     TBCOLOR
        lda     #$0a            ; border: gray
        sta     CLOCKCTL

        rts
.endproc

;;; ************************************************************
        .include "../inc/driver_postamble.inc"
;;; ************************************************************
