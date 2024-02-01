# ProDOS Drivers

[![build](https://github.com/a2stuff/prodos-drivers/actions/workflows/main.yml/badge.svg)](https://github.com/a2stuff/prodos-drivers/actions/workflows/main.yml)

Build with [ca65](https://cc65.github.io/doc/ca65.html)

# What are ProDOS "drivers"?

The ProDOS operating system for the Apple II executes the first `.SYSTEM` file found in the boot directory on startup. A common pattern is to have the boot directory contain several "driver" files that customize ProDOS by installing drivers for hardware or modify specific parts of the operating system. These include:

* Real-time Clock drivers (e.g. No-Slot Clock, Cricket!, AE DClock, etc)
  * In ProDOS 1.x, 2.0 and 2.4 the Thunderclock driver is built-in.
* RAM Disk drivers (e.g. RamWorks)
  * In ProDOS 1.x, 2.0 and 2.4 only a 64K driver for /RAM is built-in.
* Quit dispatcher/selector (`BYE` routines)
  * In ProDOS 1.0 and later, a 40-column friendly [selector](selector) prompts for a prefix then a path `ENTER PREFIX (PRESS "RETURN" TO ACCEPT)`
  * In ProDOS 1.9 and 2.0.x, on 80-column systems, a menu-driven selector is installed instead.
  * In ProDOS 2.4.x [Bitsy Bye](https://prodos8.com/bitsy-bye/) is built-in.

Early versions of these drivers would often invoke a specific file on completion, sometimes user-configurable. The best versions of these drivers simply execute the following `.SYSTEM` file, although this is non-trivial code and often did not work with network drives.

This repository collects several drivers and uses common code to chain to the next `.SYSTEM` file, suporting network drives.

## What is present here?

This repo includes the following drivers/modifications:

* Real-time Clock drivers
  * No-Slot Clock
  * Cricket!
  * Applied Engineering DClock
  * ROMX Real-Time Clock
  * FujiNet Clock
  * A "jumbo" driver that includes all of the above (just called `CLOCK.SYSTEM`)
* Accelerators
  * ZIP CHIP configuration (sets the chip to slow on speaker access)
* RAM Disk drivers
  * RAMWorks Driver by Glen E. Bredon
* Quit dispatcher/selector (`BYE` routines)
  * 40-column Selector (from ProDOS)
  * 80-column menu-driven Selector (from ProDOS 1.9 and 2.x)
  * Bird's Better Bye (a 40-column menu-driven selector)
  * Buh-Bye (an enhanced version of the ProDOS 80-column, menu-driven selector)
* Text color themes
  * These set the IIgs (or VidHD) text/background/border colors

In addition, `QUIT.SYSTEM` is present which isn't a driver but which immediately invokes the QUIT handler (a.k.a. program selector). This will happen automatically if the last driver can't find another `.SYSTEM` file, but `QUIT.SYSTEM` can be used to stop the chain.

There's also `PAUSE.SYSTEM` which just waits for a fraction of a second before invoking the next driver file. (Why? In case the log messages from the other installers goes by too fast!)

Non-drivers that are included:
* The `DATE` binary file can be `BRUN` (or just `-DATE`) to show the current ProDOS Date/Time, to verify that the clock driver is working.
* Some utilities for The Cricket! clock are also included.

## How do you use these?

The intent is that you use a tool like Copy II Plus or [Apple II DeskTop](https://github.com/a2stuff/a2d) to copy and arrange the SYSTEM files on your boot disk as you see fit. A boot disk image catalog that is used on multiple different hardware configurations might include:

* `PRODOS` - the operating system, e.g. [ProDOS 2.4](https://prodos8.com/)
* `NS.CLOCK.SYSTEM` - install No-Slot clock driver, if present
* `ROMXRTC.SYSTEM` - install ROMX clock driver, if present
* `FN.CLOCK.SYSTEM` - install FujiNet clock driver, if present
* `DCLOCK.SYSTEM` - install DClock clock driver, if present
* `CRICKET.SYSTEM` - install Cricket! clock driver, if present
* `ZIPCHIP.SYSTEM` - slow the ZIP CHIP on speaker access, if present
* `RAM.DRV.SYSTEM` - install RamWorks RAM disk driver, if present
* `BUHBYE.SYSTEM` - install a customized Quit handler to replace the built-in one
* `PAUSE.SYSTEM` - pause for a moment, so that you can inspect the output of the above
* `QUIT.SYSTEM` - invoke the Quit handler immediately, as a program selector
* `BASIC.SYSTEM` - which will not be automatically invoked, but is available to manually invoke

Alternately, you might want to install some drivers then immediately launch into BASIC. In that case, put `BASIC.SYSTEM` after the drivers in place of `QUIT.SYSTEM`.

## Alternate Approach

If you want to keep your volume directory tidier, consider using [SETUP.SYSTEM](./setup/README.md) instead.

# Building

Fetch, build, and install [cc65](http://cc65.github.io/cc65/):

```
git clone https://github.com/cc65/cc65
make -C cc65 && make -C cc65 avail
```

Fetch and build this repo:

```
git clone https://github.com/a2stuff/prodos-drivers
cd prodos-drivers
make
```

To make a disk image, fetch, build and install [Cadius](https://github.com/mach-kernel/cadius):

```
git clone https://github.com/mach-kernel/cadius
make -C cadius && make -C cadius install
```

Then you can:

```
cd prodos-drivers
make && make package
```

This will produce `prodos-drivers.po`, a disk image for use with emulators or tools like [ADTPro](http://adtpro.com/).

Notes:
* Specify `LOG_SUCCESS=0` and/or `LOG_FAILURE=0` (e.g. `make LOG_SUCCESS=0`) to build with driver success and/or error logging suppressed.
