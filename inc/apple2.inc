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

TBCOLOR         := $C022        ; IIgs: low nibble is text bg color, high is fg
CLOCKCTL        := $C034        ; IIgs: low nibble is border color

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
VERSION         := $FBB3
ZIDBYTE         := $FBC0
BELL1           := $FBDD
HOME            := $FC58
CLREOL          := $FC9C
RDKEY           := $FD0C
GETLN           := $FD6A        ; with prompt character
GETLN2          := $FD6F        ; no prompt character
CROUT           := $FD8E
PRBYTE          := $FDDA
COUT            := $FDED
COUT1           := $FDF0
SETINV          := $FE80
SETNORM         := $FE84
SETKBD          := $FE89
SETVID          := $FE93
BELL            := $FF3A

;;; ============================================================
;;; Applesoft ROM routines
;;; ============================================================
;;; These require various ZP locations to be initialized.

LINPRNT         := $ED24        ; print X,A as integer

;;; ============================================================
;;; Well-known RAM locations
;;; ============================================================

INPUT_BUFFER    := $200
RESETVEC        := $3F2
COL80HPOS       := $57B

;;; ============================================================
;;; Applesoft Zero Page Locations
;;; ============================================================

TEMPPT          := $52
TEMPST          := $55
SHIFT_SIGN_EXT  := $A4
SPEEDZ          := $F1
FLASH_BIT       := $F3
