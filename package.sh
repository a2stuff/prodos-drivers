#!/bin/bash

# Use Cadius to create a disk image for distribution
# https://github.com/mach-kernel/cadius

set -e

PACKDIR=$(mktemp -d)
IMGFILE="prodos-drivers.po"
VOLNAME="drivers"

rm -f "$IMGFILE"
cadius CREATEVOLUME "$IMGFILE" "$VOLNAME" 140KB --no-case-bits --quiet
cadius CREATEFOLDER "$IMGFILE" "/$VOLNAME/CRICKET.UTIL" --no-case-bits --quiet
cadius CREATEFOLDER "$IMGFILE" "/$VOLNAME/NSCLOCK.UTIL" --no-case-bits --quiet

add_file () {
    cp "$1" "$PACKDIR/$2"
    cadius ADDFILE "$IMGFILE" "$3" "$PACKDIR/$2" --no-case-bits --quiet
}

add_file "out/cricket.system.SYS"    "cricket.system#FF0000"  "/$VOLNAME"
add_file "out/cricket.util/set.datetime.BIN"      "set.datetime#062000"    "/$VOLNAME/CRICKET.UTIL"
add_file "out/cricket.util/set.date.BIN"          "set.date#062000"        "/$VOLNAME/CRICKET.UTIL"
add_file "out/cricket.util/set.time.BIN"          "set.time#062000"        "/$VOLNAME/CRICKET.UTIL"
add_file "out/cricket.util/test.BIN"              "test#062000"            "/$VOLNAME/CRICKET.UTIL"
add_file "out/dclock.system.SYS"      "dclock.system#FF0000"   "/$VOLNAME"
add_file "out/ns.clock.system.SYS"  "ns.clock.system#FF0000" "/$VOLNAME"
add_file "out/nsclock.util/set.datetime.BIN"     "set.datetime#062000"    "/$VOLNAME/NSCLOCK.UTIL"
add_file "out/romxrtc.system.SYS"       "romxrtc.system#FF0000"  "/$VOLNAME"
add_file "out/fn.clock.system.SYS"   "fn.clock.system#FF0000" "/$VOLNAME"
add_file "out/clock.system.SYS"        "clock.system#FF0000"    "/$VOLNAME"
add_file "out/ram.drv.system.SYS"    "ram.drv.system#FF0000"  "/$VOLNAME"
add_file "out/bbb.system.SYS"      "bbb.system#FF0000"      "/$VOLNAME"
add_file "out/buhbye.system.SYS"   "buhbye.system#FF0000"   "/$VOLNAME"
add_file "out/bye.system.SYS"      "bye.system#FF0000"      "/$VOLNAME"
add_file "out/selector.system.SYS" "selector.system#FF0000" "/$VOLNAME"
add_file "out/zipchip.system.SYS" "zipchip.system#FF0000" "/$VOLNAME"
add_file "out/quit.system.SYS"          "quit.system#FF0000"     "/$VOLNAME"
add_file "out/pause.system.SYS"         "pause.system#FF0000"    "/$VOLNAME"
add_file "out/me.first.system.SYS"      "me.first.system#FF0000" "/$VOLNAME"
add_file "out/date.BIN"                 "date#062000"            "/$VOLNAME"

cadius CREATEFOLDER "$IMGFILE" "/$VOLNAME/TEXTCOLORS" --no-case-bits --quiet
for file in a2green bw deepblue gray gsblue mint pink wb; do
    add_file "out/${file}.system.SYS"  "${file}.system#FF0000"  "/$VOLNAME/TEXTCOLORS"
done

rm -r "$PACKDIR"

cadius CATALOG "$IMGFILE"
