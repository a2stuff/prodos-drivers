# ProDOS Drivers

[![Build Status](https://travis-ci.org/a2stuff/prodos-drivers.svg?branch=master)](https://travis-ci.org/a2stuff/prodos-drivers)

The ProDOS operating system for the Apple II executes the first `.SYSTEM` file found in the boot directory on startup. A common pattern is to have the boot directory contain several "driver" files that customize ProDOS by installing drivers for hardware or modify specific parts of the operating system. These include:

* Real-time Clock drivers (e.g. No-Slot Clock, Cricket!, AE DClock, etc)
* RAM Disk drivers (e.g. RamWorks)
* Quit dispatcher/selector (`BYE` routines)

Early versions of these drivers would often invoke a specific file on completion, sometimes user-configurable. The best versions of these drivers simply execute the following `.SYSTEM` file, although this is non-trivial code and often did not work with network drives.

This repository collects several drivers and uses common code to chain to the next `.SYSTEM` file, suporting network drives. An example disk catalog might therefore include:

* `PRODOS` - the operating system
* `NS.CLOCK.SYSTEM` - install No-Slot Clock driver, if present
* `CRICKET.SYSTEM` - install Cricket! driver, if present
* `RAM.DRV.SYSTEM` - install RamWorks RAM disk driver, if present
* `BUHBYE.SYSTEM` - install a customized Quit handler
* `QUIT.SYSTEM` - invoke the Quit handler immediately, as a program selector
