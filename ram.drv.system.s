;;; Disassembly of "RAM.SYSTEM" found on Mouse Desk 2.0 images
;;; Based on Glen E. Bredon's "RAM.DRV.SYSTEM"
;;; Some details c/o http://boutillon.free.fr/Underground/Outils/Ram_Drv_System/Ram_Drv_System.html
;;;
;;; Modifications:
;;;   * Chain to next .SYSTEM file dynamically

        .feature string_escapes

        .setcpu "6502"

        .include "apple2.inc"
        .include "apple2.mac"
        .include "inc/macros.inc"
        .include "inc/apple2.inc"
        .include "inc/prodos.inc"
        .include "opcodes.inc"


;;; ============================================================

        ;; SYS files load at $2000; relocates self to $1000
        .org SYS_ADDR
        dst_addr := $1000

;;; ============================================================
;;; Relocate from $2000 to $1000

.proc relocate
        src := reloc_start
        dst := dst_addr

        ldx     #(reloc_end - reloc_start + $FF) / $100 ; pages
        ldy     #0
load:   lda     src,y     ; self-modified
        load_hi := *-1
        sta     dst,y      ; self-modified
        store_hi := *-1
        iny
        bne     load
        inc     load_hi
        inc     store_hi
        dex
        bne     load

        jmp     main
.endproc

;;; ============================================================
;;; Start of relocated code
;;;

        reloc_start := *
        pushorg dst_addr

;;; ============================================================
;;; Main routine
;;; ============================================================

.proc main
        jsr     setup
        jsr     maybe_install_driver
        jsr     launch_next
        brk
.endproc


;;; ============================================================
;;; Preserve state needed to chain to next file
;;; ============================================================

.proc setup
        ;; --------------------------------------------------
        ;; Save most recent device for later, when chaining
        ;; to next .SYSTEM file.
        lda     DEVNUM
        sta     devnum

        ;; --------------------------------------------------
        ;; Identify the name of this SYS file, which should be present at
        ;; $280 with or without a path prefix. Search pathname buffer
        ;; backwards for '/', then copy name into |self_name|.

        ;; Find '/' (which may not be present, prefix is optional)
        ldx     PATHNAME
        beq     no_name
        ldy     #0              ; Y = length
:       lda     PATHNAME,x
        and     #$7f            ; ignore high bit
        cmp     #'/'
        beq     copy_name
        iny
        dex
        bne     :-

        ;; Copy name into |self_name| buffer
copy_name:
        cpy     #0
        beq     no_name
        sty     self_name

        ldx     PATHNAME
:       lda     PATHNAME,x
        sta     self_name,y
        dex
        dey
        bne     :-

        ;; Done
        rts

no_name:
        lda     #0
        sta     self_name
        rts
.endproc

devnum:         .byte   0
self_name:      .res    16

;;; ============================================================
;;; Find and invoke the next .SYSTEM file
;;; ============================================================

.proc quit
        MLI_CALL QUIT, quit_params
        brk                     ; crash if QUIT fails

        DEFINE_QUIT_PARAMS quit_params
.endproc

online_buf              := $1C00
io_buf                  := $1C00
dir_buf                 := $2000
block_len               = $200

        DEFINE_ON_LINE_PARAMS on_line_params,,online_buf
        DEFINE_OPEN_PARAMS open_params, PATHNAME, io_buf
        DEFINE_READ_PARAMS read_params, SYS_ADDR, SYS_LEN
        DEFINE_READ_PARAMS read_block_params, dir_buf, block_len
        DEFINE_CLOSE_PARAMS close_params

.proc launch_next
        ;; Read directory and look for .SYSTEM files; find this
        ;; one, and invoke the following one.

        ptr := $A5
        num := $A7
        len := $A8

        ;; --------------------------------------------------
        ;; Own name found? If not, just quit
        lda     self_name
        beq     quit
        ;; --------------------------------------------------
        ;; Find name of boot device, copy into PATHNAME
        lda     devnum
        sta     on_line_params::unit_num
        MLI_CALL ON_LINE, on_line_params
        bcc     :+
        jmp     on_error

:       lda     #'/'            ; Prefix by '/'
        sta     PATHNAME+1
        lda     online_buf
        and     #$0F            ; Mask off length
        sta     PATHNAME
        ldx     #0              ; Copy name
:       lda     online_buf+1,x
        sta     PATHNAME+2,x
        inx
        cpx     PATHNAME
        bne     :-
        inx                     ; One more for '/' prefix
        stx     PATHNAME

        ;; Open directory
        MLI_CALL OPEN, open_params
        bcc     :+
        jmp     on_error
:       lda     open_params::ref_num
        sta     read_block_params::ref_num
        sta     close_params::ref_num

        ;; Read first "block"
        MLI_CALL READ, read_block_params
        bcc     :+
        jmp     on_error

        ;; Get sizes out of header
:       lda     dir_buf + VolumeDirectoryHeader::entry_length
        sta     entry_length_mod
        lda     dir_buf + VolumeDirectoryHeader::entries_per_block
        sta     entries_per_block_mod
        lda     #1
        sta     num

        ;; Set up pointers to entry
        lda     #<(dir_buf + .sizeof(VolumeDirectoryHeader))
        sta     ptr
        lda     #>(dir_buf + .sizeof(VolumeDirectoryHeader))
        sta     ptr+1

        ;; Process directory entry
entry:  ldy     #FileEntry::file_type      ; file_type
        lda     (ptr),y
        cmp     #$FF            ; type=SYS
        bne     next
        ldy     #FileEntry::storage_type_name_length
        lda     (ptr),y
        and     #$30            ; regular file (not directory, pascal)
        beq     next
        lda     (ptr),y
        and     #$0F            ; name_length
        sta     len
        tay

        ;; Compare suffix - is it .SYSTEM?
        ldx     suffix
:       lda     (ptr),y
        cmp     suffix,x
        bne     next
        dey
        dex
        bne     :-

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

        ;; Read next "block"
        MLI_CALL READ, read_block_params
        bcs     not_found

        ;; Set up pointers to entry
        lda     #0
        sta     num
        lda     #<(dir_buf + $04)
        sta     ptr
        lda     #>(dir_buf + $04)
        sta     ptr+1
        jmp     entry

        ;; --------------------------------------------------
        ;; Found a .SYSTEM file which is not this one; invoke
        ;; it if follows this one.
handle_sys_file:
        bit     found_self_flag
        bpl     next

        MLI_CALL CLOSE, close_params

        ;; Compose the path to invoke.
        ldx     PATHNAME
        inx
        lda     #'/'
        sta     PATHNAME,x
        ldy     #0
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
        scrcode "\r\r* Unable to find next '.SYSTEM' file *\r"
        .byte   0

        bit     KBDSTRB
:       lda     KBD
        bpl     :-
        bit     KBDSTRB
        jmp     quit
.endproc

;;; ------------------------------------------------------------
;;; Load/execute the system file in PATHNAME

.proc invoke_system_file
        MLI_CALL OPEN, open_params
        bcs     on_error

        lda     open_params::ref_num
        sta     read_params::ref_num

        MLI_CALL READ, read_params
        bcs     on_error

        MLI_CALL CLOSE, close_params
        bcs     on_error

        jmp     SYS_ADDR        ; Invoke loaded SYSTEM file
.endproc

;;; ------------------------------------------------------------
;;; Error handler - invoked if any ProDOS error occurs.

.proc on_error
        pha
        jsr     zstrout
        scrcode "\r\r*  Disk Error $"
        .byte   0

        pla
        jsr     PRBYTE

        jsr     zstrout
        scrcode "  *\r"
        .byte   0

        bit     KBDSTRB
:       lda     KBD
        bpl     :-
        bit     KBDSTRB
        jmp     quit
.endproc

;;; ============================================================
;;; Data

suffix:
        PASCAL_STRING ".SYSTEM"

found_self_flag:
        .byte   0


;;; ============================================================
;;;
;;; Driver Installer
;;;
;;; ============================================================

;;; ============================================================
;;; Configuration Parameters

        .define PRODUCT "RAMWorks RAM Disk"

zp_sig_addr             := $06

zpproc_addr             := $B0
zpproc_relay_addr       := $2D0

data_buf                := $1C00 ; I/O when chaining to next SYS file
driver_target           := $FF00 ; Install location in ProDOS


kMaxUsableBanks         = 24    ; Why is this capped so low???
                                ; (driver has room for another ~20?)

banks_to_reserve:       .byte   0       ; banks to reserve (e.g. for AppleWorks)
unitnum:                .byte   $03     ; S3D1; could be $B for S3D2

;;; ============================================================
;;; Install the driver

.proc maybe_install_driver

        sta     CLR80COL
        ldy     #0
        sty     BANKSEL
        sta     ALTZPON         ; Use ZP to probe banks

        ;; Clear map1 / map2 (256 bytes) to $FF
        lda     #$FF
:       sta     map1,y
        iny
        bne     :-

        ;; Stash first two bytes of each bank (128 possible banks)
:       sty     BANKSEL
        lda     $00
        sta     stash_00,y
        lda     $01
        sta     stash_01,y
        iny
        bpl     :-
        dey

        ;; Write bank num/complement at $0/$1
:       sty     BANKSEL
        sty     $00
        tya
        eor     #$FF
        sta     $01
        dey
        bne     :-

        ;; Y = 0

        ;; Reset signature bytes on main/aux banks
        sty     BANKSEL
        sty     $00
        sty     $01
        sta     ALTZPOFF
        sty     $00
        sty     $01
        sta     ALTZPON

        lda     banks_to_reserve
        sta     reserved_banks

;;; ============================================================

        ;; Copy into every bank
        ldy     #1
bank_loop:
        ;; Check bank for signature bytes (bank num/complement at $0/$1)
        sty     BANKSEL
        cpy     $00
        bne     next_bank
        tya
        eor     #$FF
        eor     $01
        bne     next_bank
        cpy     $00             ; Bank 0 (aux) is reserved for 128k apps
        bne     next_bank

        ;; Flag as available in map2
        ;; (map2,N = N if available, $FF otherwise)
        tya
        sta     map2,y

        ;; Skip over reserved banks, then start storing them in the map
        ldx     reserved_banks
        bne     :+
        sta     first_used_bank
:       dec     reserved_banks
        bpl     next_bank
        sta     map1,y
        ;; (map1,N = N if available, $FF otherwise - also???)

        ;; Copy helper proc into bank's ZP
        ldx     #sizeof_zpproc
:       lda     zpproc-1,x
        sta     zpproc_addr-1,x
        dex
        bne     :-

next_bank:
        iny
        bpl     bank_loop

;;; ============================================================

        ;; Y = $80

        ;; Restore stashed $0/$1 bytes of back
        ;; (except first, in first_used_bank ???)
loop0:  lda     map2-1,y
        bmi     :+
        cmp     first_used_bank
        beq     :+
        sta     BANKSEL
        lda     stash_00-1,y
        sta     $00
        lda     stash_01-1,y
        sta     $01
:       dey
        bne     loop0

        ;; Y = 0
        sty     BANKSEL
        sty     $00

        ;; Count number of available banks, and populate
        ;; driver_bank_list with list of banks.
        ldx     #$FF
loop1:  inx
        cpx     #kMaxUsableBanks
        bcs     break
loop2:  iny
        bmi     break
        lda     map1,y
        bmi     loop2
        sta     driver_bank_list,x
        bpl     loop1
break:
        ;; Patch driver with block-specific data
        ;; X = number of available banks

        ;; Compute number of blocks
        txa
        lsr     a
        sta     vol_dir_header+VolumeDirectoryHeader::total_blocks+1
        ror     vol_dir_header+VolumeDirectoryHeader::total_blocks

        stx     driver_block_x  ; num banks
        dex                     ; -1
        stx     num_banks_minus_one

        bmi     fail            ; 0 banks? give up.

        lda     vol_dir_header+VolumeDirectoryHeader::total_blocks
        sec
        sbc     driver_block_x
        and     #$F8
        sta     vol_dir_header+VolumeDirectoryHeader::total_blocks
        sta     driver_blocks_lo
        bcs     :+
        dec     vol_dir_header+VolumeDirectoryHeader::total_blocks+1
:       lda     vol_dir_header+VolumeDirectoryHeader::total_blocks+1
        sta     driver_blocks_hi

        lda     driver_bank_list
        sta     BANKSEL
        lda     $00
        beq     fail

        ;; Check for ZP signature - if not found, set it and install.
        ldx     #sig_len-1
:       lda     sig,x
        cmp     zp_sig_addr,x
        bne     set_sig
        dex
        bpl     :-

        bit     BUTN1           ; escape hatch in case of loop ???
        bmi     L21F0
        jmp     do_install

fail:   jmp     install_failure

sloop:  lda     sig,x
set_sig:
        sta     zp_sig_addr,x
        dex
        bpl     sloop

;;; ============================================================

;;; Prepare key blocks in

L21F0:  sta     ALTZPOFF

        ;; Stamp current date/time into vol_dir_header
        ldy     #3
:       lda     DATELO,y
        sta     vol_dir_header+VolumeDirectoryHeader::creation_date,y
        dey
        bpl     :-

        ;; Fill pages $06-$0F with 00-FF
        sta     RAMWRTON
        iny
        tya
:       sta     $0600,y         ; Block 2 - volume dir
        sta     $0700,y
        sta     $0800,y         ; Block 3 - volume dir
        sta     $0900,y
        sta     $0A00,y         ; Block 4 - volume dir
        sta     $0B00,y
        sta     $0C00,y         ; Block 5 - volume dir
        sta     $0D00,y
        sta     $0E00,y         ; Block 6 - volume bitmap
        sta     $0F00,y
        iny
        bne     :-

        ;; Copy vol_dir_header into page $06
        ldy     #.sizeof(VolumeDirectoryHeader)-1
:       lda     vol_dir_header,y
        sta     $0600,y
        dey
        bpl     :-

        ldy     #$02
        sty     $0800
        iny
        sty     $0A00
        iny
        sty     $0C00
        sty     $0802
        iny
        sty     $0A02

        ptr := $3C
        lda     vol_dir_header+VolumeDirectoryHeader::total_blocks
        sta     ptr
        lda     vol_dir_header+VolumeDirectoryHeader::total_blocks+1
        lsr     a
        ror     ptr
        lsr     a
        ror     ptr
        lsr     a
        ror     ptr
        clc
        adc     #$0E
        sta     ptr+1

        ldy     #0
        tya
:       sta     (ptr),y
        lda     ptr
        sec
        sbc     #1
        sta     ptr
        lda     #$FF
        bcs     :-
        dec     ptr+1
        ldx     ptr+1
        cpx     #$0E
        bcs     :-
        lda     #$01
        sta     $0E00

;;; ============================================================

do_install:
        lda     #0
        sta     RAMWRTOFF
        sta     ALTZPOFF
        sta     BANKSEL
        bit     LCBANK1
        bit     LCBANK1

        lda     #OPC_CLD        ; signature
        cmp     driver_target
        beq     copy_driver
        sta     ALTZPON         ; Maybe in AUX?
        cmp     driver_target
        beq     copy_driver
        cmp     $DE00           ; ???
        beq     copy_driver
        sta     ALTZPOFF

        ;; Copy driver into place
copy_driver:
        ldy     #0
:       lda     driver_src,y
        sta     driver_target,y
        iny
        cpy     #sizeof_driver
        bcc     :-

        ;; Check if unitnum already has a device
        ldy     DEVCNT
:       lda     DEVLST,y
        lsr     a
        lsr     a
        lsr     a
        lsr     a
        cmp     unitnum
        beq     install_device
        dey
        bpl     :-

        ;; Shift devices up by one
        inc     DEVCNT
        ldy     DEVCNT
:       lda     DEVLST-1,y
        sta     DEVLST,y
        dey
        bne     :-

        ;; Install device in ProDOS via DEVLST/DEVADR.
        ;; (Y has index in DEVLST)
install_device:
        lda     unitnum
        asl     a
        tax
        asl     a
        asl     a
        asl     a
        sta     on_line_params+1 ; unit_number
        ora     #$0E            ; $3E - signature byte used by DeskTop
        sta     DEVLST,y
        copy16  #(driver_target+1), DEVADR,x

        ;; Did we install into S3D2?
        lda     unitnum
        cmp     #$0B            ; Slot 3 Drive 2
        beq     finish

        ;; No, so uninstall S3D2 (regular /RAM)
        ldy     DEVCNT
:       lda     DEVLST,y
        and     #$F0
        cmp     #$B0            ; Slot 3 drive 2 i.e. normal /RAM
        beq     found
        dey
        bpl     :-
        bmi     finish           ; always

        ;; Actually remove from DEVLST
        slot3d2_devadr := DEVADR + $10 + 3*2
found:  ldx     slot3d2_devadr + 1
        inx
        bne     finish
:       copy    DEVLST+1,y, DEVLST,y
        iny
        cpy     DEVCNT
        bcc     :-
        beq     :-
        dec     DEVCNT
        copy16  NODEV, slot3d2_devadr ; clear driver

finish: bit     ROMIN2
        MLI_CALL ON_LINE, on_line_params
        ldx     #$00
        lda     on_line_params_buffer
        ora     L239F
        bne     install_success
        bcc     install_success
        copy    #$FF, L239F
        sta     ALTZPON
        copy    driver_bank_list, BANKSEL
        stx     $06
        stx     BANKSEL
        stx     vol_dir_header+VolumeDirectoryHeader::total_blocks
        jmp     maybe_install_driver  ; retry???

install_success:
        sta     ALTZPOFF

        jsr     HOME
        jsr     zstrout
        scrcode "\r\r\r", PRODUCT, " - Installed"
        .byte   0

        rts

install_failure:
        sta     ALTZPOFF

        jsr     HOME
        jsr     zstrout
        scrcode "\r\r\r", PRODUCT, " - Not Installed"
        .byte   0

        rts

;;; ============================================================
;;; Installed on zero page of each bank at $B0

.proc zpproc
        pushorg ::zpproc_addr

        sta     $E0             ; dst1 hi
        bcs     :+
        sty     $E0             ; dst1 hi
        tay
:       lda     #$00
        sta     RAMWRTON
        bcc     :+
        txa
        ldx     #$00
        sta     RAMWRTOFF
        sta     RAMRDON

        ;; One block = two pages
:       sty     $DD             ; src1 hi
        iny
        sty     $E3             ; src2 hi

        sta     $DF             ; dst1 lo
        sta     $E5             ; dst2 lo

        stx     $DC             ; src1 lo
        stx     $E2             ; src2 lo

        ldy     $E0             ; dst1 hi
        iny
        sty     $E6             ; dst2 hi

        ldy     #$00
:       lda     $1000,y         ; src1
        sta     $1000,y         ; dst1
        lda     $1000,y         ; src2
        sta     $1000,y         ; dst2
        iny
        bne     :-

        sta     RAMWRTOFF
        sta     RAMRDOFF
        clc
        bit     $02E4
        rts

        poporg
.endproc
        sizeof_zpproc := .sizeof(zpproc)

;;; ============================================================

        on_line_params_buffer := $220
        DEFINE_ON_LINE_PARAMS on_line_params, $30, on_line_params_buffer

num_banks_minus_one:
        .byte   0

L239F:  .byte   0

sig:    scrcode "GEB"           ; signature sequence - Glen E. Bredon
        sig_len = * - sig

        ;; Volume Directory Header
.proc vol_dir_header
        .word   0               ; preceding block number
        .word   $03             ; succeeding block number
        .byte   ST_VOLUME_DIRECTORY << 4 | 3 ; storage type / name length
        .byte   "RAM"                        ; name field is 15 bytes
        .res    15-3
        .res    8, 0            ; reserved (8 bytes)
        .word   0, 0            ; creation date/time
        .byte   1               ; version (1 = ProDOS 2.0)
        .byte   0               ; min_version
        .byte   ACCESS_DEFAULT  ; access
        .byte   $27             ; entry_length
        .byte   $D              ; entries_per_block
        .word   0               ; file_count
        .word   6               ; bit_map_pointer
blocks: .word   0               ; total_blocks
.endproc
        .assert .sizeof(vol_dir_header) = .sizeof(VolumeDirectoryHeader), error, "Size mismatch"

.endproc

;;; ============================================================
;;; Ram Disk Driver - installed at $FF00
;;; ============================================================

.proc driver_src
        pushorg ::driver_target
        driver_start := *

start:  cld                     ; used as a signature

        lda     DRIVER_COMMAND
        bne     not_status
        driver_blocks_lo := *+1
        ldx     #0              ; self-modified - blocks low
        driver_blocks_hi := *+1
        ldy     #0              ; self-modified - blocks high
LFF09:  clc
        bcc     LFF83           ; always

not_status:
        cmp     #DRIVER_COMMAND_FORMAT
        beq     LFF09

        ;; COMMAND_READ or COMMAND_WRITE
LFF10:  lda     #$27
        bcs     rts1

        lda     RD80STORE
        pha
        sta     CLR80COL

        ;; Save $40/41
        lda     $40
        pha
        lda     $41
        pha

        lda     DRIVER_BUFFER
        sta     $40
        ldx     DRIVER_BUFFER+1
        inx
        stx     $41

        jsr     install_zpproc_relay

        zpproc_relay_patch1_offset := $04
        stx     zpproc_relay_addr + zpproc_relay_patch1_offset
        lda     RDALTZP

        zpproc_relay_patch2_offset := $14
        sta     zpproc_relay_addr + zpproc_relay_patch2_offset
        lda     DRIVER_BLOCK_NUMBER+1
        pha
        tax
        lda     DRIVER_BLOCK_NUMBER
LFF3C:  sec
:       iny
        sbc     #$7F
        bcs     :-
        dex
        bpl     LFF3C

        tya
        adc     DRIVER_BLOCK_NUMBER
        bcc     :+
        inc     DRIVER_BLOCK_NUMBER+1
:       asl     a
        tay
        lda     DRIVER_BLOCK_NUMBER+1
        rol     a
        tax
        pla
        sta     DRIVER_BLOCK_NUMBER+1
        driver_block_x := *+1
        cpx     #$0             ; self-modified - ???
        bcs     LFF74

        tya
        sbc     #191
        cmp     #16
        bcs     :+
        adc     #208

        tay
        bit     LCBANK2
:       lda     DRIVER_COMMAND
        lsr     a               ; carry set = READ, clear = WRITE
        lda     bank_list,x
        ldx     DRIVER_BUFFER
        jsr     zpproc_relay_addr
        bit     LCBANK1

LFF74:  jsr     install_zpproc_relay

        ;; Restore $40/41
        pla
        sta     $41
        pla
        sta     $40

        pla
        bpl     LFF83
        sta     SET80COL
LFF83:  lda     #$00
        bcs     LFF10

rts1:   rts

install_zpproc_relay:
        ldy     #sizeof_zpproc_relay+1
:       ldx     zpproc_relay-1,y
        lda     zpproc_relay_addr-1,y
        sta     zpproc_relay-1,y
        txa
        sta     zpproc_relay_addr-1,y
        dey
        bne     :-

        ldx     DRIVER_BUFFER+1
        bpl     done
        bit     DRIVER_BUFFER+1
        bvc     done

:       ldx     $8000,y
        lda     (DRIVER_BUFFER),y
        sta     $8000,y
        txa
        sta     (DRIVER_BUFFER),y
        ldx     $8100,y
        lda     ($40),y
        sta     $8100,y
        txa
        sta     ($40),y
        iny
        bne     :-

        ldx     #$80
done:   rts

bank_list:
        .res    ::kMaxUsableBanks, 0

.proc zpproc_relay
        sta     BANKSEL

        patch_loc1 := *+1
        lda     #$00
        sta     ALTZPON
        jsr     zpproc_addr
        sty     BANKSEL
        bmi     :+
        sta     ALTZPOFF
:       rts

        patch_loc2 := *
.endproc
        sizeof_zpproc_relay := .sizeof(zpproc_relay)
        patch_loc1_offset := zpproc_relay::patch_loc1 - zpproc_relay
        patch_loc2_offset := zpproc_relay::patch_loc2 - zpproc_relay
        ;; These offsets can't be used directly due to ca65 addressing mode
        ;; assumptions, so just verify they are correct.
        .assert zpproc_relay_patch1_offset = patch_loc1_offset, error, "Offset mismatch"
        .assert zpproc_relay_patch2_offset = patch_loc2_offset, error, "Offset mismatch"

        .byte   0

        poporg
.endproc
        sizeof_driver := .sizeof(driver_src)

        driver_blocks_lo := driver_src + driver_src::driver_blocks_lo - driver_src::driver_start
        driver_blocks_hi := driver_src + driver_src::driver_blocks_hi - driver_src::driver_start
        driver_block_x   := driver_src + driver_src::driver_block_x   - driver_src::driver_start
        driver_bank_list := driver_src + driver_src::bank_list        - driver_src::driver_start


;;; ============================================================
;;; Common Routines
;;; ============================================================

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

next:   cmp     #'a'|$80        ; lower-case?
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

lowercase_mask:
        .byte   $FF             ; Set to $DF on systems w/o lower-case


;;; ============================================================
;;; Scratch space beyond code used during driver install

reserved_banks  := *
first_used_bank := *+1
map1            := *+2          ; len: $80
map2            := *+2+$80      ; len: $80
stash_00        := *+2+$100     ; len: $80
stash_01        := *+2+$180     ; len: $80

        .assert stash_01+$80 < data_buf, error, "Too long"

;;; ============================================================
;;; End of relocated code

        poporg
        reloc_end := *
