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
        lda     #$f6            ; border: white on medium blue
        sta     TBCOLOR
        lda     #$06            ; border: medium blue
        sta     CLOCKCTL

        rts
.endproc

;;; ************************************************************
        .include "../inc/driver_postamble.inc"
;;; ************************************************************
