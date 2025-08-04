#!/bin/bash

# Use Cadius to create a disk image for distribution
# https://github.com/mach-kernel/cadius

set -e

PACKDIR=$(mktemp -d)
IMGFILE="prodos-drivers.po"
VOLNAME="drivers"

rm -f "$IMGFILE"
cadius CREATEVOLUME "$IMGFILE" "$VOLNAME" 140KB --no-case-bits --quiet
cadius CREATEFOLDER "$IMGFILE" "/$VOLNAME/SETUPS" --no-case-bits --quiet

add_file () {
    cp "$1" "$PACKDIR/$2"
    cadius ADDFILE "$IMGFILE" "$3" "$PACKDIR/$2" --no-case-bits --quiet
}

# Drivers

for file in \
  "bbb" "buhbye" "bye" "selector" \
        "clock" "cricket" "dclock" "fn.clock" "ns.clock" "romxrtc" \
        "ram.drv" \
        "zipchip" \
        "me.first" "pause" "home" "noclock"; do
  add_file "out/$file.system.SYS" "$file.system#FF0000" "/$VOLNAME"
  add_file "out/$file.setup.SYS"  "$file.setup#FF0000"  "/$VOLNAME/SETUPS"
done
add_file "out/setup.system.SYS" "setup.system#FF0000" "/$VOLNAME"
add_file "out/quit.system.SYS"  "quit.system#FF0000" "/$VOLNAME"

# Utilities

add_file "out/date.BIN" "date#062000" "/$VOLNAME"

cadius CREATEFOLDER "$IMGFILE" "/$VOLNAME/CRICKET.UTIL" --no-case-bits --quiet
add_file "out/cricket.util/set.datetime.BIN" "set.datetime#062000" "/$VOLNAME/CRICKET.UTIL"
add_file "out/cricket.util/set.date.BIN"     "set.date#062000"     "/$VOLNAME/CRICKET.UTIL"
add_file "out/cricket.util/set.time.BIN"     "set.time#062000"     "/$VOLNAME/CRICKET.UTIL"
add_file "out/cricket.util/test.BIN"         "test#062000"         "/$VOLNAME/CRICKET.UTIL"

cadius CREATEFOLDER "$IMGFILE" "/$VOLNAME/NSCLOCK.UTIL" --no-case-bits --quiet
add_file "out/nsclock.util/set.datetime.BIN" "set.datetime#062000" "/$VOLNAME/NSCLOCK.UTIL"



cadius CREATEFOLDER "$IMGFILE" "/$VOLNAME/TEXTCOLORS" --no-case-bits --quiet
cadius CREATEFOLDER "$IMGFILE" "/$VOLNAME/SETUPS/TEXTCOLORS" --no-case-bits --quiet
for file in a2green bw deepblue gray gsblue mint pink wb; do
    add_file "out/${file}.system.SYS" "${file}.system#FF0000" "/$VOLNAME/TEXTCOLORS"
    add_file "out/${file}.setup.SYS"  "${file}.setup#FF0000"  "/$VOLNAME/TEXTCOLORS/SETUPS"
done

rm -r "$PACKDIR"

cadius CATALOG "$IMGFILE"
