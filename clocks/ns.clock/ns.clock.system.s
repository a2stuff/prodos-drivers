;;; NS.CLOCK.SYSTEM
;;; Original by "CAP" 04/21/91
;;; http://www.apple2.org.za/gswv/a2zine/GS.WorldView/v1999/Oct/MISC/NSC.Disk.TXT

;;; Modification history available at:
;;; https://github.com/a2stuff/prodos-drivers

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

        .undef PRODUCT
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
        pha
        jsr     DetectZ80
        pla                     ; A=$Cs
        bcs     next            ; Z80 present, skip this slot

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
        lda     #>$C015         ; $C015 = RDCXROM (internal or slot ROM?)
        ldy     #<$C015
        sta     ld4+2
        sty     ld4+1
        ldy     #$07            ; $C007 = INTCXROM (read internal ROM)
        sta     st1+2
        sty     st1+1
        dey                     ; $C006 = SLOTCXROM (read slot ROM)
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

        ;; Update absolute addresses within driver
        lda     DATETIME+1
        sta     ptr
        clc
        adc     #(unlock - driver - 1)
        sta     unlock_addr
        lda     DATETIME+2
        sta     ptr+1
        adc     #0
        sta     unlock_addr+1

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

;;; ------------------------------------------------------------
;;; Detect Z80
;;; ------------------------------------------------------------

;;; This routine gets swapped into $0FFD for execution
.proc Z80Routine
        target := $0FFD
        ;; .org $FFFD
        patch := *+2
        .byte   $32, $00, $e0   ; ld ($Es00),a   ; s=slot being probed turn off Z80, next PC is $0000
        .byte   $3e, $01        ; ld a,$01
        .byte   $32, $08, $00   ; ld (flag),a
        .byte   $c3, $fd, $ff   ; jp $FFFD
        flag := *
        .byte   $00             ; flag: .db $00
.endproc
        .assert Z80Routine > Z80Routine::target + .sizeof(Z80Routine), error, "Z80 collision"

;;; Input: A = $Cn where n = slot number
;;; Output: C=1 if Z80 found in slot
.proc DetectZ80
        ;; Location to poke to invoke Z80
        sta     store+1

        ;; Convert $Cn to $En, update Z80 code
        ora     #$E0
        sta     Z80Routine::patch

        ;; Clear detection flag
        copy    #0, Z80Routine::flag

        ;; Put routine in place
        jsr     SwapRoutine

        ;; Try to invoke Z80
        php
        sei
        store := *+1
        sta     $C000           ; self-modified
        plp

        ;; Restore memory
        jsr     SwapRoutine

        ;; Flag will be set to 1 by routine if Z80 was present.
        lda     Z80Routine::flag
        ror                     ; move flag into carry
        rts

.proc SwapRoutine
        ldx     #.sizeof(Z80Routine)-1
:       ldy     Z80Routine::target,x
        lda     Z80Routine,x
        sta     Z80Routine::target,x
        tya
        sta     Z80Routine,x
        dex
        bpl     :-
        rts
.endproc
.endproc

;;; ============================================================
;;; NSC driver - modified as needed and copied into ProDOS
;;; ============================================================

driver:
        php
        sei
        lda     PTRIG           ; Slow ZIP, IIc+ accelerator, etc
        lda     $C00B           ; Ultrawarp bug workaround c/o @bobbimanners
ld4:    lda     $CFFF           ; self-modified ($CFFF or RDCXROM)
        pha
st1:    sta     $C300           ; self-modified ($Cn00 or INTCXROM)
ld1:    lda     $C304           ; self-modified ($Cn04)
        ldx     #8

        ;; --------------------------------------------------
        ;; Unlock the NSC by bit-banging.
uloop:
        unlock_addr := *+1
        lda     unlock-1,x      ; self-modified (during relocation)
        sec
        ror     a               ; a bit at a time
:       pha
        lda     #0
        rol     a
        tay
ld2:    lda     $C300,y         ; self-modified ($Cn00)
        pla
        lsr     a
        bne     :-
        dex
        bne     uloop

        ;; --------------------------------------------------
        ;; Read 8 bytes * 8 bits of clock data, push onto stack

        tmp := $200
        ldx     #8
bloop:  ldy     #8
st2:
:       lda     $C304           ; self-modified ($Cn04)
        ror     a
        ror     tmp
        dey
        bne     :-

        ;; BCD to Binary - slow but tiny
        lda     tmp             ; A = value
        ldy     #$FF            ; result = -1
        sec
        sed
:       iny                     ; result += 1
        sbc     #1              ; value -= 1
        bcs     :-
        cld
        tya                     ; A = result

        ;; Push to stack
        pha
        dex
        bne     bloop

        ;; --------------------------------------------------
        ;; Now stack has y/m/d/w/H/M/S/F

        pla                     ; year
        sta     DATELO+1

        pla                     ; month
        asl
        asl
        asl
        asl
        asl
        sta     DATELO
        rol     DATELO+1

        pla                     ; day
        ora     DATELO
        sta     DATELO

        pla                     ; skip week

        pla                     ; hour
        sta     TIMELO+1

        pla                     ; minute
        sta     TIMELO

        pla                     ; skip seconds
        pla                     ; skip fraction

        ;; --------------------------------------------------
        ;; Finish up

        pla
        bmi     done
st4:    sta     $CFFF           ; self-modified ($CFFF or SLOTCXROM)
done:   plp
        rts

unlock:
        ;; NSC unlock sequence
        .byte   $5C, $A3, $3A, $C5
        .byte   $5C, $A3, $3A, $C5

        sizeof_driver := * - driver
        .assert sizeof_driver <= 125, error, "Clock code must be <= 125 bytes"

;;; ************************************************************
.ifndef JUMBO_CLOCK_DRIVER
        .include "../../inc/driver_postamble.inc"
.endif ; JUMBO_CLOCK_DRIVER
;;; ************************************************************
