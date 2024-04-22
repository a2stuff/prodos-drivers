;;; ZIPCHIP.SYSTEM
;;; Configures the speaker to be temporarily slow, slots 1-4 fast
;;; TODO: Add a configuration utility

        .setcpu "6502"
        .linecont +
        .feature string_escapes

        .include "apple2.inc"
        .include "apple2.mac"
        .include "opcodes.inc"

        .include "../../inc/apple2.inc"
        .include "../../inc/macros.inc"
        .include "../../inc/prodos.inc"
        .include "../../inc/ascii.inc"

;;; ************************************************************
        .include "../../inc/driver_preamble.inc"
;;; ************************************************************

        ;; From ZIP Chip Manual v1 1987
        ZC_REG_LOCK     := $C05A
        ;; Write:
        ;; $A5 Locks the ZIP CHIP.
        ;; 4 consecutive $5A writes unlock ZIP CHIP.
        ;; While unlocked, any write other than $A5 or
        ;; $5A will initiate an indefinate syncronous [sic]
        ;; sequence.
        kZCLock         = $A5
        kZCUnlock       = $5A

        ZC_REG_ENABLE   := $C05B
        ;; Write - Any hex byte written will enable ZIP CHIP

        ZC_REG_STATUS   := $C05B
        ;; Read - Read the current status of the following:
        ;; bit 0 & 1 - Ramsize where
        ;;   RAMSIZE1 RAMSIZE0 SIZE
        ;;    0        0        8K
        ;;    0        1       16K
        ;;    1        0       32K
        ;;    1        1       64K
        ;; bit 2 - unused
        ;; bit 3 - Delay (for memory)
        ;;   0 = Fast Mode - Delay not in effect
        ;;   1 = Sync Mode - Delay in effect
        ;; bit 4 - Disabled/enabled
        ;;   0 = Chip Enabled
        ;;   1 = Chip Disabled
        ;; bit 5 - Paddle fast/normal
        ;;   0 = Fast Mode
        ;;   1 = Synchronous Mode (Normal)
        ;; bit 6 = Cache Updated by data read
        ;;   0 = No update
        ;;   1 = Yes cache updated
        ;; bit 7 = Clock Pulse - 1.0035 milliseconds
        ;;   Edges occur at .50175 milliseconds

        ZC_REG_SLOTSPKR := $C05C
        ;; Read/Write - Slow/Speaker set and read
        ;;   0 = Set slot/speaker Fast
        ;;   1 = Set slot/speaker Normal
        ;; bit 0 - Speaker      bit 4 - Slot 4
        ;; bit 1 - Slot 1       bit 5 - Slot 5
        ;; bit 2 - Slot 2       bit 6 - Slot 6
        ;; bit 3 - Slot 3       bit 7 - Slot 7

        ZC_REG_SYSSPEED := $C05D
        ;; Write - Set System Speed
        ;; bit 0 - unused       bit 4 - Clk4/5
        ;; bit 1 - unused       bit 5 - Clk5/6
        ;; bit 2 - Clk2/3       bit 6 - Clk/2
        ;; bit 3 - Clk3/4       bit 7 - Clk/4
        ;; NOTE: bit 6 and bit 7 yield Clk/3

        ZC_REG_SYNCOP   := $C05E
        ;; Write - Enable/Disable Synchronous Operation
        ;; for I/O Devices
        ;; bit 0 through bit 6 - Not Used
        ;; bit 7 - Enable/Disable Delay
        ;;   0 = Enable Delay
        ;;   1 = Disable and Reset Delay

        ZC_REG_SOFTSW   := $C05E
        ;; Read - Read Apple softswitches
        ;;   0 = False
        ;;   1 = True
        ;; bit 0 - ROMRD        bit 4 - 80STORE
        ;; bit 1 - RAMBNK       bit 5 - MWR
        ;; bit 2 - PAGE2        bit 6 - MRD
        ;; bit 3 - HIRES        bit 7 - ALTZP

        ZC_REG_PDLBSLC  := $C05F
        ;; Write - Paddle Speed, Bank Switch Language Card
        ;; bit 0 through bit 5 - Not Used
        ;; bit 6 - Paddle Set
        ;;   0 = Disable Paddle Delay
        ;;   1 = Enable Paddle Delay
        ;; bit 7 - Language Card Enable/Disable
        ;;   0 = Enable Cache of Language Card Memory
        ;;   1 = Disable Cache of Language Card Memory


        .undef PRODUCT
        .define PRODUCT "ZIP CHIP"

.proc maybe_install_driver
        php                     ; timing sensitive
        sei

        ;; Unlock
        lda     #kZCUnlock
        sta     ZC_REG_LOCK
        sta     ZC_REG_LOCK
        sta     ZC_REG_LOCK
        sta     ZC_REG_LOCK

        ;; ZIP CHIP present?
        lda     ZC_REG_SLOTSPKR
        eor     #$FF
        sta     ZC_REG_SLOTSPKR
        cmp     ZC_REG_SLOTSPKR
        bne     no_zip
        eor     #$FF
        sta     ZC_REG_SLOTSPKR
        cmp     ZC_REG_SLOTSPKR
        bne     no_zip

        ;; Slow on speaker access, slots 1-4 fast, 5-7 normal
        lda     #%11100001      ; bit 0 = Speaker, bit N = slot N
        sta     ZC_REG_SLOTSPKR

        ;; Get size
        lda     ZC_REG_STATUS
        and     #%00000011
        asl
        tax
        lda     size_table,x
        sta     size
        lda     size_table+1,x
        sta     size+1

        ;; Lock
        lda     #kZCLock
        sta     ZC_REG_LOCK

        jsr     log_message
        scrcode PRODUCT, " "
size:   .res    2               ; patched with cache size
        scrcode "K - Configured."
        .byte   0

        plp
        rts

no_zip:
        jsr     log_message
        scrcode PRODUCT, " - Not Found."
        .byte   0

        plp
        rts

size_table:
        scrcode " 8"
        scrcode "16"
        scrcode "32"
        scrcode "64"



.endproc


;;; ************************************************************
        .include "../../inc/driver_postamble.inc"
;;; ************************************************************
