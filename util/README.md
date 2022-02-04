# Utilities

* [DATE](date.s)
  * Prints the current ProDOS date/time, to verify the time is set and updating. Run from the BASIC prompt: `-DATE`
* [QUIT.SYSTEM](quit.system.s)
  * This invokes the ProDOS quit handler immediately. It can be used as the last in a chain of "driver" installers to invoke the program selector, e.g. if you want to also keep `BASIC.SYSTEM` in your root directory but not launch it.
* [PAUSE.SYSTEM](pause.system.s)
  * Waits for a fraction of a second before invoking the next driver file. Useful in case the log messages from the driver installers go by too quickly!
* [ME.FIRST.SYSTEM](me.first.system.s)
  * Moves the current volume to the end of DEVLST. Niche, but useful in some circumstances.
