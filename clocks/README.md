# ProDOS Clock Drivers

Other than the Apple IIgs model, the Apple II did not ship with a real-time system clock. Many third party [Apple II system clocks](https://en.wikipedia.org/wiki/Apple_II_system_clocks) were produced in the 1980s, and many new system clocks are available, either as entirely new designs or recreations.

The ProDOS operating system for the Apple II personal computer line natively supports the Thunderclock real-time clock card, but there is a protocol for custom clock drivers to be installed:

* Check `MACHID` bit 0 to see if a clock is already active; abort if so.
* Optional: Probe hardware to determine if the clock is present; abort if not.
* Relocate the clock driver to LC bank 1, at the address at `DATETIME`+1
* Update `DATETIME` to be a `JMP` instruction.
* Optional: Chain to the next `.SYSTEM` file.

In addition:

* The clock driver must fit into 125 bytes.
* The driver may dirty $200-$207 but other memory must be restored if modified.
* When invoked, the clock driver should read the clock hardware and encode the date and time into `DATELO`/`DATEHI` and `TIMELO`/`TIMEHI`.
* ProDOS calls the clock driver when `GET_TIME` is called, and on every call (`CREATE`, `RENAME`, etc) that might need the date and time.

See https://prodos8.com/docs/techref/adding-routines-to-prodos/ for more information.

## Included drivers

This directory includes drivers for the following real-time clocks:

* [No-Slot Clock](https://www.reactivemicro.com/product/no-slot-clock/)
* [ROMX Real-Time Clock](https://theromexchange.com/)
* [FujiNet Clock](https://fujinet.online/)
* DClock
* Cricket!

All follow the above protocol: install only if there is not already a clock, probe for the clock before installing, and chain to the next driver.

In addition, the "jumbo" directory combines the other driver installers to create a single unified clock driver installer. See its [README](jumbo/README.md) for more details.
