# SETUP.SYSTEM

The November 1987 edition of Call-A.P.P.L.E features an article by Sean Nolan, ["SYSTEM.SETUP - A Proposed Startup File Standard"](https://www.callapple.org/magazines-4/call-a-p-p-l-e/setup-system-a-proposed-startup-file-standard/). The article was reprinted in [Beneath Apple DOS ProDOS 2020](https://archive.org/details/beneath-apple-dos-prodos-2020). The proposal combines the ProDOS-8 notion of running the first .SYSTEM file found on disk and the convention of chaining to the next .SYSTEM file, with the ProDOS-16 notion of enumerating a directory of startup files. A main `SETUP.SYSTEM` file is provided which enumerates all files in a `SETUPS/` directory. These "setup files" are BIN or SYS files which work like standard ProDOS-8 drivers. The advantages of this approach are:

* The top level directory only needs one SYSTEM file plus `SETUPS/`, which reduces clutter.
* Each individual setup file is simpler than stand-alone SYSTEM files, as they don't need to implement chaining.

Which approach you use is a matter of taste.

## How do you use these?

If you choose this approach, use a tool like Copy II Plus or [Apple II DeskTop](https://github.com/a2stuff/a2d) to copy and arrange `SETUP.SYSTEM` as the first `.SYSTEM` file in your root directory. Create a `SETUPS/` directory, and copy the appropriate `.SETUPS` files there. A boot disk image catalog that is used on multiple different hardware configurations might include:

* `PRODOS` - the operating system, e.g. [ProDOS 2.4](https://prodos8.com/)
* `SETUP.SYSTEM` - install No-Slot clock driver, if present
* `QUIT.SYSTEM` - invoke the Quit handler immediately, as a program selector
* `BASIC.SYSTEM` - which will not be automatically invoked, but is available to manually invoke
* `SETUPS/NS.CLOCK.SYSTEM` - install No-Slot clock driver, if present
* `SETUPS/ROMXRTC.SYSTEM` - install ROMX clock driver, if present
* `SETUPS/FN.CLOCK.SYSTEM` - install FujiNet clock driver, if present
* `SETUPS/DCLOCK.SYSTEM` - install DClock clock driver, if present
* `SETUPS/CRICKET.SYSTEM` - install Cricket! clock driver, if present
* `SETUPS/ZIPCHIP.SYSTEM` - slow the ZIP CHIP on speaker access, if present
* `SETUPS/RAM.DRV.SYSTEM` - install RamWorks RAM disk driver, if present
* `SETUPS/BUHBYE.SYSTEM` - install a customized Quit handler to replace the built-in one
* `SETUPS/PAUSE.SYSTEM` - pause for a moment, so that you can inspect the output of the above

## Notes

The `SETUP.SYSTEM` program is not modified from the published version except that it no longer clears the screen between running each file in `SETUPS/`, so that any logged output remains visible.
