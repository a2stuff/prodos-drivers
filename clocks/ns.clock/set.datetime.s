        .setcpu "6502"
        .linecont +
        .feature string_escapes

        .include "apple2.inc"
        .include "apple2.mac"
        .include "opcodes.inc"

        .include "../../inc/apple2.inc"
        .include "../../inc/macros.inc"
        .include "../../inc/prodos.inc"

;;; ------------------------------------------------------------

        .define PRODUCT "No-Slot Clock"

;;; ------------------------------------------------------------

        .org $2000

.proc main
        jsr     detect_nsc
        bcc     :+
        rts
:
        ;; --------------------------------------------------
        ;; Prompt for Date

date:
        jsr     zstrout
        scrcode "\rDate: WWW MM/DD/YY\x08\x08\x08\x08\x08\x08\x08\x08\x08\x08\x08\x08"
        .byte   0

        jsr     GETLN2

        lda     INPUT_BUFFER+4
        jsr     shift_into_tmp
        lda     INPUT_BUFFER+5
        jsr     shift_into_tmp
        sta     set_month
        jsr     bcd_to_binary
        cmp     #13
        bcs     date

        lda     INPUT_BUFFER+7
        jsr     shift_into_tmp
        lda     INPUT_BUFFER+8
        jsr     shift_into_tmp
        sta     set_date
        jsr     bcd_to_binary
        cmp     #32
        bcs     date

        lda     INPUT_BUFFER+10
        jsr     shift_into_tmp
        lda     INPUT_BUFFER+11
        jsr     shift_into_tmp
        sta     set_year

        ldx     #0
        ldy     #1
dow_loop:
        CHAR_MASK = $5F         ; clear high bit and force uppercase

        lda     INPUT_BUFFER+0
        and     #CHAR_MASK
        cmp     wkdays,x
        bne     next
        lda     INPUT_BUFFER+1
        and     #CHAR_MASK
        cmp     wkdays+1,x
        bne     next
        lda     INPUT_BUFFER+2
        and     #CHAR_MASK
        cmp     wkdays+2,x
        bne     next

        sty     set_dow
        jmp     time

next:   inx
        inx
        inx
        iny
        cpy     #8
        bcc     dow_loop
        jmp     date

        ;; --------------------------------------------------
        ;; Prompt for Time

time:
        jsr     zstrout
        scrcode "\rTime: HH:MM:SS\x08\x08\x08\x08\x08\x08\x08\x08"
        .byte   0

        jsr     GETLN2

        lda     INPUT_BUFFER+0
        jsr     shift_into_tmp
        lda     INPUT_BUFFER+1
        jsr     shift_into_tmp
        sta     set_hours
        jsr     bcd_to_binary
        cmp     #24
        bcs     time

        lda     INPUT_BUFFER+3
        jsr     shift_into_tmp
        lda     INPUT_BUFFER+4
        jsr     shift_into_tmp
        sta     set_minutes
        jsr     bcd_to_binary
        cmp     #60
        bcs     time

        lda     INPUT_BUFFER+6
        jsr     shift_into_tmp
        lda     INPUT_BUFFER+7
        jsr     shift_into_tmp
        sta     set_seconds
        jsr     bcd_to_binary
        cmp     #60
        bcs     time


        ;; --------------------------------------------------
        ;; Set NSC

        jmp     set_datetime

;;; --------------------------------------------------

bcd_to_binary:
        ldy     #$FF            ; result = -1
        sec
        sed
:       iny                     ; result += 1
        sbc     #1              ; value -= 1
        bcs     :-
        cld
        tya                     ; A = result
        rts

;;; --------------------------------------------------

shift_into_tmp:
        pha
        lda     tmp
        asl
        asl
        asl
        asl
        sta     tmp
        pla
        and     #%00001111
        ora     tmp
        sta     tmp
        rts

tmp:    .byte   0
.endproc

;;; ------------------------------------------------------------

set_year:       .byte   0
set_month:      .byte   0
set_date:       .byte   0
set_dow:        .byte   0
set_hours:      .byte   0
set_minutes:    .byte   0
set_seconds:    .byte   0
set_hundredths: .byte   0

wkdays: .byte   "MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"

;;; ------------------------------------------------------------

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
        beq     found
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

        ;; Show failure message
        jsr     zstrout
        scrcode PRODUCT, " - Not Found."
        .byte   0

        sec                     ; failure
        rts

found:
        clc                     ; success
        rts

saved:  .byte   0, 0, 0, 0
tries:  .byte   3
slot:   .byte   0
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

;;; ============================================================

.proc set_datetime
        jsr     patch_from_driver

        php
        sei
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
        ;; Push data onto stack

        lda     set_year
        pha
        lda     set_month
        pha
        lda     set_date
        pha
        lda     set_dow
        pha
        lda     set_hours
        pha
        lda     set_minutes
        pha
        lda     set_seconds
        pha
        lda     #$00            ; Hundredths
        pha

        ;; --------------------------------------------------

        ;; Loop over and write all 64 bits into register
        tmp := $200
        lda     #8              ; bytes
        sta     count

bloop:  ldx     #8              ; bits
:       pla                     ; current byte
        ror     a               ; shift out bit to write
        pha                     ; not done with this
        lda     #0
        rol     a               ; shift into low bit
        tay                     ; and into Y to use as index
st2:
        lda     $C300,y         ; self-modified ($Cn00)

        dex                     ; next bit
        bne     :-

        pla                     ; next byte
        dec     count
        bne     bloop

        ;; --------------------------------------------------
        ;; Finish up

        pla
        bmi     done
st4:    sta     $CFFF           ; self-modified ($CFFF or SLOTCXROM)
done:   plp
        rts

count:  .byte   0
.endproc

;;; --------------------------------------------------

.proc patch_from_driver
        copy    ld1+2, set_datetime::ld1+2
        copy    ld2+2, set_datetime::ld2+2
        copy16  ld4+1, set_datetime::ld4+1

        copy16  st1+1, set_datetime::st1+1
        copy    st2+2, set_datetime::st2+2
        copy16  st4+1, set_datetime::st4+1

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
