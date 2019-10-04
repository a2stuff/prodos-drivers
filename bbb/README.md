# Bird's Better Bye - Disassembly (and improvements)

[![Build Status](https://travis-ci.org/a2stuff/bbb.svg?branch=master)](https://travis-ci.org/a2stuff/bbb)

The ProDOS operating system for the Apple II personal computer line
supported a quit routine (invoked from BASIC with the `BYE` command)
allowing the user to type the name of a system file to invoke once
the previous system file had exited.

[Alan Bird](https://alanlbird.wordpress.com/products/) wrote a
replacement called **Bird's Better Bye** that would patch itself into
ProDOS, fitting into a tight 768 bytes. It provides a menu system,
allowing selection of system files (with the arrow keys), directories
(with the return key to enter and escape key to exit), and devices
(with the tab key), with a minimal and stylish 80-column display using
MouseText folder glyphs.

Later official versions of ProDOS replaced the previous quit routine
with _Bird's Better Bye_.

## ProDOS 2.4 / Bitsy Bye

The new (unofficial) releases of
[ProDOS 2.4](http://www.callapple.org/uncategorized/announcing-prodos-2-4-for-all-apple-ii-computers/)
by John Brooks include a replacement quit routine called Bitsy Bye,
a collaboration with Peter Ferrie. This new quit routine is far more
powerful, allowing access to BASIC and binary files (and more), drive
selection, type-down, more entries, and so on. It runs on older
hardware than _Bird's Better Bye_ so uses only 40 columns, and does
not require a 65C02 processor.

Impressed though I am with the power of Bitsy Bye, I am not a fan of
its aesthetics - the display is "cluttered" to my eye.

## BYE.SYSTEM

Aeons ago, Dave Cotter created BYE.SYSTEM which would patch _Bird's
Better Bye_ back into ProDOS if it had been replaced. It can be found
at:

http://www.lazilong.com/apple_ii/bye.sys/bye.html

Since I really liked the look of _Bird's Better Bye_ I used this as
the boot system for my virtual hard drive (occuring after some [clock
drivers](https://github.com/a2stuff/cricket)).

## Buh-Bye

But... I really wanted a way to quickly scroll through my games list.
So I set out to improve _Bird's Better Bye_ by disassembling it (and
the `BYE.SYSTEM` installer), thus ending up with "Bell's Better Bird's
Better Bye" or "Buh-Bye" for short.

The changes are so far pretty minimal since my 6502 skills are not,
in fact, mad, and there are only 768 bytes to play with.

I replaced the directory enumeration logic with tighter code as
outlined in the ProDOS Technical Reference Manual, and along with
other optimizations I made enough room to add seeking if an
alphabetical key is typed (hit 'C' and the list will scroll to the
next file starting with 'C').

There are a few spare bytes to play with and more can be squeezed
out, so perhaps further improvements can be made.

## QUIT.SYSTEM

This just invokes the ProDOS quit handler immediately. It can
be used as the last in a chain of "driver" installers.
