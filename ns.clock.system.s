        .setcpu "65C02"
        .linecont +

        ;; ASCII
BELL            := $07
CR              := $0D

        ;; Constants
MAX_DW          := $FFFF

        ;; Softswitches
KBD             := $C000        ; Last Key Pressed + 128
KBDSTRB         := $C010        ; Keyboard Strobe
CLR80VID        := $C00C        ; 40 Columns
CLRALTCHAR      := $C00E        ; Primary Character Set
ROMIN2          := $C082        ; Read ROM; no write
RWRAM1          := $C08B        ; Read/write RAM bank 1

        ;; ProDOS
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

        ;; Monitor
INIT            := $FB2F
MON_HOME        := $FC58
CROUT           := $FD8E
PRBYTE          := $FDDA
COUT            := $FDED
SETNORM         := $FE84
SETKBD          := $FE89
SETVID          := $FE93

;;; --------------------------------------------------

.macro PASCAL_STRING arg
        .byte   .strlen(arg)
        .byte   arg
.endmacro

.macro  HIASCII arg, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9
        .if .blank(arg)
          .exitmacro
        .endif
        .if .match ({arg}, "")  ; string?
          .repeat .strlen(arg), i
            .byte .strat(arg, i) | $80
          .endrep
        .else                   ; otherwise assume number/char/identifier
          .byte (arg | $80)
        .endif
        HIASCII arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9
.endmacro

.macro  HIASCIIZ arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9
        HIASCII arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9
        .byte   0
.endmacro

.define HI(c)   ((c)|$80)

;;; --------------------------------------------------

        data_buffer = $1800

        .define SYSTEM_SUFFIX ".SYSTEM"


;;; --------------------------------------------------

        .org $1000

        ;;  Loaded at $2000 but relocates to $1000

;;; --------------------------------------------------

sys_start:
        sec
        bcs     relocate

        .byte   $04, $21, $91   ; 4/21/91

;;; --------------------------------------------------
;;; Relocate this code from $2000 (.SYSTEM start location) to $1000
;;; and start executing there. This is done so that the next .SYSTEM
;;; file can be loaded/run at $2000.

.proc relocate
        src := SYS_ADDR
        dst := $1000

        ldx     #(sys_end - sys_start + $FF) / $100 ; pages
        ldy     #0
load:   lda     src,y           ; self-modified
        load_hi := *-1
        sta     dst,y           ; self-modified
        store_hi := *-1
        iny
        bne     load
        inc     load_hi
        inc     store_hi
        dex
        beq     find_self_name  ; done
        jmp     load
.endproc

;;; --------------------------------------------------
;;; Identify the name of this SYS file, which should be present at
;;; $280 with or without a path prefix. This is used when searching
;;; for the next .SYSTEM file to execute.

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

        ;; Copy name into |self_name| buffer
copy:   ldy     #0
cloop:  iny
        inx
        lda     PATHNAME,x
        sta     self_name,y
        cpy     $A8
        bcc     cloop
        sty     self_name
.endproc
        ;; Fall through...

;;; --------------------------------------------------

.proc pre_install
        cld
        bit     ROMIN2

        ;; Update reset vector - re-invokes this code.
        lda     #<pre_install
        sta     $03F2
        lda     #>pre_install
        sta     $03F3
        eor     #$A5
        sta     $03F4

        lda     #$95            ; Ctrl+U (quit 80 col firmware)
        jsr     COUT

        ldx     #$FF            ; Reset stack
        txs

        sta     CLR80VID        ; Reset I/O
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
        HIASCIIZ CR, "Previous Clock Installed!", BELL, CR

        jmp     launch_next_sys_file
.endproc

;;; --------------------------------------------------
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
        jsr     MON_HOME
        jsr     zstrout
        HIASCIIZ CR, "No-SLot Clock Not Found.", CR, CR,\
                 "Clock Not Installed!", BELL, CR
        jmp     launch_next_sys_file

saved:  .byte   0, 0, 0, 0
tries:  .byte   3
slot:   .byte   0
.endproc

;;; --------------------------------------------------
;;; Install NSC Driver. Copy into address at DATETIME vector,
;;; update the vector and update MACHID bits to signal a clock
;;; is present.

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
        HIASCIIZ CR, "No-Slot Clock Installed  "

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
;;; Find and invoke the next .SYSTEM file

.proc launch_next_sys_file
        ;; Update reset vector - now terminates.
        lda     #<quit
        sta     $03F2
        lda     #>quit
        sta     $03F3
        eor     #$A5
        sta     $03F4

        ptr := $A5
        len := $A8

        ;; Volume Directory Block Header structure
        prev_block              := $00
        next_block              := $02
        entry_length            := $23
        entries_per_block       := $24
        header_length           := $2B

        lda     DEVNUM          ; stick with most recent device
        sta     read_block_params_unit_num
        jsr     read_block

        lda     data_buffer + entry_length
        sta     entry_length_mod
        lda     data_buffer + entries_per_block
        sta     entries_per_block_mod
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
        adc     #$27            ; self-modified: entry_length
        entry_length_mod := *-1
        sta     ptr
        bcc     :+
        inc     ptr+1
:       inc     $A7
        lda     $A7
        cmp     #$0D            ; self-modified: entries_per_block
        entries_per_block_mod := *-1
        bcc     entry

        lda     data_buffer + next_block
        sta     read_block_params_block_num
        lda     data_buffer + next_block + 1
        sta     read_block_params_block_num+1
        ora     read_block_params_block_num
        beq     not_found       ; last block has next=0
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
        HIASCIIZ CR, CR, CR, "* Unable to find next '.SYSTEM' file *", CR
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

        pla                     ; read address from stack
        sta     ptr
        pla
        sta     ptr+1

        bne     skip            ; ???

next:   cmp     #(HI 'a')       ; lower-case?
        bcc     :+
        and     lowercase_mask  ; make upper-case if needed
:       jsr     COUT
skip:   inc     ptr
        bne     :+
        inc     ptr+1
:       ldy     #$00
        lda     (ptr),y
        bne     next

        lda     ptr+1           ; restore address to stack
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
        .byte   0               ; crash if QUIT fails
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
block_num: .word   2            ; block_num - block 2 is volume directory
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
        HIASCIIZ CR, CR, CR, "**  Disk Error $"
        pla
        jsr     PRBYTE
        jsr     zstrout
        HIASCIIZ "  **", CR
        bit     KBDSTRB
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
;;; NSC driver - copied into ProDOS

driver:
        php
        sei
ld4:    lda     $CFFF           ; self-modified
        pha
st1:    sta     $C300           ; self-modified
ld1:    lda     $C304           ; self-modified
        ldx     #8
L140D:
ld3:    lda     unlock-1,x      ; self-modified
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
:       lda     $C304           ; self-modified
        ror     a
        ror     $01FF,x
        dey
        bne     :-
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
:       adc     #$0A
        dey
        bne     :-
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

;;; --------------------------------------------------

sys_end:

;;; --------------------------------------------------
;;; Junk from here on...

        .byte $b3, $68, $72, $f0, $2a, $2a, $2a, $2a
        .byte $2a, $2a, $20, $2f, $52, $41, $4d, $20
        .byte $8d, $00, $2a, $2a, $2a, $2a, $2a, $2a
        .byte $2a, $2a, $2a, $2a, $2a, $2a, $20, $2f
        .byte $43, $4f, $4e, $54, $49, $45, $52, $49
        .byte $20, $8d, $00, $2a, $2a, $2a, $2a, $2a
        .byte $2a, $2a, $03, $2f, $48, $44, $20, $8d
        .byte $00, $2a, $2a, $2a, $2a, $2a, $2a, $2a
        .byte $2a, $2a, $2a, $2a, $2a, $2a, $2a, $2a
        .byte $2a, $2a, $2a, $2a, $2a, $2a, $2a, $2a
        .byte $2a, $2a, $2a, $2a, $6a, $2d, $2a, $2a
        .byte $2a, $2a, $2a, $2a, $2a, $2a, $2a, $2a
        .byte $2a, $2a, $2a, $2a, $2a, $2a, $2a, $2a
        .byte $2a, $31, $f0, $03, $4c, $43, $3a, $ad
        .byte $3e, $2a, $2a, $2a, $2a, $2a, $2a, $2a
        .byte $2a, $2a, $2a, $2a, $2a, $2a, $2a, $2a
        .byte $2a, $2a, $2a, $2a, $2a, $2a, $2a, $2a
        .byte $2a, $2a, $2a, $2a, $2a, $2a, $2a, $2a
        .byte $2a, $2a, $2a, $2a, $2a, $2a, $2a, $2a
        .byte $2a, $2a, $2a, $2a, $2a, $2a, $2a, $2a
        .byte $2a, $2a, $2a, $2a, $2a, $2a, $2a, $2a
        .byte $2a, $2a, $2a, $2a, $2a, $2a, $2a, $2a
        .byte $2a, $2a, $2a, $2a, $2a, $2a, $2a, $2a
        .byte $2a, $2a, $2a, $2a, $2a, $2a, $2a, $2a
        .byte $2a, $2a, $2a, $2a, $2a, $2a, $2a, $2a
        .byte $2a, $2a, $2a, $2a, $2a, $2a, $2a, $2a
        .byte $2a, $2a, $2a, $2a, $2a, $2a, $2a, $2a
        .byte $2a, $2a, $2a, $2a, $2a, $2a, $2a, $2a
        .byte $2a, $2a, $2a, $2a, $2a, $2a, $2a, $2a
        .byte $2a, $ca, $fc, $30, $f0, $07, $c9, $4c
        .byte $f0, $2a, $2a, $2a, $2a, $2a, $2a, $2a
        .byte $2a, $2a, $2a, $2a, $2a, $2a, $2a, $2a
        .byte $2a, $2a, $2a, $2a, $2a, $2a, $2a, $2a
        .byte $2a, $2a, $2a, $2a, $2a, $2a, $2a, $2a
        .byte $2a, $2a, $2a, $2a, $2a, $2a, $2a, $2a
        .byte $2a, $2a, $2a, $2a, $2a, $2a, $2a, $2a
        .byte $2a, $2a, $2a, $2a, $2a, $2a, $2a, $2a
        .byte $2a, $2a, $2a, $2a, $2a, $2a, $2a, $2a
        .byte $2a, $2a, $2a, $2a, $2a, $2a, $2a, $2a
        .byte $2a, $2a, $2a, $2a, $2a, $2a, $2a, $2a
        .byte $2a, $2a, $2a, $2a, $2a, $2a, $2a, $2a
        .byte $2a, $2a, $2a, $2a, $2a, $2a, $2a, $2a
        .byte $2a, $2a, $2a, $2a, $2a, $2a, $2a, $2a
        .byte $2a, $2a, $2a, $2a, $2a, $2a, $2a, $2a
        .byte $2a, $2a, $2a, $2a, $2a, $2a, $2a, $2a
        .byte $2a, $00, $00, $00, $ad, $50, $31, $d0
        .byte $01, $2a, $2a, $2a, $2a, $2a, $2a, $2a
        .byte $2a, $2a, $2a, $2a, $2a, $2a, $2a, $2a
        .byte $2a, $2a, $2a, $2a
