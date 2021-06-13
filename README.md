# ***rpi-qmount***

> A quick drive mounting utility for Raspberry Pi.

-----

![rpi-qmount_Demo](https://user-images.githubusercontent.com/52793789/121796600-26874480-cbcf-11eb-8770-17da7f409dbd.gif)

-----

# Features

- Mount & enable auto-mounting on boot.

- Unmount & remove auto-mounting on boot.

### *Supported File Systems*:

- ext
- exFAT
- NTFS
- FAT16/32

-----

# Guide

## *Mount a Drive*

1. Launch the configuration tool:

        bash rpi-qmount.sh

2. Select `MOUNT` and select your drive from the list.

3. Enter the new path to mount your drive, without quotes.

        /mnt/My Test Drive

- The mount folder will be created if it does not exist.

## *Unmount a Drive*

1. Launch the configuration tool:

        bash rpi-qmount.sh

2. Select `UNMOUNT` and select your drive from the list.

- The mount folder will not be removed.

-----

# *Full Walkthrough*

Below is a walkthrough (no audio) demonstrating the entire mount & unmount process.

https://user-images.githubusercontent.com/52793789/121792123-127b1d00-cba6-11eb-9789-3b82963e6dc1.mp4

## Mount

1. Check all mounted & auto-mounted devices.
2. Mount the drive.
3. Confirm the new mounting & auto-mounting.
4. Reboot to apply the auto-mounting.

## Unmount

1. Unmount the drive.
2. Confirm the mount & auto-mount removal.
3. Remove the old mounting folder.
4. Reboot to apply the removed auto-mounting.

-----

# TODO

- Improve input validation.

- Improve checks to prevent improperly mounting drives.

-----

# Credits

This tool is based on the official [External storage configuration](https://www.raspberrypi.org/documentation/configuration/external-storage.md) Guide.
