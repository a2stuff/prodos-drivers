;;; The Cricket Clock - ProDOS Patcher
;;; Disassembled from /CRICKET/PRODOS.MOD
;;; Original: Street Electronics Corporation (C) 1984

        .setcpu "6502"
        .include "apple2.inc"

        .org    $300

        ;; ProDOS System Global Page
DATETIME := $BF06               ; CLOCK CALENDAR ROUTINE.
DATELO   := $BF90               ; BITS 15-9=YR, 8-5=MO, 4-0=DAY
TIMELO   := $BF92               ; BITS 12-8=HR, 5-0=MIN; LOW-HI FORMAT.

        ;; SSC I/O Registers (for Slot 2)
TDREG    := $C088 + $20         ; ACIA Transmit Register (write)
RDREG    := $C088 + $20         ; ACIA Receive Register (read)
STATUS   := $C089 + $20         ; ACIA Status/Reset Register
COMMAND  := $C08A + $20         ; ACIA Command Register (read/write)
CONTROL  := $C08B + $20         ; ACIA Control Register (read/write)

.proc install
        ptr := $42

        ;; Copy driver to target in ProDOS
        lda     DATETIME+1
        sta     ptr
        lda     DATETIME+2
        sta     ptr+1
        lda     #$4C            ; JMP opcode
        sta     DATETIME
        lda     ROMIN           ; Write bank 2
        lda     ROMIN
        ldy     #sizeof_driver-1
loop:   lda     driver,y
        sta     (ptr),y
        dey
        bpl     loop

        ;; Simple exit when BRUN
        rts
.endproc

        ;; Driver - relocatable code. Called by ProDOS to update date/time bytes
.proc driver
        scratch := $3A          ; ZP scratch location

        ;; Initialize
        php
        sei
        lda     COMMAND         ; save status of command register
        pha

        ;; Configure SSC
        lda     #%00001011
        sta     COMMAND
        lda     #%10011110      ; 9600 baud, 8 data bits, 2 stop bits
        sta     CONTROL
:       lda     STATUS
        and     #(1 << 4)       ; transmit register empty? (bit 4)
        beq     :-              ; nope, keep waiting

        ;; Send command
        lda     #('@' | $80)    ; '@' command
        sta     TDREG

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
