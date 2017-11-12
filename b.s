
        .setcpu "65C02"
        .include "prodos.inc"

L0060           := $0060

KBD             := $C000
RAMRDOFF        := $C002
RAMRDON         := $C003
RAMWRTOFF       := $C004
RAMWRTON        := $C005
ALTZPOFF        := $C008
ALTZPON         := $C009
KBDSTRB         := $C010
ROMIN           := $C081
ROMINNW         := $C082
ROMINWB1        := $C089
LCBANK1         := $C08B
LC300           := $C300

MON_SETTXT      := $FB39
MON_TABV        := $FB5B
SETPWRC         := $FB6F
BELL1           := $FBDD
MON_HOME        := $FC58
COUT            := $FDED
SETINV          := $FE80
SETNORM         := $FE84

        .org    $2000

L2000:  jmp     install_and_quit
        install_src := *

        .org    $1000
.proc bbb
        cld
        lda     ROMINNW
        stz     $03F2
        lda     #$10
        sta     $03F3
        jsr     SETPWRC
        lda     #$A0
        jsr     LC300
        ldx     #$17
L1016:  stz     $BF58,x
        dex
        bpl     L1016
        inc     $BF6F
        lda     #$CF
        sta     $BF58
        lda     #$02
        sta     L0060
        ldx     $BF31
        stx     $65
        lda     $BF30
        bne     L1042
L1032:  ldx     $65
        lda     $BF32,x
        cpx     #$01
        bcs     L103F
        ldx     $BF31
        inx
L103F:  dex
        stx     $65
L1042:  sta     on_line_params_unit
        MLI_CALL ON_LINE, on_line_params
        bcs     L1032
        stz     $6B
        lda     $0281
        and     #$0F
        beq     L1032
        adc     #$02
        tax
L1059:  stx     $0280
        lda     #$2F
        sta     $0281
        sta     $0280,x
        stz     $0281,x
        MLI_CALL OPEN, open_params
        bcc     L107F
        lda     $6B
        beq     L1032
        jsr     BELL1
        jsr     L11DA
        stx     $0280
        jmp     keyboard_loop

L107F:  inc     $6B
        stz     $68
        lda     open_params_ref_num
        sta     read_params_ref_num
        sta     $61
        lda     #$2B
        sta     read_params_request
        stz     read_params_request+1
        jsr     L12B4
        bcs     L10B3
        ldx     #$03
L109A:  lda     $2023,x
        sta     $6E,x
        dex
        bpl     L109A
        sta     read_params_request
        lda     #$01
        sta     $72
        stz     $63
        stz     $64
        lda     $70
        ora     $71
        bne     L10B5
L10B3:  bra     L1129
L10B5:  bit     $71
        bmi     L10B3
L10B9:  lda     $63
        and     #$FE
        sta     $63
        ldy     $72
        lda     #$00
        cpy     $6F
        bcc     L10CE
        tay
        sty     $72
        inc     $63
L10CC:  inc     $63
L10CE:  dey
        clc
        bmi     L10D8
        adc     $6E
        bcc     L10CE
        bcs     L10CC
L10D8:  adc     #$04
        sta     $62
        MLI_CALL SET_MARK, L0060
        bcs     L10B3
        jsr     L12B4
        bcs     L10B3
        inc     $72
        lda     L2000
        and     #$F0
        beq     L10B9
        dec     $70
        bne     L10F8
        dec     $71
L10F8:  ror     $201E
        bcc     L10B5
        lda     $2010
        cmp     #$0F
        beq     L1108
        cmp     #$FF
        bne     L10B5
L1108:  ldx     $68
        cpx     #$80
        bcs     L1129
        sta     $74,x
        jsr     L1258
        ldy     #$0F
L1115:  lda     L2000,y
        sta     ($6C),y
        dey
        bpl     L1115
        iny
        and     #$0F
        sta     ($6C),y
        inc     $68
        bne     L10B5
L1126:  jmp     L1032

L1129:  MLI_CALL CLOSE, close_params
        bcs     L1126
        jsr     MON_SETTXT
        jsr     MON_HOME
        lda     #$17
        jsr     MON_TABV
        ldy     #$00
        lda     #$14
        jsr     L124A
        jsr     L12AD
        ldx     #$00
L1148:  lda     $0281,x
        beq     L1153
        jsr     L12AF
        inx
        bne     L1148
L1153:  stz     $67
        stz     $73
        lda     $68
        beq     keyboard_loop
        cmp     #$15
        bcc     L1161
        lda     #$14
L1161:  sta     $6A
        lda     #$02
        sta     $22
        sta     $20
        lda     #$16
        sta     $21
        sta     $23
L116F:  jsr     L1277
        inc     $67
        dec     $6A
        bne     L116F
        stz     $67
        beq     L11AA

on_up:  jsr     L1277
        ldx     $67
        beq     L11AA
        dec     $67
        lda     $25
        cmp     #$02
        bne     L11AA
        dec     $73
        lda     #$16
        bne     L11A7

on_down:
        jsr     L1277
        ldx     $67
        inx
        cpx     $68
        bcs     L11AA
        stx     $67
        lda     $25
        cmp     #$15
        bne     L11AA
        inc     $73
        lda     #$17

L11A7:  jsr     COUT
L11AA:  jsr     SETINV
        jsr     L1277

keyboard_loop:
        lda     KBD
        bpl     keyboard_loop
        sta     KBDSTRB
        jsr     SETNORM
        ldx     $68
        beq     L11CB
        cmp     #$8D            ; Return
        beq     L11F4
        cmp     #$8A            ; Down Arrow
        beq     on_down
        cmp     #$8B            ; Up Arrow
        beq     on_up
L11CB:  cmp     #$89            ; Tab
        beq     next_drive
        cmp     #$9B            ; Esc
        bne     keyboard_loop

        jsr     L11DA
        dec     $6B
        bra     L11F1
L11DA:  ldx     $0280
L11DD:  dex
        lda     $0280,x
        cmp     #$2F
        bne     L11DD
        cpx     #$01
        bne     L11EC
        ldx     $0280
L11EC:  rts

next_drive:
        jmp     L1032

L11F0:  inx
L11F1:  jmp     L1059

L11F4:  MLI_CALL SET_PREFIX, set_prefix_params
        bcs     next_drive
        ldx     $67
        jsr     L1258
        ldx     $0280
L1204:  iny
        lda     ($6C),y
        inx
        sta     $0280,x
        cpy     $69
        bcc     L1204
        stx     $0280
        ldy     $67
        lda     $74,y
        bpl     L11F0
        jsr     MON_SETTXT
        jsr     MON_HOME
        lda     #$95
        jsr     COUT
        MLI_CALL OPEN, open_params
        bcs     next_drive
        lda     open_params_ref_num
        sta     read_params_ref_num
        lda     #$FF
        sta     read_params_request
        sta     read_params_request+1
        jsr     L12B4
        php
        MLI_CALL CLOSE, close_params
        plp
        bcs     next_drive
        jmp     L2000

L124A:  sta     $24
L124C:  lda     help_string,y
        beq     L1257
        jsr     COUT
        iny
        bne     L124C
L1257:  rts

L1258:  stz     $6D
        txa
        asl     a
        rol     $6D
        asl     a
        rol     $6D
        asl     a
        rol     $6D
        asl     a
        rol     $6D
        sta     $6C
        lda     #$14
        clc
        adc     $6D
        sta     $6D
        ldy     #$00
        lda     ($6C),y
        sta     $69
        rts

L1277:  lda     #$02
        sta     $057B
        ldx     $67
        txa
        sec
        sbc     $73
        inc     a
        inc     a
        jsr     MON_TABV
        lda     $74,x
        bmi     L1299
        stz     $057B
        lda     $32
        pha
        ldy     #$2A
        jsr     L124C
        pla
        sta     $32
L1299:  jsr     L12A9
        jsr     L1258
L129F:  iny
        lda     ($6C),y
        jsr     L12AF
        cpy     $69
        bcc     L129F
L12A9:  lda     #$A0
        bne     L12B1
L12AD:  lda     #$99
L12AF:  ora     #$80
L12B1:  jmp     COUT

L12B4:  MLI_CALL READ, read_params
        rts

        .macro  HIASCII arg
        .repeat .strlen(arg), i
        .byte   .strat(arg, i) | $80
        .endrep
.endmacro

.proc help_string
        HIASCII "RETURN: Select | TAB: Chg Vol | ESC: Back"
        .byte   0               ; null terminated
.endproc

        ;; Mousetext sequence: Enable, folder left, folder right, disable
.proc folder_string
        .byte   $0F,$1B,$D8,$D9,$18,$0E
        .byte   0               ; null terminated
.endproc

.proc open_params
params: .byte   3
path:   .addr   $0280
buffer: .addr   $1C00
ref_num:.byte   0
.endproc
        open_params_ref_num := open_params::ref_num

.proc close_params
params: .byte   1
ref_num:.byte   0
.endproc

.proc on_line_params
params: .byte   2
unit:   .byte   $60
buffer: .addr   $0281
.endproc
        on_line_params_unit := on_line_params::unit

.proc set_prefix_params
params: .byte   1
path:   .addr   $0280
.endproc

.proc read_params
params: .byte   4
ref_num:.byte   1
buffer: .word   $2000
request:.word   0
trans:  .word   0
.endproc
        read_params_ref_num := read_params::ref_num
        read_params_request := read_params::request

        .res    192, 0
        .byte   $00,$00,$00,$00,$00,$00,$00,$00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00
        .byte   $00,$00,$48,$AD

.endproc
        .assert .sizeof(bbb) = $3FF, error, "Expected size is $3FF"
        .org    $2402

install_and_quit:
        jsr     install
        MLI_CALL QUIT, quit_params
.proc quit_params
params: .byte   4
type:   .byte   0
res1:   .word   0
res2:   .byte   0
res3:   .addr   0
.endproc

.proc install
        src := install_src
        end := install_src + .sizeof(bbb)
        dst := $D100            ; Install location in ProDOS

        src_ptr := $19
        dst_ptr := $1B

        sta     ALTZPOFF
        lda     ROMIN
        lda     ROMIN
        lda     #>src
        sta     src_ptr+1
        lda     #<src
        sta     src_ptr
        lda     #>dst
        sta     dst_ptr+1
        lda     #<dst
        sta     dst_ptr

loop:   lda     (src_ptr)
        sta     (dst_ptr)
        inc     src_ptr
        bne     :+
        inc     src_ptr+1
:       inc     dst_ptr
        bne     :+
        inc     dst_ptr+1
:       lda     src_ptr+1
        cmp     #>end
        bne     loop
        lda     src_ptr
        cmp     #<end
        bne     loop
        lda     (src_ptr)       ; WTF??
        sta     (dst_ptr)
        sta     ALTZPOFF
        sta     ROMINWB1
        sta     ROMINWB1
        rts
.endproc
