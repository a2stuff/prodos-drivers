;;; Test program for The Cricket!
;;; * Probes Slot 2 for Super Serial Card (or compatible)
;;; * Initializes SSC
;;; * Sends Cricket ID sequence

        .setcpu "6502"
        .linecont +

        .include "apple2.inc"
        .include "opcodes.inc"

        .include "./common.inc"

        .org $2000

        read_delay_hi = $3 * 3 ; ($300 iterations is normal * 3.6MHz)

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
        lda     #%00001011      ; no parity/echo/interrupts, RTS low, DTR low
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
        jsr     zstrout
        HIASCIIZ "Reading SSC: "

        jsr     readbyte
        bcs     cricket_not_found ; timeout
        cmp     #HI('C')          ; = 'C' ?
        bne     cricket_not_found

        jsr     readbyte
        bcs     cricket_not_found ; timeout
        bcc     digit

:       jsr     readbyte
        bcs     cricket_not_found ; timeout
        cmp     #HI(CR)           ; = CR ?
        beq     cricket_found
digit:  cmp     #HI('0')          ; < '0' ?
        bcc     cricket_not_found
        cmp     #HI('9' + 1)      ; > '9' ?
        bcs     cricket_not_found
        bcc     :-

        jmp     cricket_found

cricket_found:
        jsr     zstrout
        HIASCIIZ CR, "Cricket tentatively found.", CR
        jmp     exit

cricket_not_found:
        jsr     zstrout
        HIASCIIZ CR, "Cricket not identified.", CR
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

        jsr zstrout
        HIASCIIZ "... timeout!"

        sec                     ; failed
        rts

ready:  lda     RDREG           ; actually read the register
        pha
        jsr     COUT
        pla
        clc
        rts
.endproc



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
