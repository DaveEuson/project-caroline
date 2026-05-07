# How to Create a VM, USB Installer, or Raspberry Pi SD Card

Use this guide before the Caroline installer if you still need to create the computer Caroline will run on.

## Best Option by Setup

| Setup | Use |
|---|---|
| Raspberry Pi | Raspberry Pi Imager |
| Ubuntu Server in Windows | Hyper-V, VirtualBox, VMware, or Proxmox |
| Ubuntu Server on a real PC | Rufus, balenaEtcher, or another USB imaging tool |
| Ubuntu Desktop on a real PC | Rufus, balenaEtcher, or another USB imaging tool |

## Raspberry Pi SD Card

Use the official Raspberry Pi Imager:

https://www.raspberrypi.com/software/

Basic flow:

1. Insert the microSD card into your computer.
2. Open Raspberry Pi Imager.
3. Choose **Raspberry Pi OS Desktop 64-bit**.
4. Choose your SD card.
5. Open **OS Customisation** or **Edit Settings**.
6. Set hostname, username, password, Wi-Fi, timezone, and SSH.
7. Write the card.
8. Put the card in the Pi and boot it.

Official Raspberry Pi getting-started docs:

https://www.raspberrypi.com/documentation/installation/

## Hyper-V VM on Windows

Hyper-V is a good way to test Ubuntu Server on a Windows PC.

Official Microsoft Hyper-V VM guide:

https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/get-started/create-a-virtual-machine-in-hyper-v

Recommended Caroline VM settings:

- Generation: **Generation 2**
- Startup memory: **4096MB minimum**, **8192MB preferred**
- Dynamic Memory: okay, but set the minimum to **4096MB** or disable Dynamic Memory during install
- Processors: **2 or more**
- Disk: **40GB or more**
- Network: **Default Switch** is okay for testing; an external switch is better if you want a stable LAN address
- ISO: attach the Ubuntu Server ISO

Basic flow:

1. Open **Hyper-V Manager**.
2. Choose **New > Virtual Machine**.
3. Pick **Generation 2**.
4. Assign memory. Use at least 4096MB.
5. Connect the VM to a virtual switch.
6. Create a virtual hard disk, 40GB or larger.
7. Attach the Ubuntu Server ISO.
8. Start the VM and install Ubuntu Server.
9. During Ubuntu setup, enable **OpenSSH Server**.

If the VM will not boot the ISO, open VM settings and try disabling Secure Boot.

If the Caroline installer says `Killed` during package installation, the VM ran out of usable memory or swap. Raise the Hyper-V Dynamic Memory minimum or disable Dynamic Memory, then rerun the installer.

## VirtualBox, VMware, or Proxmox

These work too. Caroline does not care which VM host you use.

Use similar settings:

- 64-bit Ubuntu Server
- 2 CPU cores or more
- 4GB RAM minimum, 8GB preferred
- 40GB disk or larger
- Bridged networking if you want the VM to have a normal LAN IP
- NAT networking is fine for testing, but browser access from another device can be trickier

When Ubuntu asks about SSH, enable **OpenSSH Server**.

## Ubuntu USB Installer

For a real PC, write the Ubuntu ISO to a USB drive.

Official Ubuntu Server install docs:

https://ubuntu.com/server/docs/tutorial/basic-installation

Good imaging tools:

- Raspberry Pi Imager: https://www.raspberrypi.com/software/
- Rufus for Windows: https://rufus.ie/
- balenaEtcher for Windows, macOS, and Linux: https://etcher.balena.io/

Basic flow:

1. Download the Ubuntu Server or Ubuntu Desktop ISO.
2. Insert an empty USB drive.
3. Open your imaging tool.
4. Select the Ubuntu ISO.
5. Select the USB drive.
6. Write/flash the USB drive.
7. Boot the target computer from the USB drive.
8. Install Ubuntu.

Warning: imaging tools erase the USB drive or SD card you select. Double-check the target drive before clicking write or flash.

## Video Help

Videos go stale quickly, so Caroline's docs link official written guides first. If you want a video, search YouTube for one of these exact phrases:

```text
install ubuntu server hyper-v windows
install ubuntu server from usb
raspberry pi imager enable ssh
```

Prefer recent videos from Microsoft, Ubuntu, Raspberry Pi, or well-known Linux educators.
