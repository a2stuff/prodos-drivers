# Disassembly of Glen E. Bredon's `RAM.DRV.SYSTEM` for Apple II ProDOS


[![Build Status](https://travis-ci.org/a2stuff/ram.drv.system.svg?branch=master)](https://travis-ci.org/a2stuff/ram.drv.system)


This was started before realizing what the origin of the `RAM.SYSTEM`
found on a MouseDesk 2.0 disk image file was.

There is a more complete diassembly with commentary at:

http://boutillon.free.fr/Underground/Outils/Ram_Drv_System/Ram_Drv_System.html

## Project Details

* The `orig` branch compiles to to match the original.
* The `master` branch has additions, including:
  * Chains to next `.SYSTEM` file in dir order (not hard coded)
  * Chains to next `.SYSTEM` file on non-block devices (e.g. file shares)
