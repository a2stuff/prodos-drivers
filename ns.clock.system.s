;;; NS.CLOCK.SYSTEM
;;; Original by "CAP" 04/21/91
;;; http://www.apple2.org.za/gswv/a2zine/GS.WorldView/v1999/Oct/MISC/NSC.Disk.TXT

;;; Modification history available at:
;;; https://github.com/a2stuff/cricket

        .setcpu "6502"
        .linecont +
        .feature string_escapes

        .include "apple2.inc"
        .include "apple2.mac"
        .include "opcodes.inc"

        .include "inc/apple2.inc"
        .include "inc/macros.inc"
        .include "inc/prodos.inc"

;;; ************************************************************
        .include "driver_preamble.inc"
;;; ************************************************************

;;; ============================================================
;;;
;;; Driver Installer
;;;
;;; ============================================================

        .define PRODUCT "No-Slot Clock"

;;; ============================================================
;;; Ensure there is not a previous clock driver installed.

.proc maybe_install_driver
        lda     MACHID
        and     #$01            ; existing clock card?
        beq     detect_nsc      ; nope, check for NSC

        rts                     ; yes, done!
.endproc

;;; ------------------------------------------------------------
;;; Detect NSC. Scan slot ROMs and main ROMs. Try reading
;;; each location several times, and validate results before
;;; installing driver.

.proc detect_nsc
        ;; Preserve date/time
        ldy     #3              ; copy 4 bytes
:       lda     DATELO,y
        sta     saved,y
        dey
        bpl     :-

        ;; Check slot ROMs
        lda     #>$CFFF
        ldy     #<$CFFF
        sta     ld4+2
        sty     ld4+1
        sta     st4+2
        sty     st4+1
        lda     #0
        sta     slot
        lda     #3              ; treat slot 0 as slot 3

sloop:  ora     #$C0            ; A=$Cs
        sta     st1+2
rloop:  sta     ld1+2
        sta     ld2+2
        sta     st2+2

        lda     #3              ; 3 tries - need valid results each time
        sta     tries
try:    jsr     driver          ; try reading date/time
        lda     DATELO+1        ; check result
        ror     a
        lda     DATELO
        rol     a
        rol     a
        rol     a
        rol     a
        and     #$0F
        beq     next
        cmp     #13             ; month
        bcs     next
        lda     DATELO
        and     #$1F
        beq     next
        cmp     #32             ; day
        bcs     next
        lda     TIMELO+1
        cmp     #24             ; hours
        bcs     next
        lda     TIMELO
        cmp     #60             ; minutes
        bcs     next
        dec     tries
        bne     try
        beq     install_driver  ; all tries look valid
next:   inc     slot
        lda     slot
        cmp     #8
        bcc     sloop           ; next slot
        bne     not_found

        ;; Not found in slot ROM, try main ROMs ???
        lda     #>$C015
        ldy     #<$C015
        sta     ld4+2
        sty     ld4+1
        ldy     #$07
        sta     st1+2
        sty     st1+1
        dey
        sta     st4+2
        sty     st4+1
        lda     #>$C800
        bne     rloop

        ;; Restore date/time
not_found:
        ldy     #3
:       lda     saved,y
        sta     DATELO,y
        dey
        bpl     :-

        ;; Show failure message
        jsr     zstrout
        scrcode "\r\r\r", PRODUCT, " - Not Found."
        .byte   0

        rts

saved:  .byte   0, 0, 0, 0
tries:  .byte   3
slot:   .byte   0
.endproc

;;; ------------------------------------------------------------
;;; Install NSC Driver. Copy into address at DATETIME vector,
;;; update the vector and update MACHID bits to signal a clock
;;; is present.

.proc install_driver
        ptr := $A5

        lda     DATETIME+1
        sta     ptr
        clc
        adc     #(unlock - driver - 1)
        sta     ld3+1
        lda     DATETIME+2
        sta     ptr+1
        adc     #0
        sta     ld3+2
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

;;; ============================================================
;;; NSC driver - modified as needed and copied into ProDOS
;;; ============================================================

driver:
        php
        sei
ld4:    lda     $CFFF           ; self-modified
        pha
st1:    sta     $C300           ; self-modified
ld1:    lda     $C304           ; self-modified
        ldx     #8

        ;; Unlock the NSC by bit-banging.
uloop:
ld3:    lda     unlock-1,x      ; self-modified
        sec
        ror     a               ; a bit at a time
:       pha
        lda     #0
        rol     a
        tay
ld2:    lda     $C300,y         ; self-modified
        pla
        lsr     a
        bne     :-
        dex
        bne     uloop

        ;; Read 8 bytes * 8 bits of clock data into $200...$207
        ldx     #8
bloop:  ldy     #8
st2:
:       lda     $C304           ; self-modified
        ror     a
        ror     $01FF,x
        dey
        bne     :-
        lda     $01FF,x         ; got 8 bits

        lsr     a               ; BCD to binary
        lsr     a               ; shift out tens
        lsr     a
        lsr     a
        tay
        beq     donebcd
        lda     $01FF,x
        and     #$0F            ; mask out units
        clc
:       adc     #10             ; and add tens as needed
        dey
        bne     :-
        sta     $01FF,x
donebcd:
        dex
        bne     bloop

        ;; Now $200...$207 is y/m/d/w/H/M/S/f

        ;; Update ProDOS date/time.
        lda     $0204           ; hour
        sta     TIMELO+1

        lda     $0205           ; minute
        sta     TIMELO

        lda     $0201           ; month
        asl     a
        asl     a
        asl     a
        asl     a
        asl     a

        ora     $0202           ; day
        sta     DATELO

        lda     $0200           ; year
        rol     a
        sta     DATELO+1

        pla
        bmi     done
st4:    sta     $CFFF           ; self-modified
done:   plp
        rts

unlock:
        ;; NSC unlock sequence
        .byte   $5C, $A3, $3A, $C5
        .byte   $5C, $A3, $3A, $C5
        .byte   $00

        sizeof_driver := * - driver
        .assert sizeof_driver <= 125, error, "Clock code must be <= 125 bytes"


;;; ************************************************************
        .include "driver_postamble.inc"
;;; ************************************************************
