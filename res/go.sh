#!/bin/bash

# Run this from the ram.drv.system directory

set -e
source "res/util.sh"

function verify {
    diff "orig/$1" "out/$2" \
        && (cecho green "diff $2 good" ) \
        || (tput blink ; cecho red "DIFF $2 BAD" ; return 1)
}


#do_make clean
do_make all

verify "RAM.SYSTEM.SYS" "ram.drv.system.SYS"
