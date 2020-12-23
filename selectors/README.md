# ProDOS Program Selectors ("BYE" commands)

The ProDOS operating system for the Apple II personal computer line supported a quit routine (invoked from BASIC with the `BYE` command) allowing the user to launch a new system file once previous system file had exited.

This selector code evolved over time, and the memory location that the routine was stored at was documented, allowing users to install customized versions coded to fit within a mere 768 bytes.

## ProDOS 1.0 through 1.8 - Selector

The earliest versions of ProDOS supported a simple 40-column-friendly selector prompting:

* `ENTER PREFIX (PRESS "RETURN" TO ACCEPT)"`
* `ENTER PATHNAME OF NEXT APPLICATION`

This was not particularly user friendly.

ℹ️ If you want to use this selector with any version of ProDOS, add the `SELECTOR.SYSTEM` file to your boot sequence. You can follow it with `QUIT.SYSTEM` in your driver sequence to show the selector on startup.

## Bird's Better Bye

[Alan Bird](https://alanlbird.wordpress.com/products/) wrote a replacement called **Bird's Better Bye** that would patch itself into ProDOS. Directories and system files could be selected with arrows keys and the Return key, Escape would back up a directory level, Tab would change drives. This also functioned in 40 column mode.

ℹ️ If you want to use this selector with any version of ProDOS, add the `BBB.SYSTEM` file to your boot sequence. You can follow it with `QUIT.SYSTEM` in your driver sequence to show the selector on startup.

## ProDOS 1.9 and 2.0.x - 80-column Selector

ProDOS 1.9 introduced a much improved menu-driven selector showing a list of files and allowing navigation of the file system with the keyboard. Directories and system files could be selected with arrows keys and the Return key, Escape would back up a directory level, Tab would change drives. This required 80 columns and a 65C02 processor, and took advantage of the [MouseText characters](https://en.wikipedia.org/wiki/MouseText) to show folder glyphs for directories.

If these versions of ProDOS were started on systems without 40 column support, the previous version of the selector would be loaded instead (both were present in the PRODOS system file.)

ℹ️ If you want to use this selector with any version of ProDOS, add the `BYE.SYSTEM` file to your boot sequence. You can follow it with `QUIT.SYSTEM` in your driver sequence to show the selector on startup.

This was inspired by the work of Dave Cotter who created a similarly named file to patch the selector back in. It can be found at: http://www.lazilong.com/apple_ii/bye.sys/bye.html

## ProDOS 2.4 - Bitsy Bye

The new (unofficial) releases of [ProDOS 2.4](http://www.callapple.org/uncategorized/announcing-prodos-2-4-for-all-apple-ii-computers/) by John Brooks include a replacement quit routine called Bitsy Bye, a collaboration with Peter Ferrie. This new quit routine is far more powerful, allowing access to BASIC and binary files (and more), drive selection, type-down, more entries, and so on. It uses only 40 columns, and does not require a 65C02 processor.

ℹ️ If you want to use this selector, use a version of ProDOS 2.4 from https://prodos8.com/

## Buh-Bye - Enhanced 80-column selector

Since I prefered the look of the ProDOS 80-column selector to Bitsy Bye, but missed the type-down ability, I modified the 80-column selector to tighten up the code added seeking if an alphabetical key is typed. Hit 'C' and the list will scroll to the next file starting with 'C'.

I erroneously thought that the ProDOS 80-column selector was _Bird's Better Bye_ and named this "Bell's Better Bird's Better Bye" or "Buh-Bye".

ℹ️ If you want to use this selector with any version of ProDOS, add the `BUHBYE.SYSTEM` file to your boot sequence. You can follow it with `QUIT.SYSTEM` in your driver sequence to show the selector on startup.
