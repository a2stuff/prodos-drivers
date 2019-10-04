;;; ------------------------------------------------------------
;;; ProDOS MLI
;;; ------------------------------------------------------------

;;; ------------------------------------------------------------
;;; ProDOS Global Page

MLI             := $BF00        ; Entry point
DEVNUM          := $BF30        ; Most recent accessed device
DEVCNT          := $BF31        ; Number of on-line devices minus 1
DEVLST          := $BF32        ; Up to 14 units
BITMAP          := $BF58
BITMAP_SIZE     := $18          ; Bits for pages $00 to $BF
DATELO          := $BF90        ; Date lo
DATEHI          := $BF91        ; Date hi
TIMELO          := $BF92        ; Time lo
TIMEHI          := $BF93        ; Time hi


;;; ------------------------------------------------------------
;;; MLI Calls

;;; Housekeeping Calls
CREATE          := $C0
DESTROY         := $C1
RENAME          := $C2
SET_FILE_INFO   := $C3
GET_FILE_INFO   := $C4
ON_LINE         := $C5
SET_PREFIX      := $C6
GET_PREFIX      := $C7

;;; Filing Calls
OPEN            := $C8
NEWLINE         := $C9
READ            := $CA
WRITE           := $CB
CLOSE           := $CC
FLUSH           := $CD
SET_MARK        := $CE
GET_MARK        := $CF
SET_EOF         := $D0
GET_EOF         := $D1
SET_BUF         := $D2
GET_BUF         := $D3

;;; System Calls
GET_TIME        := $82
ALLOC_INTERRUPT := $40
DEALLOC_INTERRUPT       := $41
QUIT            := $65

;;; Direct Disk Access Commands
READ_BLOCK      := $80
WRITE_BLOCK     := $71

;;; ------------------------------------------------------------
;;; File Types

FT_TYPELESS     := $00
FT_BAD          := $01
FT_TEXT         := $04
FT_BINARY       := $06
FT_DIRECTORY    := $0F
FT_SRC          := $B0  ; IIgs system type; re-used?
FT_BASIC        := $FC
FT_SYSTEM       := $FF


;;; ------------------------------------------------------------
;;; Macros

.macro  MLI_CALL    op, addr
        jsr MLI
        .byte op
        .addr addr
.endmacro


;;; ------------------------------------------------------------
;;; Structures

.scope DirectoryHeader
        entry_length    := $23
        entries_per_block := $24
        file_count      := $25

        size := $2B
.endscope

.scope FileEntry
        storage_type    := $00     ; high nibble
        name_length     := $00     ; low nibble
        file_name       := $01
        file_type       := $10
        access          := $1E
.endscope

.scope FileType
        Directory := $0F
        System    := $FF
.endscope
