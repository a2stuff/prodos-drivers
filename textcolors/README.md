# Text Color Utilities
These utilities will work with the Apple IIgs or on any Apple II equipped with a VidHD card. Each will set the color of the text, background, and border and then invoke the ProDOS quit handler immediately.

Useful if you'd like to automatically set a theme at boot or select one manually afterwards. Originally created because I wanted my GS to use a different set of colors when booting my ProDOS 8 partition then what I have set as default in the Control Panel.

To have these themes applied at boot, place one of the theme SYSTEM at the end of your load chain.

---

[A2GREEN.SYSTEM](a2green.system.s)
  * Apple Monitor II green phosphor theme

[BW.SYSTEM](bw.system.s)
  * White text on black background

[DEEPBLUE.SYSTEM](deepblue.system.s)
  * White text on deep blue background

[GRAY.SYSTEM](gray.system.s)
  * Dark gray text on light gray background

[GSBLUE.SYSTEM](gsblue.system.s)
  * The Apple IIgs system defaults

[MINT.SYSTEM](mint.system.s)
  * A minty flavored theme

[PINK.SYSTEM](pink.system.s)
  * Dark gray text on a pink background with light blue borders

[WB.SYSTEM](wb.system.s)
  * Black text on a black background

