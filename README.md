# The Cricket! - ProDOS Clock Driver

I acquired a Cricket sound/clock peripheral on eBay. Therefore it is now critical that we have a conforming ProDOS clock driver for it.

> STATUS: Works on my machine!

## Background

"The Cricket!" by Street Electronics Corporation, released in 1984, is a hardware peripheral for the Apple //c computer. It plugs into the serial port and offers a multi-voice sound synthesizer, a speech synthesizer, and a real-time clock.

The disks supplied with the device include:
* `/CRICKET/PRODOS.MOD` which can be BRUN to patch ProDOS in memory with a clock driver.
* A modified version of ProDOS
* A utility to patch ProDOS on disk

## Goals

Like the `NS.CLOCK.SYSTEM` (by "CAP") ideally we would have:

* [x] A ProDOS `.SYSTEM` file
* [x] Detects the presence of a Cricket
* [x] Installs a driver in memory following the ProDOS clock driver protocol
* [x] Chains to the next `.SYSTEM` file (e.g. `BASIC.SYSTEM`)

Successfully tested on real hardware. (Laser 128EX, an Apple //c clone &mdash; including at 3x speed!)

## Build

Requires [cc65](https://github.com/cc65/cc65). The included `Makefile` is very specific to my machine - sorry about that.

[CRICKET.SYSTEM](cricket.system.s) is the result of the build.

## Notes

I ended up disassembling both [NS.CLOCK.SYSTEM](ns.clock.system.s) (to understand the SYSTEM chaining - what a pain!) and The Cricket!'s [PRODOS.MOD](prodos.mod.s) and melding them together, adding in the detection routine following the protocol in the manual.

Other files:
* [GET.TIME](get.time.s) just prints the current ProDOS date/time, to verify the time is set and updating.
* [TEST](test.s) attempts to identify an SSC in Slot 2 and the Cricket via the ID sequence, to test routines.

## Resources

Cricket disks on Asimov: 
* ftp://ftp.apple.asimov.net/pub/apple_II/images/hardware/sound/cricket_disk1.po 
* ftp://ftp.apple.asimov.net/pub/apple_II/images/hardware/sound/cricket_disk2.po

Cricket Manual on Asimov:
* ftp://ftp.apple.asimov.net/pub/apple_II/documentation/hardware/sound/Street%20Electronics%20The%20Cricket.pdf
