# Applied Engineering DClock &mdash; ProDOS Clock Driver

This is based on a disassembly of the Applied Engineering driver for the DClock real time clock add on for the Apple IIc.

> NOTE: Currently untested!

Like other drivers here, this one will:

* Conditionally install, only if a DClock is detected.
  * Only attempts detection if there is not already a clock driver.
  * Only attempts detection if the system is a an Apple IIc
* If detected, installs into ProDOS directly, following Technical Reference Manual requirements.
* Chains to the next `.SYSTEM` file in the directory.
