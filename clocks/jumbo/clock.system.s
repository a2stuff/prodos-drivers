;;; "Jumbo" Clock Driver
;;;
;;; Pulls in several clock drivers sources and tries each one in sequence.
;;;

        JUMBO_CLOCK_DRIVER = 1

        .setcpu "6502"
        .linecont +
        .feature string_escapes

        .include "apple2.inc"
        .include "apple2.mac"
        .include "opcodes.inc"

        .include "../../inc/apple2.inc"
        .include "../../inc/macros.inc"
        .include "../../inc/prodos.inc"
        .include "../../inc/ascii.inc"

;;; ************************************************************
        .include "../../inc/driver_preamble.inc"
;;; ************************************************************

.scope ns_clock
        .include "../ns.clock/ns.clock.system.s"
.endscope
.scope romx
        .include "../romx/romxrtc.system.s"
.endscope
.scope dclock
        .include "../dclock/dclock.system.s"
.endscope
.scope fujinet
        .include "../fujinet/fn.clock.system.s"
.endscope
.scope cricket
        .include "../cricket/cricket.system.s"
.endscope

;;; ============================================================
;;;
;;; Driver Installer
;;;
;;; ============================================================

        .define PRODUCT "Jumbo Clock Driver"

.proc maybe_install_driver
        lda     MACHID
        and     #$01            ; existing clock card?
        bne     ret

        jsr     ns_clock::maybe_install_driver
        bcc     ret

        jsr     romx::maybe_install_driver
        bcc     ret

        jsr     dclock::maybe_install_driver
        bcc     ret

        jsr     fujinet::maybe_install_driver
        bcc     ret

        jsr     cricket::maybe_install_driver
        bcc     ret

ret:    rts
.endproc


;;; ************************************************************
        .include "../../inc/driver_postamble.inc"
;;; ************************************************************
