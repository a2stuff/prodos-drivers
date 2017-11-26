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

.macro PASCAL_STRING arg
        .byte   .strlen(arg)
        .byte   arg
.endmacro

.macro  HIASCII arg
        .repeat .strlen(arg), i
        .byte   .strat(arg, i) | $80
        .endrep
.endmacro

.define HI(c)   ((c)|$80)

        data_buffer = $1800


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
        beq     pre_install
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
        ;; fall through...

;;; --------------------------------------------------

.proc pre_install
        cld
        bit     ROMIN2

        lda     #$46            ; reset vector???
        sta     $03F2
        lda     #$10
        sta     $03F3
        eor     #$A5
        sta     $03F4

        lda     #$95            ; Ctrl+U
        jsr     COUT

        ldx     #$FF
        txs
        sta     CLR80VID
        sta     CLRALTCHAR
        jsr     SETVID
        jsr     SETKBD
        jsr     SETNORM
        jsr     INIT

        ldx     #$17            ; Update system page bitmap
        lda     #1
:       sta     BITMAP,x
        lda     #0
        dex
        bne     :-
        lda     #$CF
        sta     BITMAP

        lda     MACHID
        and     #$88            ; //e or //c ?
        bne     :+
        lda     #$DF
        sta     lowercase_mask  ; lower case to upper case
:       lda     MACHID
        and     #$01            ; existing clock card?
        beq     detect_nsc      ; nope, check for NSC

        jsr     MON_HOME
        jsr     zstrout

        .byte   CR
        HIASCII "Previous Clock Installed!"
        .byte   BELL
        .byte   CR
        .byte   0

        jmp     exit
.endproc

;;; --------------------------------------------------
;;; Detect NSC

detect_nsc:
        ;; Preserve date/time
        ldy     #3              ; copy 4 bytes
:       lda     DATELO,y
        sta     L1197,y
        dey
        bpl     :-

        lda     #$CF
        ldy     #$FF
        sta     ld4+2
        sty     ld4+1
        sta     st4+2
        sty     st4+1
        lda     #$00
        sta     L119C
        lda     #$03
L10DF:  ora     #$C0
        sta     st1+2
L10E4:  sta     ld1+2
        sta     ld2+2
        sta     st2+2
        lda     #$03
        sta     L119B
L10F2:  jsr     driver
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
        sta     ld4+2
        sty     ld4+1
        ldy     #$07
        sta     st1+2
        sty     st1+1
        dey
        sta     st4+2
        sty     st4+1
        lda     #$C8
        bne     L10E4

        ;; Restore date/time
L1151:  ldy     #$03
:       lda     L1197,y
        sta     DATELO,y
        dey
        bpl     :-

        ;; Show failure message
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
;;; Install NSC Date Driver

.proc install_driver
        ptr := $A5

        lda     DATETIME+1
        sta     ptr
        clc
        adc     #$73
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

        lda     #$4C            ; JMP opcode
        sta     DATETIME

        ;; Invoke the driver to init the time
        jsr     DATETIME

        ;; Display success message
        bit     ROMIN2
        jsr     MON_HOME
        jsr     zstrout

        .byte   CR
        HIASCII "No-Slot Clock Installed  "
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

        lda     #(HI '/')       ; /
        jsr     COUT

        pla                     ; day
        and     #%00011111
        jsr     cout_number

        lda     #(HI '/')       ; /
        jsr     COUT

        pla                     ; year
        jsr     cout_number
        jsr     CROUT
.endproc

;;; --------------------------------------------------

exit:
        ;; Twiddle reset vector?
        lda     #$65
        sta     $03F2
        lda     #$13
        sta     $03F3
        eor     #$A5
        sta     $03F4

;;; --------------------------------------------------
;;; Invoke next .SYSTEM file

.define SYSTEM_SUFFIX ".SYSTEM"

.proc find_next_sys_file
        ptr := $A5
        len := $A8

        ;; Volume Directory Header structure
        entry_length := $23
        entries_per_block := $24
        header_length := $2B

        lda     DEVNUM          ; stick with most recent device
        sta     read_block_params_unit_num
        jsr     read_block

        lda     data_buffer + entry_length
        sta     adc1+1
        lda     data_buffer + entries_per_block
        sta     cmp1+1
        lda     #1
        sta     $A7             ; ???

        lda     #<(data_buffer + header_length)
        sta     ptr
        lda     #>(data_buffer + header_length)
        sta     ptr+1

        ;; File Entry structure
        storage_type := $00
        name_length := $00
        file_name := $01
        file_type := $10

        ;; Process directory entry
entry:  ldy     #file_type      ; file_type
        lda     (ptr),y
        cmp     #$FF            ; type=SYS
        bne     next
        ldy     #storage_type
        lda     (ptr),y
        and     #$30            ; regular file (not directory, pascal)
        beq     next
        lda     (ptr),y
        and     #$0F            ; name_length
        sta     len
        tay

        ;; Compare suffix - is it .SYSTEM?
        ldx     #.strlen(SYSTEM_SUFFIX)-1
:       lda     (ptr),y
        cmp     suffix,x
        bne     next
        dey
        dex
        bpl     :-

        ;; Yes; is it *this* .SYSTEM file?
        ldy     self_name
        cpy     len
        bne     handle_sys_file
:       lda     (ptr),y
        cmp     self_name,y
        bne     handle_sys_file
        dey
        bne     :-
        sec
        ror     found_self_flag

        ;; Move to the next entry
next:   lda     ptr
        clc
adc1:   adc     #$27            ; self-modified: entry_length
        sta     ptr
        bcc     L1293
        inc     ptr+1
L1293:  inc     $A7
        lda     $A7
cmp1:   cmp     #$0D            ; self-modified: entries_per_block
        bcc     entry

        lda     data_buffer + $2
        sta     read_block_params_block_num
        lda     data_buffer + $3
        sta     read_block_params_block_num+1
        ora     read_block_params_block_num
        beq     not_found
        jsr     read_block
        lda     #$00
        sta     $A7
        lda     #<(data_buffer + $04)
        sta     ptr
        lda     #>(data_buffer + $04)
        sta     ptr+1
        jmp     entry

        ;; Found a .SYSTEM file which is not this one; invoke
        ;; it if follows this one.
handle_sys_file:
        bit     found_self_flag
        bpl     next

        ;; Compose the path to invoke. First walk self path
        ;; backwards to '/'.
        ldx     PATHNAME
        beq     append
:       dex
        beq     append
        lda     PATHNAME,x
        eor     #'/'
        asl     a
        bne     :-

        ;; Now append name of found file.
append: ldy     #0
:       iny
        inx
        lda     (ptr),y
        sta     PATHNAME,x
        cpy     len
        bcc     :-
        stx     PATHNAME
        jmp     invoke_system_file

not_found:
        jsr     zstrout

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
.endproc

;;; --------------------------------------------------
;;; Output a high-ascii, null-terminated string.
;;; String immediately follows the JSR.

.proc zstrout
        ptr := $A5

        pla
        sta     ptr
        pla
        sta     ptr+1
        bne     L1334
L132A:  cmp     #(HI 'a')       ; lower-case?
        bcc     :+
        and     lowercase_mask  ; make upper-case if needed
:       jsr     COUT
L1334:  inc     ptr
        bne     L133A
        inc     ptr+1
L133A:  ldy     #$00
        lda     (ptr),y
        bne     L132A
        lda     ptr+1
        pha
        lda     ptr
        pha
        rts
.endproc

;;; --------------------------------------------------
;;; COUT a 2-digit number in A

.proc cout_number
        ldx     #(HI '0')
        cmp     #10             ; >= 10?
        bcc     tens

        ;; divide by 10, dividend(+'0') in x remainder in a
:       sbc     #10
        inx
        cmp     #10
        bcs     :-

tens:   pha
        cpx     #(HI '0')
        beq     units
        txa
        jsr     COUT

units:  pla
        ora     #(HI '0')
        jsr     COUT
        rts
.endproc

;;; --------------------------------------------------

lowercase_mask:
        .byte   $FF             ; Set to $DF on systems w/o lower-case

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
        .addr   data_buffer     ; data_buffer
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
        .addr   data_buffer     ; io_buffer
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
        PASCAL_STRING "NS.CLOCK.SYSTEM"

;;; --------------------------------------------------
;;; The driver - copied into ProDOS

driver:
        php
        sei
ld4:    lda     $CFFF
        pha
st1:    sta     $C300           ; self-modified
ld1:    lda     $C304           ; self-modified
        ldx     #8
L140D:
ld3:    lda     $1472,x         ; self-modified
        sec
        ror     a
L1412:  pha
        lda     #0
        rol     a
        tay
ld2:    lda     $C300,y         ; self-modified
        pla
        lsr     a
        bne     L1412
        dex
        bne     L140D
        ldx     #8
L1423:  ldy     #8
st2:
L1425:  lda     $C304           ; self-modified
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
        sta     $01FF,x
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
st4:    sta     $CFFF           ; self-modified
L1471:  plp
        rts

unlock:
        ;; NSC unlock sequence
        .byte   $5C, $A3, $3A, $C5
        .byte   $5C, $A3, $3A, $C5
        .byte   $00

        sizeof_driver := * - driver

;;; --------------------------------------------------
;;; Junk from here on?

        ;; ??
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
