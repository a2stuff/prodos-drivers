;;; Disassembly of "RAM.SYSTEM" found on Mouse Desk 2.0 images
;;; Based on Glen E. Bredon's "RAM.DRV.SYSTEM"
;;; Some details c/o http://boutillon.free.fr/Underground/Outils/Ram_Drv_System/Ram_Drv_System.html
;;;
;;; Modifications:
;;;   * Chain to next .SYSTEM file dynamically

        .setcpu "6502"
        .linecont +
        .feature string_escapes

        .include "apple2.inc"
        .include "apple2.mac"
        .include "opcodes.inc"

        .include "../inc/apple2.inc"
        .include "../inc/macros.inc"
        .include "../inc/prodos.inc"

;;; ************************************************************
        .include "../inc/driver_preamble.inc"
;;; ************************************************************

;;; ============================================================
;;;
;;; Driver Installer
;;;
;;; ============================================================

;;; ============================================================
;;; Configuration Parameters

        .undef PRODUCT
        .define PRODUCT "RAMWorks RAM Disk"

zp_sig_addr             := $06

zpproc_addr             := $B0
zpproc_relay_addr       := $2D0

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

        ;; Otherwise, insert at end. ProDOS resolves names to devices
        ;; from last to first, so fast RAM disks should go last.
        inc     DEVCNT
        ldy     DEVCNT

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

.if ::LOG_SUCCESS
        jsr     log_message
        scrcode PRODUCT, " - "
        .byte   0
.endif ; ::LOG_SUCCESS

        ;; Initialize Applesoft zero page locations required by LINPRNT
        copy    #0, SHIFT_SIGN_EXT ; required by FP routines
        copy    #TEMPST, TEMPPT    ; string descriptor pointer
        copy    #1, SPEEDZ         ; output delay
        copy    #0, FLASH_BIT      ; character set mask

        ldx     vol_dir_header+VolumeDirectoryHeader::total_blocks
        lda     vol_dir_header+VolumeDirectoryHeader::total_blocks+1
        jsr     LINPRNT

        jsr     zstrout
        scrcode " Blocks"
        .byte   0

        rts

install_failure:
        sta     ALTZPOFF

.if ::LOG_FAILURE
        jsr     log_message
        scrcode PRODUCT, " - Not Found"
        .byte   0
.endif ; ::LOG_FAILURE

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
;;; Scratch space beyond code used during driver install

reserved_banks  := *
first_used_bank := *+1
map1            := *+2          ; len: $80
map2            := *+2+$80      ; len: $80
stash_00        := *+2+$100     ; len: $80
stash_01        := *+2+$180     ; len: $80

;;; ************************************************************
        .include "../inc/driver_postamble.inc"
;;; ************************************************************
