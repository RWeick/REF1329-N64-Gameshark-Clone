# REF1329-N64-Gameshark-Clone
This implements the original LZ9FC17 GAL on an Altera EPM240. It fully supports all functionality to include: parallel port, 7 segment display, and the GS button.

The upper EEPROM contains the high bytes of the BIN, and the lower EEPROM contains the lower bytes of the BIN. Happy making.

This is my first foray into Verilog, and I welcome any comments or suggestions about how I could have done it better.

Huge shoutout to @Parasyte for his ceaseless guidance, mentorship, and encouragement, as well as for originally documenting the hardware registers of the N64 Gameshark. This would not exist without him.

Huge shoutout to the #N64Brew community, who have provided countless resources and documentation that enabled me to complete this project.

PCB Thickness: 1.2 mm

![image](https://github.com/Modman/REF1329-N64-Gameshark-Clone/blob/main/Front.png)
