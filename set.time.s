        .setcpu "6502"
        .linecont +

        .include "apple2.inc"
        .include "./common.inc"

        .org $2000

.proc main
        jsr     zstrout
        HIASCII CR, "Time: HH:MM:SS XM"
        HIASCII BS, BS, BS, BS, BS, BS
        HIASCII BS, BS, BS, BS, BS
        .byte   0

        jsr     GETLN2

        ;; Configure SSC
        lda     #%00001011      ; no parity/echo/interrupts, RTS low, DTR low
        sta     COMMAND
        lda     #%10011110      ; 9600 baud, 8 data bits, 2 stop bits
        sta     CONTROL

        ;; Clock Commands
        ;; Set Time "ST HH:MM:SS:XM"
        lda     #HI('S')
        jsr     sendbyte
        lda     #HI('T')
        jsr     sendbyte
        lda     #HI(' ')
        jsr     sendbyte

        ldx     #0
loop:   lda     INPUT_BUFFER,x
        jsr     sendbyte
        inx
        cmp     #HI(CR)
        bne     loop

        rts
.endproc

        ;; Write byte in A to SSC
.proc sendbyte
        pha
:       lda     STATUS
        and     #(1 << 4)       ; transmit register empty? (bit 4)
        beq     :-              ; nope, keep waiting
        pla
        sta     TDREG
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
