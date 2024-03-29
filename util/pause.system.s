
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


.proc maybe_install_driver
        ldx     #4
:       lda     #$FF
        jsr     $FCA8           ; WAIT
        dex
        bne     :-
        rts
.endproc

;;; ************************************************************
        .include "../inc/driver_postamble.inc"
;;; ************************************************************
