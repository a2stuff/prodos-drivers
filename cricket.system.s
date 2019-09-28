;;; The Cricket Clock - ProDOS System
;;; Adapted from /CRICKET/PRODOS.MOD
;;; Original: Street Electronics Corporation (C) 1984

;;; Adapted from: /NO.SLOT.CLOCK/NS.CLOCK.SYSTEM
;;; Original by "CAP" 04/21/91
;;; http://www.apple2.org.za/gswv/a2zine/GS.WorldView/v1999/Oct/MISC/NSC.Disk.TXT

        .setcpu "6502"
        .linecont +

        .include "apple2.inc"
        .include "opcodes.inc"

        .include "./common.inc"

;;; ------------------------------------------------------------

        data_buffer = $1800

        read_delay_hi = $3 * 3 ; ($300 iterations is normal * 3.6MHz)

        .define SYSTEM_SUFFIX ".SYSTEM"
        .define PRODUCT "Cricket Clock"

;;; ------------------------------------------------------------

        .org $1000

        ;;  Loaded at $2000 but relocates to $1000

;;; ------------------------------------------------------------

sys_start:
        sec
        bcs     relocate

        .byte   MM, DD, YY      ; version date stamp

;;; ------------------------------------------------------------
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

;;; ------------------------------------------------------------
;;; Identify the name of this SYS file, which should be present at
;;; $280 with or without a path prefix. This is used when searching
;;; for the next .SYSTEM file to execute.

.proc find_self_name
        ;; Search pathname buffer backwards for '/', then
        ;; copy name into |self_name|; this is used later
        ;; to find/invoke the next .SYSTEM file.

        ;; Find '/' (which may not be present, prefix is optional)
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

;;; ------------------------------------------------------------
;;; Before installing, get the system to a known state and
;;; ensure there is not a previous clock driver installed.

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

        ;; Quit 80-column firmware
        lda     #$95            ; Ctrl+U (quit 80 col firmware)
        jsr     COUT

        ;; Reset stack
        ldx     #$FF
        txs

        ;; Reset I/O
        sta     CLR80VID
        sta     CLRALTCHAR
        jsr     SETVID
        jsr     SETKBD
        jsr     SETNORM
        jsr     INIT

        ;; Update System Bit Map
        ldx     #BITMAP_SIZE-1
        lda     #%00000001      ; protect page $BF
:       sta     BITMAP,x
        lda     #%00000000      ; nothing else protected until...
        dex
        bne     :-
        lda     #%11001111      ; ZP ($00), stack ($01), text page 1 ($04-$07)
        sta     BITMAP

        lda     MACHID
        and     #$88            ; IIe or IIc (or IIgs) ?
        bne     :+
        lda     #$DF
        sta     lowercase_mask  ; lower case to upper case

:       lda     MACHID
        and     #$01            ; existing clock card?
        beq     detect_cricket  ; nope, check for Cricket

        ;; Chain with no message
        jmp     launch_next_sys_file
.endproc

;;; ------------------------------------------------------------
;;; Detect Cricket. Detect SSC and if present probe device.

.proc detect_cricket

        ;; Check Slot 2 for SSC. ID bytes per:
        ;; Apple II Technical Note #8: Pascal 1.1 Firmware Protocol ID Bytes
        lda     $C205
        cmp     #$38
        bne     ssc_not_found
        lda     $C207
        cmp     #$18
        bne     ssc_not_found
        lda     $C20B
        cmp     #$01
        bne     ssc_not_found
        lda     $C20C
        cmp     #$31
        bne     ssc_not_found

        beq     init_ssc
ssc_not_found:
        jmp     not_found

        ;; Init SSC and try the "Read Cricket ID code" sequence.
init_ssc:
        lda     COMMAND         ; save status of SSC registers
        sta     saved_command
        lda     CONTROL
        sta     saved_control

        ;; Configure SSC
        lda     #%00001011      ; no parity/echo/interrupts, RTS low, DTR low
        sta     COMMAND
        lda     #%10011110      ; 9600 baud, 8 data bits, 2 stop bits
        sta     CONTROL

        ;; Read Cricket ID code: 00 ($00)
        lda     #0
        jsr     sendbyte

        ;; "The Cricket will return a "C" (195, $C3) followed by a
        ;; version number (in ASCII) and a carriage return (141, $8D)."
        jsr     readbyte
        bcs     cricket_not_found ; timeout
        cmp     #HI('C')          ; = 'C' ?
        bne     cricket_not_found

        jsr     readbyte
        bcs     cricket_not_found ; timeout
        bcc     digit

:       jsr     readbyte
        bcs     cricket_not_found ; timeout
        cmp     #HI(CR)           ; = CR ?
        beq     cricket_found
digit:  cmp     #HI('0')          ; < '0' ?
        bcc     cricket_not_found
        cmp     #HI('9' + 1)      ; > '9' ?
        bcs     cricket_not_found
        bcc     :-

cricket_found:
        jsr     restore_cmd_ctl
        jmp     install_driver

cricket_not_found:
        jsr     restore_cmd_ctl
        ;; fall through...

not_found:
        ;; Show failure message
        jsr     MON_HOME
        jsr     zstrout
        HIASCIIZ CR, CR, CR, PRODUCT, " - Not Found."
        jmp     launch_next_sys_file

restore_cmd_ctl:
        lda     saved_control
        sta     CONTROL
        lda     saved_command
        sta     COMMAND
        rts

saved_command:  .byte   0
saved_control:  .byte   0
.endproc

        ;; Write byte in A
.proc sendbyte
        pha
:       lda     STATUS
        and     #(1 << 4)       ; transmit register empty? (bit 4)
        beq     :-              ; nope, keep waiting
        pla
        sta     TDREG
        rts
.endproc

        ;; Read byte into A, or carry set if timed out
.proc readbyte
        tries := $100 * read_delay_hi
        counter := $A5

        lda     #<tries
        sta     counter
        lda     #>tries
        sta     counter+1

check:  lda     STATUS          ; did we get it?
        and     #(1 << 3)       ; receive register full? (bit 3)
        bne     ready           ; yes, we read the value

        dec     counter
        bne     check
        dec     counter+1
        bne     check

        sec                     ; failed
        rts

ready:  lda     RDREG           ; actually read the register
        clc
        rts
.endproc

;;; ------------------------------------------------------------
;;; Install Cricket Driver. Copy into address at DATETIME vector,
;;; update the vector and update MACHID bits to signal a clock
;;; is present.

.proc install_driver
        ptr := $A5

        lda     DATETIME+1
        sta     ptr
        lda     DATETIME+2
        sta     ptr+1
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
        bit     ROMIN2
        jsr     MON_HOME
        jsr     zstrout
        HIASCIIZ CR, CR, CR, PRODUCT, " - Installed  "

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
.endproc

;;; ------------------------------------------------------------
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
        num := $A7
        len := $A8

        lda     DEVNUM          ; stick with most recent device
        sta     read_block_params_unit_num
        jsr     read_block

        lda     data_buffer + VolumeDirectoryBlockHeader::entry_length
        sta     entry_length_mod
        lda     data_buffer + VolumeDirectoryBlockHeader::entries_per_block
        sta     entries_per_block_mod
        lda     #1
        sta     num

        lda     #<(data_buffer + VolumeDirectoryBlockHeader::header_length)
        sta     ptr
        lda     #>(data_buffer + VolumeDirectoryBlockHeader::header_length)
        sta     ptr+1

        ;; Process directory entry
entry:  ldy     #FileEntry::file_type      ; file_type
        lda     (ptr),y
        cmp     #$FF            ; type=SYS
        bne     next
        ldy     #FileEntry::storage_type
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
:       inc     num
        lda     num
        cmp     #$0D            ; self-modified: entries_per_block
        entries_per_block_mod := *-1
        bcc     entry

        lda     data_buffer + VolumeDirectoryBlockHeader::next_block
        sta     read_block_params_block_num
        lda     data_buffer + VolumeDirectoryBlockHeader::next_block + 1
        sta     read_block_params_block_num+1
        ora     read_block_params_block_num
        beq     not_found       ; last block has next=0
        jsr     read_block
        lda     #0
        sta     num
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

next:   cmp     #HI('a')        ; lower-case?
        bcc     :+
        and     lowercase_mask  ; make upper-case if needed
:       jsr     COUT
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

;;; ------------------------------------------------------------
;;; COUT a 2-digit number in A

.proc cout_number
        ldx     #HI('0')
        cmp     #10             ; >= 10?
        bcc     tens

        ;; divide by 10, dividend(+'0') in x remainder in a
:       sbc     #10
        inx
        cmp     #10
        bcs     :-

tens:   pha
        cpx     #HI('0')
        beq     units
        txa
        jsr     COUT

units:  pla
        ora     #HI('0')
        jsr     COUT
        rts
.endproc

;;; ------------------------------------------------------------

lowercase_mask:
        .byte   $FF             ; Set to $DF on systems w/o lower-case

;;; ------------------------------------------------------------
;;; Invoke ProDOS QUIT routine.

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

;;; ------------------------------------------------------------
;;; Read a disk block.

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

;;; ------------------------------------------------------------
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

;;; ------------------------------------------------------------
;;; Error handler - invoked if any ProDOS error occurs.

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

;;; ------------------------------------------------------------

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

;;; ------------------------------------------------------------

found_self_flag:
        .byte   0

suffix: .byte   SYSTEM_SUFFIX

self_name:
        PASCAL_STRING "CRICKET.SYSTEM"

;;; ------------------------------------------------------------
;;; Cricket Clock Driver - copied into ProDOS

.proc driver
        scratch := $3A          ; ZP scratch location

        ;; Initialize
        php
        sei
        lda     COMMAND         ; save status of command register
        pha

        ;; Configure SSC
        lda     #%00001011      ; no parity/echo/interrupts, RTS low, DTR low
        sta     COMMAND
        lda     #%10011110      ; 9600 baud, 8 data bits, 2 stop bits
        sta     CONTROL

        ;; Send command
:       lda     STATUS
        and     #(1 << 4)       ; transmit register empty? (bit 4)
        beq     :-              ; nope, keep waiting
        lda     #HI('@')        ; '@' command
        sta     TDREG

        read_len := 7           ; read 7 bytes (w/m/d/y/H/M/S)

        ;; Read response, pushing to stack
        ldy     #(read_len-1)

rloop:  ldx     #0              ; x = retry loop counter low byte
        lda     #read_delay_hi  ; scratch = retry loop counter high byte
        sta     scratch

check:  lda     STATUS          ; did we get it?
        and     #(1 << 3)       ; receive register full? (bit 3)
        bne     ready           ; yes, we read the value

        inx                     ; not yet, so keep trying
        bne     check           ; until counter runs out
        dec     scratch
        bne     check

        ;; Read failed - restore stack and exit
reset:  cpy     #(read_len-1)   ; anything left to restore?
        beq     done            ; nope, exit
        pla                     ; yep, clear it off the stack
        iny
        bne     reset

        ;; Read succeeded - stuff it on the stack and continue
ready:  lda     RDREG
        pha
        dey
        bpl     rloop

        ;; Convert pushed response to ProDOS time field
        pla                     ; day of week (unused)

        pla                     ; minute
        sta     TIMELO          ; -- stored as-is (TIMELO 5-0)

        pla                     ; hour
        sta     TIMELO+1        ; -- stored as-is (TIMELO 12-8)

        pla                     ; year
        sta     DATELO+1        ; -- will be shifted up by 1 (DATELO 15-9)

        pla                     ; day
        and     #%00011111      ; -- masked, stored as is (DATELO 4-0)
        sta     DATELO

        pla                     ; month
        asl     a               ; -- shifted up (DATELO 8-5)
        asl     a
        asl     a
        asl     a
        asl     a
        ora     DATELO          ; -- merge low 5 bits
        sta     DATELO
        rol     DATELO+1

        pla                     ; seconds (unused)

        ;; Restore prior state
done:   pla                     ; restore saved command state
        sta     COMMAND
        plp
        rts
.endproc
        sizeof_driver := .sizeof(driver)
        .assert sizeof_driver <= 125, error, "Clock code must be <= 125 bytes"
;;; ------------------------------------------------------------

sys_end:
