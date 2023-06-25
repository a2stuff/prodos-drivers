# No Slot Clock ProDOS Driver

Adapted from `NS.CLOCK.SYSTEM` (by "CAP"), with these changes:

* Fixes a typo
* Removes beeps
* Is less chatty so you can have multiple clock drivers, e.g. if you use the same hard disk image across different hardware configurations
* Uses file I/O rather than block I/O for chaining
* Does not hard-code driver file name

## Other Utilities

These `BRUN`able files are also built:
* [SET.DATETIME](set.datetime.s) sets the No Slot Clock date/time.
