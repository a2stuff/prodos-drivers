        .setcpu "65C02"

CR              := $8D
BELL            := $87

MAX_DW          := $FFFF

        ;; Softswitches
KBD             := $C000        ; Last Key Pressed + 128
KBDSTRB         := $C010        ; Keyboard Strobe
CLR80VID        := $C00C        ; 40 Columns
CLRALTCHAR      := $C00E        ; Primary Character Set
ROMIN2          := $C082        ; Read ROM; no write
RWRAM1          := $C08B        ; Read/write RAM bank 1

        ;; ProDOS Equates
PRODOS          := $BF00
DATETIME        := $BF06
DEVNUM          := $BF30
BITMAP          := $BF58
DATELO          := $BF90
TIMELO          := $BF92
MACHID          := $BF98

SYS_ADDR        := $2000
PATHNAME        := $0280
MLI_QUIT        := $65
MLI_READ_BLOCK  := $80
MLI_OPEN        := $C8
MLI_READ        := $CA
MLI_CLOSE       := $CC

.macro PRODOS_CALL call, params
        jsr     PRODOS
        .byte   call
        .addr   params
.endmacro

        ;; Monitor Equates
INIT            := $FB2F
MON_HOME        := $FC58
CROUT           := $FD8E
PRBYTE          := $FDDA
COUT            := $FDED
SETNORM         := $FE84
SETKBD          := $FE89
SETVID          := $FE93

.macro  HIASCII arg
        .repeat .strlen(arg), i
        .byte   .strat(arg, i) | $80
        .endrep
.endmacro


;;; --------------------------------------------------

        .org $1000

        ;;  Loaded at $2000 but relocates to $1000

;;; --------------------------------------------------

init:   sec
        bcs     :+
        .byte   $04, $21, $91   ; ????

;;; --------------------------------------------------

.proc relocate
        src := SYS_ADDR
        dst := $1000

:       ldx     #5              ; pages
        ldy     #0
load:   lda     src,y           ; self-modified
store:  sta     dst,y           ; self-modified
        iny
        bne     load
        inc     load+2
        inc     store+2
        dex
        beq     find_self_name
        jmp     load
.endproc

;;; --------------------------------------------------

        ;; Search pathname buffer backwards for '/', then
        ;; copy name into |self_name|; this is used later
        ;; to find/invoke the next .SYSTEM file.
.proc find_self_name
        ;; find '/' (which may not be present, prefix is optional)
        lda     #0
        sta     $A8
        ldx     PATHNAME
        beq     L1046
floop:  inc     $A8
        dex
        beq     copy
        lda     PATHNAME,x
        eor     #'/'
        asl     a
        bne     floop

        ;; copy name into |self_name| buffer
copy:   ldy     #0
cloop:  iny
        inx
        lda     PATHNAME,x
        sta     self_name,y
        cpy     $A8
        bcc     cloop
        sty     self_name
.endproc

;;; --------------------------------------------------

L1046:  cld
        bit     ROMIN2
        lda     #$46
        sta     $03F2
        lda     #$10
        sta     $03F3
        eor     #$A5
        sta     $03F4
        lda     #$95
        jsr     COUT
        ldx     #$FF
        txs
        sta     CLR80VID
        sta     CLRALTCHAR
        jsr     SETVID
        jsr     SETKBD
        jsr     SETNORM
        jsr     INIT
        ldx     #$17
        lda     #$01
L1077:  sta     BITMAP,x
        lda     #$00
        dex
        bne     L1077
        lda     #$CF
        sta     BITMAP
        lda     MACHID
        and     #$88
        bne     L1090
        lda     #$DF
        sta     cout_mask       ; lower case to upper case
L1090:  lda     MACHID
        and     #$01
        beq     L10BD
        jsr     MON_HOME
        jsr     zstrout

        .byte   CR
        HIASCII "Previous Clock Installed!"
        .byte   BELL
        .byte   CR
        .byte   0

        jmp     exit

L10BD:  ldy     #$03
L10BF:  lda     DATELO,y
        sta     L1197,y
        dey
        bpl     L10BF
        lda     #$CF
        ldy     #$FF
        sta     L1403
        sty     L1402
        sta     L1470
        sty     L146F
        lda     #$00
        sta     L119C
        lda     #$03
L10DF:  ora     #$C0
        sta     L1407
L10E4:  sta     L140A
        sta     L1419
        sta     L1427
        lda     #$03
        sta     L119B
L10F2:  jsr     L13FF
        lda     DATELO+1
        ror     a
        lda     DATELO
        rol     a
        rol     a
        rol     a
        rol     a
        and     #$0F
        beq     L1128
        cmp     #$0D
        bcs     L1128
        lda     DATELO
L110B:  and     #$1F
        beq     L1128
        cmp     #$20
        bcs     L1128
        .byte   $AD
        .byte   $93
L1115:  bbs3    $C9,$1130
        bcs     L1128
        lda     TIMELO
        cmp     #$3C
        bcs     L1128
        dec     L119B
        bne     L10F2
        .byte   $F0
L1127:  .byte   $75
L1128:  inc     L119C
        lda     L119C
        cmp     #$08
        bcc     L10DF
        bne     L1151
        lda     #$C0
        ldy     #$15
        sta     L1403
        sty     L1402
        ldy     #$07
        sta     L1407
        sty     L1406
        dey
        sta     L1470
        sty     L146F
        lda     #$C8
        bne     L10E4
L1151:  ldy     #$03
L1153:  lda     L1197,y
        sta     DATELO,y
        dey
        bpl     L1153
        jsr     MON_HOME
        jsr     zstrout

        .byte   CR
        HIASCII "No-SLot Clock Not Found."
        .byte   CR
        .byte   CR
        HIASCII "Clock Not Installed!"
        .byte   BELL
        .byte   CR
        .byte   0

        jmp     exit

L1197:  .byte   0, 0, 0, 0
L119B:  .byte   $03
L119C:  brk

;;; --------------------------------------------------

L119D:  lda     DATETIME+1
        sta     $A5
        clc
        adc     #$73
        sta     L140E
        lda     DATETIME+2
        sta     $A6
        adc     #$00
        sta     L140F
        lda     RWRAM1
        lda     RWRAM1
        ldy     #$7C
L11BA:  lda     L13FF,y
        sta     ($A5),y
        dey
        bpl     L11BA
        lda     MACHID
        ora     #$01
        sta     MACHID
        lda     #$4C            ; JMP opcode
        sta     DATETIME
        jsr     DATETIME
        bit     ROMIN2
        jsr     MON_HOME
        jsr     zstrout

        .byte   CR
        HIASCII "No-Slot Clock Installed  "
        .byte   0

        lda     DATELO+1
        ror     a
        pha
        lda     DATELO
        pha
        rol     a
        rol     a
        rol     a
        rol     a
        and     #$0F
        jsr     L1347
        lda     #$AF
        jsr     COUT
        pla
        and     #$1F
        jsr     L1347
        lda     #$AF
        jsr     COUT
        pla
        jsr     L1347
        jsr     CROUT

;;; --------------------------------------------------

        ;; Twiddle reset vector?
exit:
        lda     #$65
        sta     $03F2
        lda     #$13
        sta     $03F3
        eor     #$A5
        sta     $03F4

;;; --------------------------------------------------
;;; Invoke next .SYSTEM file


.define SYSTEM_SUFFIX ".SYSTEM"

        lda     DEVNUM
        sta     read_block_params_unit_num
        jsr     read_block
        lda     $1823
        sta     L128C
        lda     $1824
        sta     L1298
        lda     #$01
        sta     $A7
        lda     #$2B
        sta     $A5
        lda     #$18
        sta     $A6
L124F:  ldy     #$10
        lda     ($A5),y
        cmp     #$FF            ; type=SYS ???
        bne     L1288
        ldy     #$00
        lda     ($A5),y
        and     #$30
        beq     L1288
        lda     ($A5),y
        and     #$0F
        sta     $A8
        tay
        ;; Compare suffix - is it .SYSTEM?
        ldx     #.strlen(SYSTEM_SUFFIX)-1
L1268:  lda     ($A5),y
        cmp     suffix,x
        bne     L1288
        dey
        dex
        bpl     L1268
        ldy     self_name
        cpy     $A8
        bne     L12BE
:       lda     ($A5),y
        cmp     self_name,y
        bne     L12BE
        dey
        bne     :-
        sec
        ror     found_self_flag

        ;; go on to next file (???)
L1288:  lda     $A5
        clc
        .byte   $69
L128C:  rmb2    $85
        lda     $90
        .byte   $02
        inc     $A6
        inc     $A7
        lda     $A7
        .byte   $C9
L1298:  ora     $B490
        lda     $1802
        sta     read_block_params_block_num
        lda     $1803
        sta     read_block_params_block_num+1
        ora     read_block_params_block_num
        beq     L12E6
        jsr     read_block
        lda     #$00
        sta     $A7
        lda     #$04
        sta     $A5
        lda     #$18
        sta     $A6
        jmp     L124F

L12BE:  bit     found_self_flag
        bpl     L1288


        ldx     PATHNAME
        beq     L12D3
L12C8:  dex
        beq     L12D3
        lda     PATHNAME,x
        eor     #'/'
        asl     a
        bne     L12C8
L12D3:  ldy     #$00
L12D5:  iny
        inx
L12D7:  lda     ($A5),y
        sta     PATHNAME,x
        cpy     $A8
        bcc     L12D5
        stx     PATHNAME
        jmp     invoke_system_file

L12E6:  jsr     zstrout

        .byte   CR
        .byte   CR
        .byte   CR
        HIASCII "* Unable to find next '.SYSTEM' file *"
        .byte   CR
        .byte   0

        bit     KBDSTRB
:       lda     KBD
        bpl     :-
        bit     KBDSTRB
        jmp     quit

;;; --------------------------------------------------
;;; Output a high-ascii, null-terminated string.
;;; String immediately follows the JSR.

.proc zstrout
        pla
        sta     $A5
        pla
        sta     $A6
        bne     L1334
L132A:  cmp     #('a'|$80)      ; lower-case?
        bcc     :+
        and     cout_mask       ; make upper-case if needed
:       jsr     COUT
L1334:  inc     $A5
        bne     L133A
        inc     $A6
L133A:  ldy     #$00
        lda     ($A5),y
        bne     L132A
        lda     $A6
        pha
        lda     $A5
        pha
        rts
.endproc

;;; --------------------------------------------------

L1347:  ldx     #$B0
        cmp     #$0A
        bcc     L1354
L134D:  sbc     #$0A
        inx
        cmp     #$0A
        bcs     L134D
L1354:  pha
        cpx     #$B0
        beq     L135D
        txa
L135A:  jsr     COUT
L135D:  pla
        ora     #$B0
        jsr     COUT
        rts

cout_mask:
        .byte   $FF

;;; --------------------------------------------------

.proc quit
        PRODOS_CALL MLI_QUIT, quit_params
        .byte   0               ; ???
        rts
.proc quit_params
        .byte   4               ; param_count
        .byte   0               ; quit_type
        .word   0000            ; reserved
        .byte   0               ; reserved
        .word   0000            ; reserved
.endproc
.endproc

;;; --------------------------------------------------

.proc read_block
        PRODOS_CALL MLI_READ_BLOCK, read_block_params
        bcs     on_error
        rts
.endproc

.proc read_block_params
        .byte   3               ; param_count
unit_num:  .byte   $60          ; unit_num
        .addr   $1800           ; data_buffer
block_num: .word   2            ; block_num
.endproc
        read_block_params_unit_num := read_block_params::unit_num
        read_block_params_block_num := read_block_params::block_num

;;; --------------------------------------------------
;;; Load/execute the system file in PATHNAME

.proc invoke_system_file
        PRODOS_CALL MLI_OPEN, open_params
        bcs     on_error

        lda     open_params_ref_num
        sta     read_params_ref_num

        PRODOS_CALL MLI_READ, read_params
        bcs     on_error

        PRODOS_CALL MLI_CLOSE, close_params
        bcs     on_error

        jmp     SYS_ADDR        ; Invoke loaded SYSTEM file
.endproc

;;; --------------------------------------------------
;;; Error Handler

.proc on_error
        pha
        jsr     zstrout

        .byte   CR
        .byte   CR
        .byte   CR
        HIASCII "**  Disk Error $"
        .byte   0

        pla
        jsr     PRBYTE
        jsr     zstrout

        HIASCII "  **"
        .byte   CR
        .byte   0

        bit KBDSTRB
:       lda     KBD
        bpl     :-
        bit     KBDSTRB
        jmp     quit
.endproc

;;; --------------------------------------------------

.proc open_params
        .byte   3               ; param_count
        .addr   PATHNAME        ; pathname
        .addr   $1800           ; io_buffer
ref_num:.byte   1               ; ref_num
.endproc
        open_params_ref_num := open_params::ref_num

.proc read_params
        .byte   4               ; param_count
ref_num:.byte   1               ; ref_num
        .addr   SYS_ADDR        ; data_buffer
        .word   MAX_DW          ; request_count
        .word   0               ; trans_count
.endproc
        read_params_ref_num := read_params::ref_num

.proc close_params
        .byte   1               ; param_count
ref_num:.byte   0               ; ref_num
.endproc

;;; --------------------------------------------------

found_self_flag:
        .byte   0

suffix: .byte   SYSTEM_SUFFIX


self_name:
        .byte   $F, "NS.CLOCK.SYSTEM"

;;; --------------------------------------------------

L13FF:  php
        sei
        .byte   $AD
L1402:  .byte   $FF
L1403:  bbs4    $48,$1393
L1406:  brk
L1407:  .byte   $C3
        .byte   $AD
        .byte   $04
L140A:  .byte   $C3
        ldx     #$08
L140D:  .byte   $BD
L140E:  .byte   $72
L140F:  trb     $38
        ror     a
L1412:  pha
        lda     #$00
        rol     a
        tay
        .byte   $B9
        brk
L1419:  .byte   $C3
        pla
        lsr     a
        bne     L1412
        dex
        bne     L140D
        ldx     #$08
L1423:  ldy     #$08
L1425:  .byte   $AD
        .byte   $04
L1427:  .byte   $C3
        ror     a
        ror     $01FF,x
        dey
        bne     L1425
        lda     $01FF,x
        lsr     a
        lsr     a
        lsr     a
        lsr     a
        tay
        beq     L1447
        lda     $01FF,x
        and     #$0F
        clc
L143F:  adc     #$0A
        dey
        bne     L143F
        .byte   $9D
L1445:  .byte   $FF
        .byte   $01
L1447:  dex
        bne     L1423
        lda     $0204
        sta     TIMELO+1
        lda     $0205
        sta     TIMELO
        lda     $0201
        asl     a
        asl     a
        asl     a
        asl     a
        asl     a
        ora     $0202
        sta     DATELO
        lda     $0200
        rol     a
        sta     DATELO+1
        pla
        bmi     L1471
        .byte   $8D
L146F:  .byte   $FF
L1470:  .byte   $CF
L1471:  plp
        rts

        .byte   $5C
        .byte   $A3
        dec     a
        cmp     $5C
        .byte   $A3
        dec     a
        cmp     $00
        .byte   $B3
        pla
        adc     ($F0)


        .res    6, $2a
        .byte   " /RAM ", $8D, $00
        .res    12, $2a
        .byte   " /CONTIERI ", $8D, $00
        .res    7, $2a
        .byte   $03, "/HD ", $8D, $00
        .res    27, $2a
        .byte   $6a, $2d
        .res    19, $2a
        .byte   $31, $f0, $03, $4c, $43, $3a, $ad, $3e
        .res    7, $2a
L14F4:  .res    2, $2a
L14F6:  .res    99, $2a
L1559:  .res    12, $2a
        .byte   $CA, $FC, $30, $F0, $07, $C9, $4C, $F0
        .res    120, $2a
        .byte   0, 0, 0

        lda     $3150
        bne     L15EE

;        000005e0  2a 2a 2a 2a 2a 00 00 00  ad 50 31 d0 01 2a 2a 2a  |*****....P1..***|
;        000005f0  2a 2a 2a 2a 2a 2a 2a 2a  2a 2a 2a 2a 2a 2a 2a 2a  |****************|

        .byte   $2a
L15EE:  .res    18, $2a
