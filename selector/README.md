# Selector - Disassembly

The ProDOS operating system for the Apple II personal computer line supported a quit routine (invoked from BASIC with the `BYE` command) allowing the user to type the next prefix and name of a system file to invoke once the previous system file had exited.

* `ENTER PREFIX (PRESS "RETURN" TO ACCEPT)"`
* `ENTER PATHNAME OF NEXT APPLICATION`

This was replaced in later versions of ProDOS with much improved selector showing a list of files and allowing navigation of the file system with the keyboard.

But... maybe you are feeling retro? This `SELECTOR.SYSTEM` patches the old version of the selector back in. Like the other drivers here, it is intended to be placed on your boot volume to run on startup, and will chain to the next `.SYSTEM` file found. You can follow it with `QUIT.SYSTEM` in your driver sequence if you want to show the selector on startup.
