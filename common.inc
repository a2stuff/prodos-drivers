;;; ------------------------------------------------------------
;;; ASCII

BELL            := $07
BS              := $08
CR              := $0D

;;; ------------------------------------------------------------
;;; Constants

MAX_DW          := $FFFF


;;; ------------------------------------------------------------
;;; Softswitches

CLR80VID        := $C00C        ; 40 Columns
ROMIN2          := $C082        ; Read ROM; no write
RWRAM1          := $C08B        ; Read/write RAM bank 1

;;; ------------------------------------------------------------
;;; ProDOS

PRODOS          := $BF00
DATETIME        := $BF06
DEVNUM          := $BF30
BITMAP          := $BF58
BITMAP_SIZE     := 24           ; 24 bytes in system bit map
DATELO          := $BF90
TIMELO          := $BF92
MACHID          := $BF98

SYS_ADDR        := $2000        ; Load address for SYSTEM files
PATHNAME        := $0280        ; Pathname of loaded system file

;;; MLI commands
MLI_QUIT        := $65
MLI_READ_BLOCK  := $80
MLI_GET_TIME    := $82
MLI_OPEN        := $C8
MLI_READ        := $CA
MLI_CLOSE       := $CC

.macro PRODOS_CALL call, params
        jsr     PRODOS
        .byte   call
        .addr   params
.endmacro

;;; Volume Directory Block Header structure
.scope VolumeDirectoryBlockHeader
        prev_block              := $00
        next_block              := $02
        entry_length            := $23
        entries_per_block       := $24
        header_length           := $2B
.endscope

;; File Entry structure
.scope FileEntry
        storage_type := $00
        name_length := $00
        file_name := $01
        file_type := $10
.endscope

;;; ------------------------------------------------------------
;;; Monitor

INIT            := $FB2F
MON_HOME        := $FC58
GETLN           := $FD6A        ; with prompt character
GETLN2          := $FD6F        ; no prompt character
CROUT           := $FD8E
PRBYTE          := $FDDA
COUT            := $FDED
SETNORM         := $FE84
SETKBD          := $FE89
SETVID          := $FE93

INPUT_BUFFER    := $200

;;; ------------------------------------------------------------
;;; I/O Registers (for Slot 2)

TDREG    := $C088 + $20         ; ACIA Transmit Register (write)
RDREG    := $C088 + $20         ; ACIA Receive Register (read)
STATUS   := $C089 + $20         ; ACIA Status/Reset Register
COMMAND  := $C08A + $20         ; ACIA Command Register (read/write)
CONTROL  := $C08B + $20         ; ACIA Control Register (read/write)

;;; ------------------------------------------------------------

;;; Length-prefixed string
.macro PASCAL_STRING arg
        .byte   .strlen(arg)
        .byte   arg
.endmacro

;;; ------------------------------------------------------------

;;; Define a string with high bits set
;;; e.g. HIASCII "Ding ding", $7, $7
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

;;; Like HIASCII, but null-terminated
.macro  HIASCIIZ arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9
        HIASCII arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9
        .byte   0
.endmacro

;;; Set the high bit on the passed byte
.define HI(c)   ((c)|$80)
