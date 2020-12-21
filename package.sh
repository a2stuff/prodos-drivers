#!/bin/bash

# Use Cadius to create a disk image for distribution
# https://github.com/mach-kernel/cadius

set -e

PACKDIR=$(mktemp -d)
IMGFILE="drivers.po"
VOLNAME="drivers"

rm -f "$IMGFILE"
cadius CREATEVOLUME "$IMGFILE" "$VOLNAME" 140KB --no-case-bits --quiet
cadius CREATEFOLDER "$IMGFILE" "/$VOLNAME/CRICKET.UTIL" --no-case-bits --quiet

add_file () {
    cp "$1" "$PACKDIR/$2"
    cadius ADDFILE "$IMGFILE" "$3" "$PACKDIR/$2" --no-case-bits --quiet
}

add_file "bbb/out/buhbye.system.SYS"        "buhbye.system#FF0000"   "/$VOLNAME"
add_file "bbb/out/bye.system.SYS"           "bye.system#FF0000"      "/$VOLNAME"
add_file "selector/out/selector.system.SYS" "selector.system#FF0000" "/$VOLNAME"
add_file "cricket/out/cricket.system.SYS"   "cricket.system#FF0000"  "/$VOLNAME"
add_file "cricket/out/date.BIN"             "date#062000"            "/$VOLNAME/CRICKET.UTIL"
add_file "cricket/out/set.date.BIN"         "set.date#062000"        "/$VOLNAME/CRICKET.UTIL"
add_file "cricket/out/set.time.BIN"         "set.time#062000"        "/$VOLNAME/CRICKET.UTIL"
add_file "cricket/out/test.BIN"             "test#062000"            "/$VOLNAME/CRICKET.UTIL"
add_file "ns.clock/out/ns.clock.system.SYS" "ns.clock.system#FF0000" "/$VOLNAME"
add_file "quit/out/quit.system.SYS"         "quit.system#FF0000"     "/$VOLNAME"
add_file "ram.drv/out/ram.drv.system.SYS"   "ram.drv.system#FF0000"  "/$VOLNAME"

rm -r "$PACKDIR"

cadius CATALOG "$IMGFILE"
