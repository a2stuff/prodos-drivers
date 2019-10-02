
        .setcpu "6502"
        .include "apple2.inc"
        .include "prodos.inc"

        .org    $2000

CLR80VID        := $C00C
ROMIN2          := $C082
SETVID          := $FE93
SETKBD          := $FE89
INIT            := $FB2F
HOME            := $FC58
SETNORM         := $FE84

        cld
        bit     ROMIN2
        sta     CLR80VID
        sta     CLRALTCHAR
        sta     CLR80COL
        jsr     SETVID
        jsr     SETKBD
        jsr     SETNORM
        jsr     INIT
        jsr     HOME

        MLI_CALL QUIT, quit_params
        brk

quit_params:
        .byte   4
        .byte   0
        .word   0
        .byte   0
        .word   0
