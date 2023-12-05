# "Jumbo" ProDOS Clock Driver

This is an amalgamation of the other clock driver installers. Each one is tried in turn, until one successfully installs a clock driver.

The drivers are (in order):

* No-Slot Clock
* ROMX
* FujiNet
* DClock
* Cricket!

By default, the installer logs on success so you can tell what clock was detected, but you can build with `LOG_SUCCESS=0` to prevent that.

If ProDOS _already_ has a clock driver installed, the driver is checked for common Thunderclock year tables. If found, the table is updated in memory to cover 2023-2028.
