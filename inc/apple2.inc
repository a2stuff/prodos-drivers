;;; ============================================================
;;;
;;; More Apple II Symbols
;;;
;;; ============================================================

;;; ============================================================
;;; Soft Switches
;;; ============================================================

;;; I/O Soft Switches / Firmware

RAMRDOFF        := $C002
RAMRDON         := $C003
RAMWRTOFF       := $C004
RAMWRTON        := $C005
ALTZPOFF        := $C008
ALTZPON         := $C009

CLR80VID        := $C00C
SET80VID        := $C00D
RDALTZP         := $C016
RD80STORE       := $C018
RDPAGE2         := $C01C

BANKSEL         := $C073        ; Select RamWorks bank

ROMIN2          := $C082        ; Read ROM; no write
ROMINWB1        := $C089        ; Read ROM; write RAM bank 1
RWRAM1          := $C08B        ; Read/write RAM bank 1

;;; ============================================================
;;; I/O Registers (for Slot 2)
;;; ============================================================

TDREG    := $C088 + $20         ; ACIA Transmit Register (write)
RDREG    := $C088 + $20         ; ACIA Receive Register (read)
STATUS   := $C089 + $20         ; ACIA Status/Reset Register
COMMAND  := $C08A + $20         ; ACIA Command Register (read/write)
CONTROL  := $C08B + $20         ; ACIA Control Register (read/write)

;;; ============================================================
;;; Other Slots
;;; ============================================================

SLOT3           := $C300

;;; ============================================================
;;; Monitor ROM routines
;;; ============================================================

INIT            := $FB2F
SETTXT          := $FB39
TABV            := $FB5B
SETPWRC         := $FB6F
BELL1           := $FBDD
HOME            := $FC58
CLREOL          := $FC9C
RDKEY           := $FD0C
GETLN           := $FD6A        ; with prompt character
GETLN2          := $FD6F        ; no prompt character
CROUT           := $FD8E
PRBYTE          := $FDDA
COUT            := $FDED
SETINV          := $FE80
SETNORM         := $FE84
SETKBD          := $FE89
SETVID          := $FE93
BELL            := $FF3A

;;; ============================================================
;;; Well-known RAM locations
;;; ============================================================

INPUT_BUFFER    := $200
RESETVEC        := $3F2
COL80HPOS       := $57B
