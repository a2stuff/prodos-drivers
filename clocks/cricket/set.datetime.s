;;; SET.DATETIME utility for The Cricket!
;;; Prompts for date and time and updates Cricket.

        .setcpu "6502"
        .linecont +
        .feature string_escapes

        .include "apple2.inc"
        .include "apple2.mac"

        .include "../../inc/apple2.inc"
        .include "../../inc/macros.inc"
        .include "../../inc/ascii.inc"

        .org $2000

.proc main
        ;; --------------------------------------------------
        ;; Date

        jsr     zstrout
        scrcode "\rDate: WWW MM/DD/YY\x08\x08\x08\x08\x08\x08\x08\x08\x08\x08\x08\x08"
        .byte   0

        jsr     GETLN2

        php
        sei

        ;; Reset SSC
        sta     KBDSTRB         ; Port 2 DSR line connected to KBDSTRB
        lda     #0
        sta     COMMAND
        sta     CONTROL

        ;; Configure SSC
        lda     #%00001011      ; no parity/echo/interrupts, RTS low, DTR low
        sta     COMMAND
        lda     #%10011110      ; 9600 baud, 8 data bits, 2 stop bits
        sta     CONTROL

        ;; Clock Commands
        ;; Set Date "SD WWW MM/DD/YY"
        lda     #HI('S')
        jsr     sendbyte
        lda     #HI('D')
        jsr     sendbyte
        lda     #HI(' ')
        jsr     sendbyte

        ldx     #0
:       lda     INPUT_BUFFER,x
        jsr     sendbyte
        inx
        cmp     #HI(ASCII_CR)
        bne     :-

        plp

        ;; --------------------------------------------------
        ;; Time

        jsr     zstrout
        scrcode "\rTime: HH:MM:SS\x08\x08\x08\x08\x08\x08\x08\x08"
        .byte   0

        jsr     GETLN2

        php
        sei

        ;; Reset SSC
        sta     KBDSTRB         ; Port 2 DSR line connected to KBDSTRB
        lda     #0
        sta     COMMAND
        sta     CONTROL

        ;; Configure SSC
        lda     #%00001011      ; no parity/echo/interrupts, RTS low, DTR low
        sta     COMMAND
        lda     #%10011110      ; 9600 baud, 8 data bits, 2 stop bits
        sta     CONTROL

        ;; Clock Commands
        ;; Set Time "ST HH:MM:SS"
        lda     #HI('S')
        jsr     sendbyte
        lda     #HI('T')
        jsr     sendbyte
        lda     #HI(' ')
        jsr     sendbyte

        ldx     #0
:       lda     INPUT_BUFFER,x
        jsr     sendbyte
        inx
        cmp     #HI(ASCII_CR)
        bne     :-

        plp

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

