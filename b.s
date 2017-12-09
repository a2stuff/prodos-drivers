;;; Disassembly of BYE.SYSTEM (Bird's Better Bye)

        .setcpu "65C02"
        .include "apple2.inc"
        .include "prodos.inc"

L0060           := $0060

RAMRDOFF        := $C002
RAMRDON         := $C003
RAMWRTOFF       := $C004
RAMWRTON        := $C005
ALTZPOFF        := $C008
ALTZPON         := $C009
ROMINNW         := $C082
ROMINWB1        := $C089
LC300           := $C300

MON_SETTXT      := $FB39
MON_TABV        := $FB5B
SETPWRC         := $FB6F
BELL1           := $FBDD
MON_HOME        := $FC58
COUT            := $FDED
SETINV          := $FE80
SETNORM         := $FE84

ZP_HPOS         := $24
ZP_TMASK        := $32

COL80HPOS       := $057B


ASCII_TAB       := $9
ASCII_DOWN      := $A
ASCII_UP        := $B
ASCII_RETURN    := $D
ASCII_ESCAPE    := $1B

;;; ------------------------------------------------------------

.define HI(char)        (char|$80)

.macro  HIASCII arg
        .repeat .strlen(arg), i
        .byte   .strat(arg, i) | $80
        .endrep
.endmacro

.macro  HIASCIIZ arg
        HIASCII arg
        .byte   0
.endmacro

;;; ------------------------------------------------------------

        ;; Loads at $2000 but executed at $1000.

        .org    $2000

L2000:  jmp     install_and_quit
        install_src := *

        .org    $1000
.proc bbb

        prefix := $280          ; length-prefixed
        ;; filenames at $1400 - each is length byte + 15 byte buffer

        read_buffer := $2000    ; Also, start location for launched SYS files


        current_entry := $67
        num_entries := $68
        page_start := $73

        top_row    := 2
        bottom_row := 21

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
        lda     prefix+1
        and     #$0F
        beq     L1032
        adc     #$02
        tax

L1059:  stx     prefix          ; truncate prefix to length x
        lda     #'/'
        sta     prefix+1
        sta     prefix,x
        stz     prefix+1,x

        MLI_CALL OPEN, open_params
        bcc     L107F
        lda     $6B
        beq     L1032
        jsr     BELL1
        jsr     L11DA
        stx     prefix
        jmp     keyboard_loop

L107F:  inc     $6B             ; ???
        stz     num_entries
        lda     open_params_ref_num
        sta     read_params_ref_num
        sta     $61
        lda     #$2B
        sta     read_params_request
        stz     read_params_request+1
        jsr     do_read
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
        jsr     do_read
        bcs     L10B3
        inc     $72
        lda     read_buffer
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
L1108:  ldx     num_entries
        cpx     #$80
        bcs     L1129
        sta     $74,x
        jsr     L1258
        ldy     #$0F
L1115:  lda     read_buffer,y
        sta     ($6C),y
        dey
        bpl     L1115
        iny
        and     #$0F
        sta     ($6C),y
        inc     num_entries
        bne     L10B5
L1126:  jmp     L1032

L1129:  MLI_CALL CLOSE, close_params
        bcs     L1126

        ;; TEXT : HOME : VTAB 23
        jsr     MON_SETTXT
        jsr     MON_HOME
        lda     #23             ; line 23
        jsr     MON_TABV

        ;; Print help text
        ldy     #0
        lda     #20             ; HTAB 20
        jsr     cout_string_hpos

        jsr     L12AD
        ldx     #0
:       lda     prefix+1,x
        beq     L1153
        jsr     ascii_cout
        inx
        bne     :-

L1153:  stz     current_entry
        stz     page_start
        lda     num_entries
        beq     keyboard_loop
        cmp     #bottom_row
        bcc     L1161
        lda     #$14
L1161:  sta     $6A
        lda     #$02
        sta     $22
        sta     $20
        lda     #$16
        sta     $21
        sta     $23
L116F:  jsr     draw_current_line
        inc     current_entry
        dec     $6A
        bne     L116F
        stz     current_entry
        beq     draw_current_line_inv

;;; ------------------------------------------------------------

.proc on_up
        jsr     draw_current_line ; show current line
        ldx     current_entry
        beq     draw_current_line_inv ; first one? just redraw
        dec     current_entry         ; go to previous
        lda     $25
        cmp     #top_row
        bne     draw_current_line_inv
        dec     page_start
        lda     #$16            ; code output ???
        bne     draw_current_line_with_char
.endproc

;;; ------------------------------------------------------------

.proc on_down
        jsr     draw_current_line
        ldx     current_entry
        inx
        cpx     num_entries
        bcs     draw_current_line_inv
        stx     current_entry
        lda     $25
        cmp     #bottom_row
        bne     draw_current_line_inv
        inc     page_start
        lda     #$17            ; code output ???
        ;; fall through
.endproc

;;; ------------------------------------------------------------

draw_current_line_with_char:
        jsr     COUT

draw_current_line_inv:
        jsr     SETINV
        jsr     draw_current_line
        ;; fall through

;;; ------------------------------------------------------------

.proc keyboard_loop
        lda     KBD
        bpl     keyboard_loop
        sta     KBDSTRB
        jsr     SETNORM
        ldx     num_entries
        beq     :+              ; no up/down/return if empty

        cmp     #HI(ASCII_RETURN)
        beq     on_return
        cmp     #HI(ASCII_DOWN)
        beq     on_down
        cmp     #HI(ASCII_UP)
        beq     on_up

:       cmp     #HI(ASCII_TAB)
        beq     next_drive
        cmp     #HI(ASCII_ESCAPE)
        bne     keyboard_loop
        ;; fall through
.endproc

;;; ------------------------------------------------------------

.proc on_escape
        jsr     L11DA
        dec     $6B
        bra     L11F1
.endproc

;;; ------------------------------------------------------------

L11DA:  ldx     prefix
L11DD:  dex
        lda     prefix,x
        cmp     #'/'
        bne     L11DD
        cpx     #$01
        bne     L11EC
        ldx     prefix
L11EC:  rts

next_drive:
        jmp     L1032

L11F0:  inx
L11F1:  jmp     L1059

;;; ------------------------------------------------------------

.proc on_return
        MLI_CALL SET_PREFIX, set_prefix_params
        bcs     next_drive
        ldx     current_entry
        jsr     L1258

        ldx     prefix
:       iny
        lda     ($6C),y
        inx
        sta     prefix,x
        cpy     $69
        bcc     :-
        stx     prefix

        ldy     current_entry
        lda     $74,y
        bpl     L11F0           ; is directory???
        ;; nope, system file, so...

        ;; fall through
.endproc

;;; ------------------------------------------------------------

.proc launch_sys_file
        jsr     MON_SETTXT
        jsr     MON_HOME
        lda     #$95            ; Right arrow
        jsr     COUT

        MLI_CALL OPEN, open_params
        bcs     next_drive
        lda     open_params_ref_num
        sta     read_params_ref_num
        lda     #$FF            ; Load up to $FFFF bytes
        sta     read_params_request
        sta     read_params_request+1
        jsr     do_read
        php
        MLI_CALL CLOSE, close_params
        plp
        bcs     next_drive
        jmp     read_buffer     ; Invoke the loaded code
.endproc

;;; ------------------------------------------------------------

cout_string_hpos:
        sta     ZP_HPOS

.proc cout_string
        lda     help_string,y
        beq     done
        jsr     COUT
        iny
        bne     cout_string
done:   rts
.endproc

;;; ------------------------------------------------------------

        ;; Compute offset to name in directory listing ???
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

;;; ------------------------------------------------------------

draw_current_line:
        lda     #2              ; hpos = 2
        sta     COL80HPOS

        ldx     current_entry   ; vpos = entry - page_start + 2
        txa
        sec
        sbc     page_start
        inc     a
        inc     a
        jsr     MON_TABV

        lda     $74,x
        bmi     L1299
        stz     COL80HPOS
        lda     ZP_TMASK
        pha
        ldy     #(folder_string - string_start) ; Draw folder glyphs
        jsr     cout_string
        pla
        sta     ZP_TMASK
L1299:  jsr     L12A9
        jsr     L1258
L129F:  iny
        lda     ($6C),y
        jsr     ascii_cout
        cpy     $69
        bcc     L129F
L12A9:  lda     #HI(' ')
        bne     cout            ; implicit RTS
L12AD:  lda     #$99            ; Ctrl+Y ??

        ;; Sets high bit before calling COUT
ascii_cout:
        ora     #$80
cout:   jmp     COUT

;;; ------------------------------------------------------------

.proc do_read
        MLI_CALL READ, read_params
        rts
.endproc

;;; ------------------------------------------------------------

        string_start := *
.proc help_string
        HIASCIIZ "RETURN: Select | TAB: Chg Vol | ESC: Back"
.endproc

        ;; Mousetext sequence: Enable, folder left, folder right, disable
.proc folder_string
        .byte   $0F,$1B,$D8,$D9,$18,$0E
        .byte   0               ; null terminated
.endproc

;;; ------------------------------------------------------------

.proc open_params
params: .byte   3
path:   .addr   prefix
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
buffer: .addr   prefix+1
.endproc
        on_line_params_unit := on_line_params::unit

.proc set_prefix_params
params: .byte   1
path:   .addr   prefix
.endproc

.proc read_params
params: .byte   4
ref_num:.byte   1
buffer: .word   read_buffer
request:.word   0
trans:  .word   0
.endproc
        read_params_ref_num := read_params::ref_num
        read_params_request := read_params::request

;;; ------------------------------------------------------------

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

;;; ------------------------------------------------------------

.proc install_and_quit
        jsr     install
        MLI_CALL QUIT, params

.proc params
params: .byte   4
type:   .byte   0
res1:   .word   0
res2:   .byte   0
res3:   .addr   0
.endproc
.endproc

;;; ------------------------------------------------------------

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
