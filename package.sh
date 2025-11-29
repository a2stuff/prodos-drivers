#!/bin/bash

# Use Cadius to create a disk image for distribution
# https://github.com/mach-kernel/cadius

set -e

IMGFILE="prodos-drivers.po"
VOLNAME="drivers"

# cecho - "color echo"
# ex: cecho red ...
# ex: cecho green ...
# ex: cecho yellow ...
function cecho {
    case $1 in
        red)    tput setaf 1 ; shift ;;
        green)  tput setaf 2 ; shift ;;
        yellow) tput setaf 3 ; shift ;;
    esac
    echo -e "$@"
    tput sgr0
}

# suppress - hide command output unless it failed; and if so show in red
# ex: suppress command_that_might_fail args ...
function suppress {
    set +e
    local result
    result=$("$@")
    if [ $? -ne 0 ]; then
        cecho red "$result" >&2
        exit 1
    fi
    set -e
}


rm -f "$IMGFILE"
suppress cadius CREATEVOLUME "$IMGFILE" "$VOLNAME" 140KB --no-case-bits --quiet

PACKDIR=$(mktemp -d)
trap "rm -r $PACKDIR" EXIT

add_file () {
    cp "$1" "$PACKDIR/$2"
    suppress cadius ADDFILE "$IMGFILE" "$3" "$PACKDIR/$2" --no-case-bits --quiet
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

add_file "out/cricket.util/set.datetime.BIN" "set.datetime#062000" "/$VOLNAME/CRICKET.UTIL"
add_file "out/cricket.util/set.date.BIN"     "set.date#062000"     "/$VOLNAME/CRICKET.UTIL"
add_file "out/cricket.util/set.time.BIN"     "set.time#062000"     "/$VOLNAME/CRICKET.UTIL"
add_file "out/cricket.util/test.BIN"         "test#062000"         "/$VOLNAME/CRICKET.UTIL"

add_file "out/nsclock.util/set.datetime.BIN" "set.datetime#062000" "/$VOLNAME/NSCLOCK.UTIL"


for file in a2green bw deepblue gray gsblue mint pink wb; do
    add_file "out/${file}.system.SYS" "${file}.system#FF0000" "/$VOLNAME/TEXTCOLORS"
    add_file "out/${file}.setup.SYS"  "${file}.setup#FF0000"  "/$VOLNAME/TEXTCOLORS/SETUPS"
done

cadius CATALOG "$IMGFILE" | cut -c1-$(tput cols)
