;;; The Cricket Clock - ProDOS System
;;; Adapted from /CRICKET/PRODOS.MOD
;;; Original: Street Electronics Corporation (C) 1984

;;; Adapted from: /NO.SLOT.CLOCK/NS.CLOCK.SYSTEM
;;; Original by "CAP" 04/21/91
;;; http://www.apple2.org.za/gswv/a2zine/GS.WorldView/v1999/Oct/MISC/NSC.Disk.TXT

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

;;; ============================================================
;;;
;;; Driver Installer
;;;
;;; ============================================================

        read_delay_hi = $3 * 3 ; ($300 iterations is normal * 3.6MHz)

.ifndef JUMBO_CLOCK_DRIVER
        .define PRODUCT "Cricket Clock"
.endif ; JUMBO_CLOCK_DRIVER

;;; ============================================================
;;; Ensure there is not a previous clock driver installed.

.proc maybe_install_driver
        lda     MACHID
        and     #$01            ; existing clock card?
        beq     detect_cricket  ; nope, check for Cricket

        rts                     ; yes, done!
.endproc

;;; ------------------------------------------------------------
;;; Detect Cricket. Detect SSC and if present probe device.

.proc detect_cricket

        ;; Check Slot 2 for SSC. ID bytes per:
        ;; Apple II Technical Note #8: Pascal 1.1 Firmware Protocol ID Bytes
        lda     $C205
        cmp     #$38
        bne     ssc_not_found
        lda     $C207
        cmp     #$18
        bne     ssc_not_found
        lda     $C20B
        cmp     #$01
        bne     ssc_not_found
        lda     $C20C
        cmp     #$31
        bne     ssc_not_found

        beq     init_ssc
ssc_not_found:
        jmp     not_found

        ;; Init SSC and try the "Read Cricket ID code" sequence.
init_ssc:
        lda     COMMAND         ; save status of SSC registers
        sta     saved_command
        lda     CONTROL
        sta     saved_control

        ;; Configure SSC
        lda     #%00001011      ; no parity/echo/interrupts, RTS low, DTR low
        sta     COMMAND
        lda     #%10011110      ; 9600 baud, 8 data bits, 2 stop bits
        sta     CONTROL

        ;; Read Cricket ID code: 00 ($00)
        lda     #0
        jsr     sendbyte

        ;; "The Cricket will return a "C" (195, $C3) followed by a
        ;; version number (in ASCII) and a carriage return (141, $8D)."
        jsr     readbyte
        bcs     cricket_not_found ; timeout
        cmp     #HI('C')          ; = 'C' ?
        bne     cricket_not_found

        jsr     readbyte
        bcs     cricket_not_found ; timeout
        bcc     digit

:       jsr     readbyte
        bcs     cricket_not_found ; timeout
        cmp     #HI(ASCII_CR)
        beq     cricket_found
digit:  cmp     #HI('0')          ; < '0' ?
        bcc     cricket_not_found
        cmp     #HI('9' + 1)      ; > '9' ?
        bcs     cricket_not_found
        bcc     :-

cricket_found:
        jsr     restore_cmd_ctl
        jmp     install_driver

cricket_not_found:
        jsr     restore_cmd_ctl
        ;; fall through...

not_found:
.ifndef JUMBO_CLOCK_DRIVER
        ;; Show failure message
        jsr     log_message
        scrcode PRODUCT, " - Not Found."
        .byte   0
.endif ; JUMBO_CLOCK_DRIVER

        sec                     ; failure
        rts

restore_cmd_ctl:
        lda     saved_control
        sta     CONTROL
        lda     saved_command
        sta     COMMAND
        rts

saved_command:  .byte   0
saved_control:  .byte   0
.endproc

        ;; Write byte in A
.proc sendbyte
        pha
:       lda     STATUS
        and     #(1 << 4)       ; transmit register empty? (bit 4)
        beq     :-              ; nope, keep waiting
        pla
        sta     TDREG
        rts
.endproc

        ;; Read byte into A, or carry set if timed out
.proc readbyte
        tries := $100 * read_delay_hi
        counter := $A5

        lda     #<tries
        sta     counter
        lda     #>tries
        sta     counter+1

check:  lda     STATUS          ; did we get it?
        and     #(1 << 3)       ; receive register full? (bit 3)
        bne     ready           ; yes, we read the value

        dec     counter
        bne     check
        dec     counter+1
        bne     check

        sec                     ; failed
        rts

ready:  lda     RDREG           ; actually read the register
        clc
        rts
.endproc

;;; ------------------------------------------------------------
;;; Install Cricket Driver. Copy into address at DATETIME vector,
;;; update the vector and update MACHID bits to signal a clock
;;; is present.

.proc install_driver
        ptr := $A5

        lda     DATETIME+1
        sta     ptr
        lda     DATETIME+2
        sta     ptr+1
        lda     RWRAM1
        lda     RWRAM1
        ldy     #sizeof_driver-1

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

.ifndef JUMBO_CLOCK_DRIVER
        ;; Display success message
        jsr     log_message
        scrcode PRODUCT, " - "
        .byte   0

        ;; Display the current date
        jsr     cout_date
.endif ; JUMBO_CLOCK_DRIVER

        clc                     ; success
        rts                     ; done!
.endproc

;;; ============================================================
;;; Cricket Clock Driver - copied into ProDOS
;;; ============================================================

.proc driver
        scratch := $3A          ; ZP scratch location

        ;; Initialize
        php
        sei
        lda     COMMAND         ; save status of command register
        pha

        ;; Configure SSC
        lda     #%00001011      ; no parity/echo/interrupts, RTS low, DTR low
        sta     COMMAND
        lda     #%10011110      ; 9600 baud, 8 data bits, 2 stop bits
        sta     CONTROL

        ;; Send command
:       lda     STATUS
        and     #(1 << 4)       ; transmit register empty? (bit 4)
        beq     :-              ; nope, keep waiting
        lda     #HI('@')        ; '@' command
        sta     TDREG

        read_len := 7           ; read 7 bytes (w/m/d/y/H/M/S)

        ;; Read response, pushing to stack
        ldy     #(read_len-1)

rloop:  ldx     #0              ; x = retry loop counter low byte
        lda     #read_delay_hi  ; scratch = retry loop counter high byte
        sta     scratch

check:  lda     STATUS          ; did we get it?
        and     #(1 << 3)       ; receive register full? (bit 3)
        bne     ready           ; yes, we read the value

        inx                     ; not yet, so keep trying
        bne     check           ; until counter runs out
        dec     scratch
        bne     check

        ;; Read failed - restore stack and exit
reset:  cpy     #(read_len-1)   ; anything left to restore?
        beq     done            ; nope, exit
        pla                     ; yep, clear it off the stack
        iny
        bne     reset

        ;; Read succeeded - stuff it on the stack and continue
ready:  lda     RDREG
        pha
        dey
        bpl     rloop

        ;; Convert pushed response to ProDOS time field
        pla                     ; day of week (unused)

        pla                     ; minute
        sta     TIMELO          ; -- stored as-is (TIMELO 5-0)

        pla                     ; hour
        sta     TIMELO+1        ; -- stored as-is (TIMELO 12-8)

        pla                     ; year
        sta     DATELO+1        ; -- will be shifted up by 1 (DATELO 15-9)

        pla                     ; day
        and     #%00011111      ; -- masked, stored as is (DATELO 4-0)
        sta     DATELO

        pla                     ; month
        asl     a               ; -- shifted up (DATELO 8-5)
        asl     a
        asl     a
        asl     a
        asl     a
        ora     DATELO          ; -- merge low 5 bits
        sta     DATELO
        rol     DATELO+1

        pla                     ; seconds (unused)

        ;; Restore prior state
done:   pla                     ; restore saved command state
        sta     COMMAND
        plp
        rts
.endproc
        sizeof_driver := .sizeof(driver)
        .assert sizeof_driver <= 125, error, "Clock code must be <= 125 bytes"

;;; ************************************************************
.ifndef JUMBO_CLOCK_DRIVER
        .include "../../inc/driver_postamble.inc"
.endif ; JUMBO_CLOCK_DRIVER
;;; ************************************************************
