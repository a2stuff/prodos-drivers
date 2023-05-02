;;; ProDOS driver for the Fujinet clock
;;; Adapted from: https://github.com/a2stuff/prodos-drivers/blob/main/cricket/cricket.system.s

.ifndef JUMBO_CLOCK_DRIVER
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
.endif ; JUMBO_CLOCK_DRIVER

;;; ************************************************************
.ifndef JUMBO_CLOCK_DRIVER
        .include "../../inc/driver_preamble.inc"
.endif ; JUMBO_CLOCK_DRIVER
;;; ************************************************************

        .include "./smartport.inc"

FN_CLOCK_DEVICE_TYPE := $13 ; As defined on the Fujinet firmware

;;; ============================================================
;;;
;;; Driver Installer
;;;
;;; ============================================================

        .undef PRODUCT
        .define PRODUCT "Fujinet Clock"

;;; ============================================================
;;; Ensure there is not a previous clock driver installed.

.proc maybe_install_driver

        lda     MACHID
        and     #$01            ; existing clock card?
        beq     detect_fujinet_clock  ; nope, check for clock

        rts                     ; yes, done!
.endproc

;;; ============================================================
;;; Fujinet Clock Driver - copied into ProDOS
;;; ============================================================

.proc driver
        scratch := $3A          ; ZP scratch location

        ;; Initialize
        php
        sei

        ;; Execute smartport command
        jsr     $c50d           ; To be changed to the detected slot and address
drv_call_hi = *-1
drv_call_lo = *-2
        .byte   DRIVER_COMMAND_STATUS ; Command Status
params_address:
        .word   params - driver ; To be changed on relocation

        ;; Restore state and return
        sta     $CFFF ; release C8xx ROM space
        plp
        rts

params: .byte   $03 ; Status param count
port:   .byte   $00 ; Smartport device
        .word   DATELO ; Write directly on the four bytes reserved by Prodos for date and time
        .byte   'P' ; Get datetime in ProDDOS format

.endproc
        .assert .sizeof(driver) <= 125, error, "Clock code must be <= 125 bytes"


;;; ------------------------------------------------------------
;;; Detect Fujinet Clock.

.proc detect_fujinet_clock

        ;; Search for smartport cards
        ldx     #$C7 ; Start the search from slot 7
search_slot:
        jsr     find_smartport
        bcs     not_found

        ;; Find a Fujinet Clock device on this slot
        jsr     setup_smartport
        jsr     device_count
        cpx     #$0
        beq     continue_slot_search; no devices in the slot

search_unit:
        jsr     unit_type
        cmp     #FN_CLOCK_DEVICE_TYPE
        beq     found
        dex
        bne     search_unit
continue_slot_search:
        ldx     sp_call_hi ; restore card
        dex
        cpx     #$C0
        bne     search_slot
        jmp     not_found
found:
        ; Modify the driver code with the detected data
        stx     driver::port
        lda     sp_call_lo
        sta     driver::drv_call_lo
        lda     sp_call_hi
        sta     driver::drv_call_hi

        jmp     install_driver

not_found:
.ifndef JUMBO_CLOCK_DRIVER
.if ::LOG_FAILURE
        ;; Show failure message
        jsr     log_message
        scrcode PRODUCT, " - Not Found."
        .byte   0
.endif ; ::LOG_FAILURE
.endif ; JUMBO_CLOCK_DRIVER

        sec                     ; failure
        rts
.endproc

;;; ------------------------------------------------------------
;;; Install Driver. Copy into address at DATETIME vector,
;;; update the vector and update MACHID bits to signal a clock
;;; is present.

.proc install_driver
        ptr := $A5

        ;; Find driver destination
        lda     DATETIME+1
        sta     ptr
        lda     DATETIME+2
        sta     ptr+1

        ;; Fix pointers
        clc
        lda     ptr
        adc     driver::params_address
        sta     driver::params_address
        lda     ptr+1
        adc     driver::params_address+1
        sta     driver::params_address+1

        ;; Copy code
        lda     RWRAM1
        lda     RWRAM1
        ldy     #.sizeof(driver)-1

loop:   lda     driver,y
        sta     (ptr),y
        dey
        bpl     loop

        ;; Set the "Recognizable Clock Card" bit
        lda     MACHID
        ora     #$01
        sta     MACHID

        lda     #OPC_JMP_abs
        sta     DATETIME

        ;; Invoke the driver to init the time
        jsr     DATETIME

        lda     ROMIN2

.if ::LOG_SUCCESS
        ;; Display success message
        jsr     log_message
        scrcode PRODUCT, " - "
        .byte   0

        ;; Display the current date
        jsr     cout_date
.endif ; ::LOG_SUCCESS

        clc                     ; success
        rts                     ; done!
.endproc


;;; ************************************************************
.ifndef JUMBO_CLOCK_DRIVER
        .include "../../inc/driver_postamble.inc"
.endif ; JUMBO_CLOCK_DRIVER
;;; ************************************************************
