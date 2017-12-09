;;; Disassembly of BYE.SYSTEM (Bird's Better Bye)

        .setcpu "65C02"
        .include "apple2.inc"
        .include "prodos.inc"

L0060           := $0060

RESETVEC        := $3F2

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

COL80HPOS       := $057B

;;; ProDOS
BITMAP          := $BF58
BITMAP_SIZE     := $18

;;; ASCII
ASCII_TAB       := $9
ASCII_DOWN      := $A           ; down arrow
ASCII_UP        := $B           ; up arrow
ASCII_CR        := $D
ASCII_SYN       := $16          ; scroll up
ASCII_ETB       := $17          ; scroll down
ASCII_EM        := $19          ; move cursor to upper left
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
;;; Entry point
;;; ------------------------------------------------------------

        ;; Loads at $2000 but executed at $1000.

        .org    $2000

L2000:  jmp     install_and_quit
        install_src := *

;;; ------------------------------------------------------------
;;; Selector
;;; ------------------------------------------------------------

        .org    $1000
.proc bbb

        prefix  := $280         ; length-prefixed

        filenames       := $1400 ; each is length + 15 bytes
        read_buffer     := $2000 ; Also, start location for launched SYS files

        current_entry   := $67  ; index of current entry
        num_entries     := $68  ; length of |filenames|

        curr_len        := $69  ; length of current entry name
        curr_ptr        := $6C  ; address of current entry name (in |filenames|)

        page_start      := $73  ; index of first entry shown on screen

        top_row         := 2    ; first row used on screen
        bottom_row      := 21   ; last row used on screen

;;; ------------------------------------------------------------

        cld                     ; ProDOS protocol for QUIT routine
        lda     ROMINNW         ; Page in ROM for reads, writes ignored

        ;; Point reset vector at this routine
        stz     RESETVEC
        lda     #>bbb
        sta     RESETVEC+1

        jsr     SETPWRC
        lda     #$A0
        jsr     LC300           ; Activate 80-Column Firmware

        ;; Update system bitmap
        ldx     #BITMAP_SIZE-1  ; zero it all out
:       stz     BITMAP,x        ; zero it all out...
        dex
        bpl     :-
        inc     BITMAP+BITMAP_SIZE-1 ; protect global page itself

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
L10B3:  bra     finish_read
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
        bcs     finish_read
        sta     $74,x
        jsr     update_curr_ptr
        ldy     #$0F
L1115:  lda     read_buffer,y
        sta     (curr_ptr),y
        dey
        bpl     L1115
        iny
        and     #$0F
        sta     (curr_ptr),y
        inc     num_entries
        bne     L10B5
L1126:  jmp     L1032

finish_read:
        MLI_CALL CLOSE, close_params
        bcs     L1126

draw_screen:
        jsr     MON_SETTXT      ; TEXT
        jsr     MON_HOME        ; HOME
        lda     #23             ; VTAB 23
        jsr     MON_TABV

        ;; Print help text
        ldy     #0
        lda     #20             ; HTAB 20
        jsr     cout_string_hpos

        ;; Draw prefix
        jsr     home
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
        jsr     draw_current_line ; clear inverse selection

        ldx     current_entry
        beq     draw_current_line_inv ; first one? just redraw
        dec     current_entry         ; go to previous

        lda     CV
        cmp     #top_row        ; at the top?
        bne     draw_current_line_inv ; if not, just draw
        dec     page_start      ; yes, adjust page and
        lda     #ASCII_SYN      ; scroll screen up
        bne     draw_current_line_with_char
.endproc

;;; ------------------------------------------------------------

.proc on_down
        jsr     draw_current_line ; clear inverse selection

        ldx     current_entry
        inx
        cpx     num_entries           ; past the limit?
        bcs     draw_current_line_inv ; yes, just redraw
        stx     current_entry         ; go to next

        lda     CV
        cmp     #bottom_row     ; at the bottom?
        bne     draw_current_line_inv ; if not, just draw
        inc     page_start      ; yes, adjust page and
        lda     #ASCII_ETB      ; scroll screen down
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

        cmp     #HI(ASCII_CR)
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
        jsr     update_curr_ptr

        ldx     prefix
:       iny
        lda     (curr_ptr),y
        inx
        sta     prefix,x
        cpy     curr_len
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
        sta     CH

.proc cout_string
        lda     help_string,y
        beq     done
        jsr     COUT
        iny
        bne     cout_string
done:   rts
.endproc

;;; ------------------------------------------------------------

;; Compute address/length of curr_ptr/curr_len
;; Call with entry index in X.

.proc update_curr_ptr
        stz     curr_ptr+1
        txa
        asl     a
        rol     curr_ptr+1
        asl     a
        rol     curr_ptr+1
        asl     a
        rol     curr_ptr+1
        asl     a
        rol     curr_ptr+1
        sta     curr_ptr
        lda     #>filenames
        clc
        adc     curr_ptr+1
        sta     curr_ptr+1
        ldy     #0
        lda     (curr_ptr),y
        sta     curr_len
        rts
.endproc

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
        lda     INVFLG
        pha
        ldy     #(folder_string - string_start) ; Draw folder glyphs
        jsr     cout_string
        pla
        sta     INVFLG
L1299:  jsr     space
        jsr     update_curr_ptr
L129F:  iny
        lda     (curr_ptr),y
        jsr     ascii_cout
        cpy     curr_len
        bcc     L129F

space:  lda     #HI(' ')
        bne     cout            ; implicit RTS

home:   lda     #HI(ASCII_EM)   ; move cursor to top left

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
;;; Installer
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
