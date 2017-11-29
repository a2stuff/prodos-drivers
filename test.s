
        .setcpu "6502"
        .linecont +

        .include "apple2.inc"
        .include "opcodes.inc"

        .include "./common.inc"

        .org $2000

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

        jsr     zstrout
        HIASCIIZ "SSC found.", CR
        jmp     init_ssc

ssc_not_found:
        jsr     zstrout
        HIASCIIZ "SSC not found.", CR
        rts

        ;; TODO: Write NUL and check for 'C' ... version ... $8D (CR)
        ;; https://github.com/inexorabletash/cricket/issues/3
init_ssc:
        lda     COMMAND         ; save status of SSC registers
        sta     saved_command
        lda     CONTROL
        sta     saved_control

        ;; Configure SSC
        lda     #%00001011
        sta     COMMAND
        lda     #%10011110      ; 9600 baud, 8 data bits, 2 stop bits
        sta     CONTROL

        ;; Miscellaneous Commands
        ;; Read Cricket ID code: 00 ($00)
        lda     #0
        jsr     sendbyte

        ;; "The Cricket will return a "C" (195, $C3) followed
        ;; by a version number (in ASCII) and a carriage return (141,
        ;; $8D)."
        jsr     readbyte
        bcs     cricket_not_found ; timeout
        cmp     #HI('C')          ; = 'C' ?
        bne     cricket_not_found

:       jsr     readbyte
        bcs     cricket_not_found ; timeout
        cmp     #HI(CR)           ; = CR ?
        beq     cricket_found
        cmp     #HI('0')          ; < '0' ?
        bcc     cricket_not_found
        cmp     #HI('9' + 1)      ; > '9' ?
        bcs     cricket_not_found
        bcc     :-

        jmp     cricket_found

cricket_found:
        jsr     zstrout
        HIASCIIZ "Cricket tentatively found.", CR
        jmp     exit

cricket_not_found:
        jsr     zstrout
        HIASCIIZ "Cricket not identified.", CR
        jmp     exit

exit:
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
        tries := $300
        lda #<tries
        sta counter
        lda #>tries
        sta counter+1

check:  lda     STATUS          ; did we get it?
        and     #(1 << 3)       ; receive register full? (bit 3)
        bne     ready           ; yes, we read the value

        dec     counter
        bne     check
        dec     counter+1
        bne     check

        sec                     ; failed
        rts

ready:  clc
        rts

counter:        .word   0
.endproc



;;; ------------------------------------------------------------
;;; Cricket Clock Driver - copied into ProDOS

.proc driver
        scratch := $3A          ; ZP scratch location

        ;; Initialize
        php
        sei
        lda     COMMAND         ; save status of command register
        pha

        read_len := 7           ; read 7 bytes (w/m/d/y/H/M/S)

        ;; Read response, pushing to stack
        ldy     #(read_len-1)

rloop:  ldx     #0              ; x = retry loop counter low byte
        lda     #3              ; scratch = retry loop counter high byte
        sta     scratch         ; ($300 iterations total)

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

;;; ------------------------------------------------------------
;;; Output a high-ascii, null-terminated string.
;;; String immediately follows the JSR.

.proc zstrout
        ptr := $A5

        pla                     ; read address from stack
        sta     ptr
        pla
        sta     ptr+1
        bne     skip            ; always (since data not on ZP)

next:   jsr     COUT
skip:   inc     ptr
        bne     :+
        inc     ptr+1
:       ldy     #0
        lda     (ptr),y
        bne     next

        lda     ptr+1           ; restore address to stack
        pha
        lda     ptr
        pha
        rts
.endproc

;;; ------------------------------------------------------------
