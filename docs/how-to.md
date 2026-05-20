# Caroline How-To Guides

Start here if you are new to Raspberry Pi, Ubuntu, SSH, or home-server setup.

## Choose Your Install

| I have... | Use this guide |
|---|---|
| A Raspberry Pi with a screen | [How to install Caroline on Raspberry Pi OS](how-to-raspberry-pi-os.md) |
| A spare PC, mini PC, VM, or server | [How to install Caroline on Ubuntu Server](how-to-ubuntu-server.md) |
| A normal Ubuntu desktop computer | [How to install Caroline on Ubuntu Desktop](how-to-ubuntu-desktop.md) |
| A Steam Deck in Desktop Mode | [Experimental Steam Deck / SteamOS install](how-to-steamos.md) |
| A Windows, Ubuntu/Pop!_OS, or Steam Deck desktop client | [How to install the Companion app](companion-client.md) |

## Before You Install

Do these first if you can:

1. Make sure the device is on your home network.
2. Enable SSH so you can reach the device from another computer.
3. Give the device a stable IP address or router reservation.

Need help creating the VM, USB installer, or Raspberry Pi SD card first?

[How to create a VM, USB installer, or Raspberry Pi SD card](how-to-create-install-media.md)

Guide:

[How to set up SSH and a stable IP](network-prep.md)

## After You Install

Open Caroline from a browser:

```text
http://DEVICE-IP:8080/
```

For microphone input or activation word from another computer, use Chrome or Chromium and open:

```text
https://DEVICE-IP:8444/
```

Accept the local certificate warning once. The normal HTTP URL remains best for typing/chat.

Then open **Settings** and add only what you need:

- **AI:** OpenRouter API key for the best experience, or local Ollama with the installer-recommended model for your hardware
- **Connect:** Google Calendar, Spotify, Hue, or Discord
- **Widgets:** location, weather, tides, and video channels

## Quick Test Lines

Try these after setup:

```text
What is on my calendar today?
Can you add test Caroline calendar event at 9pm tonight?
Add buy milk to my tasks.
Turn off my Hue lights.
```

## If Something Breaks

Check Caroline:

```bash
sudo systemctl status caroline
```

Restart Caroline:

```bash
sudo systemctl restart caroline
```

View recent logs:

```bash
journalctl -u caroline -n 120 --no-pager
```

## Operations Guides

- [Architecture overview](architecture.md)
- [Backup and restore](backup-restore.md)
- [Release process](release.md)
- [Release notes](releases/README.md)
