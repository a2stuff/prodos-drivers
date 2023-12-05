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

        .undef PRODUCT
        .define PRODUCT "Jumbo Clock Driver"

.proc maybe_install_driver
        lda     MACHID
        and     #$01            ; existing clock card?
        bne     check_thunderclock

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

.proc check_thunderclock
         ;; Look for Thunderclock year table
        bit     RWRAM1
        bit     RWRAM1

        lda     #<table_1982
        ldx     #>table_1982
        jsr     check_sig
        beq     update_table

        lda     #<table_1986
        ldx     #>table_1986
        jsr     check_sig
        beq     update_table

        lda     #<table_1993
        ldx     #>table_1993
        jsr     check_sig
        beq     update_table

        lda     #<table_2018
        ldx     #>table_2018
        jsr     check_sig
        beq     update_table

        ;; Table not found - we have a clock but don't
        ;; know what it is, so don't log anything.
        bit     ROMIN2
        rts

        ;; ----------------------------------------

        ;; Copy the latest table into place
update_table:
        ldx     #SIG_LEN-1
:       lda     table_2023,x
        sta     SIG_ADDR,x
        dex
        bpl     :-

        bit     ROMIN2
.if ::LOG_SUCCESS
        ;; Display success message, to confirm table updates.
        jsr     log_message
        scrcode "ThunderClock - "
        .byte   0

        ;; Display the current date
        jsr     cout_date
.endif ; ::LOG_SUCCESS
        rts

        ;; ----------------------------------------

check_sig:
        ptr := $06
        sta     ptr
        stx     ptr+1
        ldy     #SIG_LEN-1
:       lda     (ptr),y
        cmp     SIG_ADDR,y
        bne     :+              ; Z=0 for no match
        dey
        bpl     :-
        iny                     ; Z=1 for match
:       rts

SIG_LEN = 7
SIG_ADDR := $D7B8

table_1982:                     ; ProDOS 1.1.1
        .byte   $54, $54, $53, $52, $57, $56, $55

table_1986:                     ; ProDOS 1.3 - 1.9
        .byte   $5A, $59, $58, $58, $57, $56, $5B

table_1993:                     ; ProDOS 2.0.3
        .byte   $60, $5F, $5E, $5D, $62, $61, $60

table_2018:                     ; ProDOS 2.4.2
        .byte   $12, $17, $16, $15, $14, $14, $13

table_2023:
        .byte   $18, $17, $1C, $1B, $1A, $19, $18
.endproc

;;; ************************************************************
        .include "../../inc/driver_postamble.inc"
;;; ************************************************************
