# ***rpi-qmount***

> A quick drive mounting utility for Raspberry Pi.

-----

https://user-images.githubusercontent.com/52793789/121792123-127b1d00-cba6-11eb-9789-3b82963e6dc1.mp4

-----

# Supported Drive Types:

- ext

- exFAT

- NTFS

- FAT16/32

-----

# Features:

- Mount & enable auto-mounting on boot.

- Unmount & remove auto-mounting on boot.

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

# TODO

- Improve input validation.

- Improve checks to prevent improperly mounting drives.

-----

# Credits

This tool is based on the official [External storage configuration](https://www.raspberrypi.org/documentation/configuration/external-storage.md) Guide.
