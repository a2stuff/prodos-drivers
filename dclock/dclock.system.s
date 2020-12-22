; Fully disassembled and analyzed source to AE
; DCLOCK.SYSTEM by M.G. - 04/18/2017
; https://gist.github.com/mgcaret/7f0d7aeec169e90809c7cfaab9bf183b
; Further modified by @inexorabletash - 12/21/2020

; There are critical bugs in the original AE code:
; * When driver loader is initially probing it corrupts the
;   Apple //c Memory Expansion Card:
;   - it saves, but fails to restore, data at address $080000
;   - it fails to reset slinky pointer, and *will* trash $080000-$080007
; * When the clock is read, it corrupts data at address $08xx01
;   - John Brooks spotted this, [M.G.] totally missed this.
; This version of the code has fixes permanently applied.

        .setcpu "65C02"
        .linecont +
        .feature string_escapes

        .include "apple2.inc"
        .include "apple2.mac"
        .include "opcodes.inc"

        .include "../inc/apple2.inc"
        .include "../inc/macros.inc"
        .include "../inc/prodos.inc"

; zero page locations
SCRATCH         := $0B                          ; scratch value for BCD range checks
SAVEBYTE        := $0C                          ; slinky overwritten byte save location
BCDTMP          := $3A                          ; location clock driver uses for BCD->Binary

; buffers & other spaces
INBUF           := $0200                        ; input buffer
CLOCKBUF        := $0300                        ; clock buffer

; I/O and hardware
C8OFF           := $CFFF                        ; C8xx ROM off
SLOT4ROM        := $C400                        ; Slot 4 ROM space
SLOT4IO         := $C0C0                        ; Slot 4 I/O space
DPTRL           := SLOT4IO+0                    ; Slinky data ptr low
DPTRM           := SLOT4IO+1                    ; Slinky data ptr middle
DPTRH           := SLOT4IO+2                    ; Slinky data ptr high
DATA            := SLOT4IO+3                    ; Slinky data byte

;;; ************************************************************
        .include "../inc/driver_preamble.inc"
;;; ************************************************************

;;; ============================================================
;;;
;;; Driver Installer
;;;
;;; ============================================================

        .define PRODUCT "DClock"

;;; ============================================================
;;; Ensure there is not a previous clock driver installed.
;;; And that this is a IIc. And that the clock is present.

.proc maybe_install_driver
        lda     MACHID
        and     #$01            ; existing clock card?
        bne     done

        lda     VERSION         ; IIc identification byte 1
        cmp     #$06
        bne     done
        lda     ZIDBYTE         ; IIc identification byte 2
        cmp     #$00
        bne     done

        jsr     ClockRead
        jsr     ValidTime
        bcc     InstallDriver

        ;; Show failure message
        jsr     zstrout
        scrcode "\r\r\r", PRODUCT, " - Not Found."
        .byte   0

done:   rts
.endproc

; ----------------------------------------------------------------------------
; Install clock driver
.proc   InstallDriver

        ;; Copy into address at DATETIME vector, update the vector and
        ;; update MACHID bits to signal a clock is present.
        ptr := $A5

        ;; Update absolute addresses within driver
        lda     DATETIME+1
        sta     ptr
        clc
        adc     #(regulk - driver - 1)
        sta     regulk_addr
        lda     DATETIME+2
        sta     ptr+1
        adc     #0
        sta     regulk_addr+1

        ;; Copy driver into appropriate bank
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

        ;; Display success message
        jsr     zstrout
        scrcode "\r\r\r", PRODUCT, " - Installed  "
        .byte   0

        ;; Display the current date
        lda     DATELO+1        ; month
        ror     a
        pha
        lda     DATELO
        pha
        rol     a
        rol     a
        rol     a
        rol     a
        and     #%00001111
        jsr     cout_number

        lda     #HI('/')        ; /
        jsr     COUT

        pla                     ; day
        and     #%00011111
        jsr     cout_number

        lda     #HI('/')        ; /
        jsr     COUT

        pla                     ; year
        jsr     cout_number
        jsr     CROUT

        rts                     ; done!
.endproc

; ----------------------------------------------------------------------------
; enable slinky registers, set adddress and save byte we intend to trash
.proc   SlinkyEnable
        lda     C8OFF                           ; not needed on //c, but release $C8xx firmware
        lda     SLOT4ROM                        ; enable slinky registers
        lda     #$08                            ; set addr $080000
        sta     DPTRH
        stz     DPTRM
        stz     DPTRL
        lda     DATA                            ; read data byte
        sta     SAVEBYTE                        ; save it to restore later
        rts
.endproc
; ----------------------------------------------------------------------------
; Routine to restore trashed byte in slinky RAM
.proc   SlinkyRestore
        lda     #$08                            ; set adddr $080000
        sta     DPTRH
        stz     DPTRM
        stz     DPTRL
        lda     SAVEBYTE                        ; get saved byte
        sta     DATA                            ; and put it back
        lda     C8OFF                           ; not needed on //c, but release $C8xx firmware
        rts
.endproc
; ----------------------------------------------------------------------------
; Write 8 bits to clock
.proc   ClockWrite8b
        ldx     #$08                            ; set adddr $080000
        stx     DPTRH
        stz     DPTRM
:       stz     DPTRL                           ; restore low byte to 0
        sta     DATA                            ; write byte
        lsr     a                               ; next bit into 0 position
        dex
        bne     :-
        rts
.endproc
; ----------------------------------------------------------------------------
; unlock the clock by writing the magic bit sequence
.proc   ClockUnlock
        ldy     #$08
:       lda     unlock,y
        jsr     ClockWrite8b                    ; write 8 bits
        dey
        bne     :-
        rts
unlock  = * - 1
        .byte   $5c, $a3, $3a, $c5, $5c, $a3, $3a, $c5
.endproc
; ----------------------------------------------------------------------------
; Read 8 bits from the clock
.proc   ClockRead8b
        ldx     #$08                            ; set adddr $080000
        stz     DPTRL
        stz     DPTRM
        stx     DPTRH
:       pha                                     ; save accumulator
        lda     DATA                            ; get data byte
        lsr     a                               ; bit 0 into carry
        pla                                     ; restore accumulator
        ror     a                               ; put read bit into position
        dex
        bne     :-
        rts
.endproc
; ----------------------------------------------------------------------------
; read the clock data into memory at CLOCKBUF
; WARNING: unfixed code never restores byte we trashed
.proc   ClockRead
        jsr     SlinkyEnable
        jsr     ClockUnlock
        ldy     #$00
:       jsr     ClockRead8b
        sta     CLOCKBUF,y
        iny
        cpy     #$08                            ; have we read 8 bytes?
        bcc     :-                              ; nope
        jsr     SlinkyRestore
        rts
.endproc
; ----------------------------------------------------------------------------
; validate the DClock data makes sense
; return carry clear if it does, carry set if it does not
.proc   ValidTime
        ; validate ms
        ldx     #$00
        ldy     #$99
        lda     CLOCKBUF
        jsr     CheckBCD
        bcs     :+
        ; validate seconds
        ldx     #$00
        ldy     #$59
        lda     CLOCKBUF+$01
        jsr     CheckBCD
        bcs     :+
        ; validate minutes
        ldx     #$00
        ldy     #$59
        lda     CLOCKBUF+$02
        jsr     CheckBCD
        bcs     :+
        ; validate hours
        ldx     #$00
        ldy     #$23
        lda     CLOCKBUF+$03
        jsr     CheckBCD
        bcs     :+
        ; validate day of week
        ldx     #$01
        ldy     #$07
        lda     CLOCKBUF+$04
        jsr     CheckBCD
        bcs     :+
        ; validate day of month
        ldx     #$01
        ldy     #$31
        lda     CLOCKBUF+$05
        jsr     CheckBCD
        bcs     :+
        ; validate month
        ldx     #$01
        ldy     #$12
        lda     CLOCKBUF+$06
        jsr     CheckBCD
        bcs     :+
        ; validate year
        ldx     #$00
        ldy     #$99
        lda     CLOCKBUF+$07
        jsr     CheckBCD
        bcs     :+
        clc                                     ; all good
        rts
:       sec                                     ; problem
        rts
.endproc
; ----------------------------------------------------------------------------
; Check BCD number in range of [x,y]
; return carry clear if it is, carry set if it is not
.proc   CheckBCD
        sed                                     ; decimal mode
        stx     SCRATCH                         ; lower bound into scratch
        cmp     SCRATCH                         ; compare it
        bcc     :++                             ; fail if out of range
        sty     SCRATCH                         ; upper bound into scratch
        cmp     SCRATCH                         ; compare it
        beq     :+                              ; OK if equal
        bcs     :++                             ; fail if out of range
:       cld                                     ; in range
        clc
        rts
:       cld                                     ; not in range
        sec
        rts
.endproc

; ----------------------------------------------------------------------------
; clock driver code inserted into ProDOS

driver:
        lda     #$08                            ; useless instruction
        php
        sei
        lda     SLOT4ROM                        ; activate slinky registers
                                                ; ($08 from above overwritten)
        stz     DPTRL                           ; set slinky address to $08xx00
        ldy     #$08                            ; also counter for unlock bytes
        sty     DPTRH
        lda     DATA                            ; get destroyed byte
                                                ; (slinky now at $08xx01)
        pha                                     ; save value on stack
        ; unlock dclock registers
        regulk_addr := *+1
ubytlp: lda     regulk,y        ; self-modified
        ldx     #$08                            ; bit counter
ubitlp: stz     DPTRL                           ; reset pointer to $08xx00
        sta     DATA                            ; write to $08xx00
        lsr     a                               ; next bit into 0 position
        dex
        bne     ubitlp
        dey
        bne     ubytlp
        ; now read 64 bits (8 bytes) from dclock
        ldx     #$08                            ; byte counter
rbytlp: ldy     #$08                            ; bit counter
rbitlp: pha
        lda     DATA                            ; data byte
        lsr     a                               ; bit 0 into carry
        pla
        ror     a                               ; carry into bit 7
        dey
        bne     rbitlp
        ; got 8 bits now, convert from BCD to binary
        pha
        and     #$0F
        sta     BCDTMP
        pla
        and     #$F0
        lsr     a
        pha
        adc     BCDTMP
        sta     BCDTMP
        pla
        lsr     a
        lsr     a
        adc     BCDTMP
        ; place in input buffer, which is OK because the ThunderClock driver does this
        sta     INBUF-1,x
        dex
        bne     rbytlp
        ; done copying, now put necessary values into ProDOS time locations
        ; copy hours to ProDOS hours
        lda     INBUF+4
        sta     TIMEHI
        ; copy minutes to ProDOS minutes
        lda     INBUF+5
        sta     TIMELO
        ; copy month ...
        lda     INBUF+1
        lsr     a
        ror     a
        ror     a
        ror     a
        ; ... and day of month to ProDOS month/day
        ora     INBUF+2
        sta     DATELO
        ; copy year and final bit of month to ProDOS year/month
        lda     INBUF
        rol     a
        sta     DATEHI
        stz     DPTRL                           ; set slinky back to $08xx00
        pla                                     ; get saved byte
        sta     DATA                            ; put it back
        plp
        rts
; DS1215 unlock sequence (in reverse)
regulk  = * - 1
        .byte   $5C, $A3, $3A, $C5, $5C, $A3, $3A, $C5

        sizeof_driver := * - driver
        .assert sizeof_driver <= 125, error, "Clock code must be <= 125 bytes"

;;; ************************************************************
        .include "../inc/driver_postamble.inc"
;;; ************************************************************
