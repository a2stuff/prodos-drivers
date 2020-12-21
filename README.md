# ProDOS Drivers

[![Build Status](https://travis-ci.org/a2stuff/prodos-drivers.svg?branch=master)](https://travis-ci.org/a2stuff/prodos-drivers)

# What are ProDOS drivers/modifications?

The ProDOS operating system for the Apple II executes the first `.SYSTEM` file found in the boot directory on startup. A common pattern is to have the boot directory contain several "driver" files that customize ProDOS by installing drivers for hardware or modify specific parts of the operating system. These include:

* Real-time Clock drivers (e.g. No-Slot Clock, Cricket!, AE DClock, etc)
  * In ProDOS 1.x, 2.0 and 2.4 the Thunderclock driver is built-in. 
* RAM Disk drivers (e.g. RamWorks)
  * In ProDOS 1.x, 2.0 and 2.4 only a 64K driver for /RAM is built-in.
* Quit dispatcher/selector (`BYE` routines)
  * In ProDOS 1.x a selector prompting `ENTER PREFIX (PRESS "RETURN" TO ACCEPT)` asked for a path.
  * In ProDOS 2.0 [Bird's Better Bye](bbb) is built-in.
  * In ProDOS 2.4 [Bitsy Bye](https://prodos8.com/bitsy-bye/) is built-in.

Early versions of these drivers would often invoke a specific file on completion, sometimes user-configurable. The best versions of these drivers simply execute the following `.SYSTEM` file, although this is non-trivial code and often did not work with network drives.

This repository collects several drivers and uses common code to chain to the next `.SYSTEM` file, suporting network drives. 

## How do you use these?

The intent is that you use a tool like Copy II Plus or [Apple II DeskTop](https://github.com/a2stuff/a2d) to copy and arrange the SYSTEM files on your boot disk as you see fit. An example boot disk catalog might include:

* `PRODOS` - the operating system, e.g. [ProDOS 2.4](https://prodos8.com/)
* `NS.CLOCK.SYSTEM` - install No-Slot Clock driver, if present
* `CRICKET.SYSTEM` - install Cricket! clock driver, if present
* `RAM.DRV.SYSTEM` - install RamWorks RAM disk driver, if present
* `BUHBYE.SYSTEM` - install a customized Quit handler to replace the built-in one
* `QUIT.SYSTEM` - invoke the Quit handler immediately, as a program selector

Alternately, you might want to install some drivers then immediately launch into BASIC. In that case, put `BASIC.SYSTEM` after the drivers in place of `QUIT.SYSTEM`.
