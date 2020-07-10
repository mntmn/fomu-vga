# Fomu Crazy VGA Experiment

This is based on the "blink-expanded" example of fomu-workshop. The idea is to generate VGA via the 4 exposed pads of the Fomu, plus the USB GND like this:

- Pad 1 -> VGA HS
- Pad 2 -> VGA VS
- Pad 3 -> VGA Color Bit 0
- Pad 4 -> VGA Color Bit 1
- USB GND -> GND

I also want to implement a simple framebuffer that would accept data via USB, but so far I couldn't get the random USB code that I found (usbcorev) to work. I still need to learn more about the USB low-level details. Help is appreciated!

## Using

Type `make` to build the DFU image.
Type `dfu-util -D blink.dfu` to load the DFU image onto the Fomu board.
Type `make clean` to remove all the generated files.
