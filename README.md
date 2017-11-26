# The Cricket - ProDOS Clock Driver

I acquired a Cricket sound/clock peripheral on eBay. Therefore it is now critical that we have a conforming ProDOS clock driver for it.

> STATUS: Work In Progress

## Background

"The Cricket" by Street Electronics Corporation, released in 1984, is a hardware peripheral for the Apple //c computer. It plugs into the serial port and offers a multi-voice sound synthesizer, a speech synthesizer, and a real-time clock.

The included disks include:
* `/CRICKET/PRODOS.MOD` which can be BRUN to patch ProDOS in memory with a clock driver.
* A modified version of ProDOS
* A utility to patch ProDOS on disk

## Goal

Like the `NS.CLOCK.SYSTEM` (author?) ideally we would have:

* A ProDOS `.SYSTEM` file
* Which detects the presence of a Cricket
* And if found, installs the driver in memory following the ProDOS clock driver protocol
* And finally chains to the next `.SYSTEM` file (e.g. `BASIC.SYSTEM`)
