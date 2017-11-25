
        .setcpu "6502"
        .include "apple2.inc"

        .org    $2000           ; System files start at $2000

        ;; ProDOS System Global Page
PRODOS   := $BF00               ; MLI entry point


.proc install
        rts

parmtable:
        .byte   4               ; Number of parameters is 4
        .byte   0               ; 0 is the only quit type
        .word   0000            ; Pointer reserved for future use
        .byte   0               ; Byte reserved for future use
        .word   0000            ; Pointer reserved for future use
.endproc
