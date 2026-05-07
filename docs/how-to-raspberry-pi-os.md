# How to Install Caroline on Raspberry Pi OS

This is the recommended beta setup if you want Caroline on a dedicated screen.

## What You Need

- Raspberry Pi 4 or 5
- 4GB RAM or more
- 32GB or larger microSD card
- Raspberry Pi power supply
- Internet connection
- Another computer to write the microSD card
- Optional: keyboard, mouse, and monitor for first setup

## 1. Install Raspberry Pi OS

1. Download and open Raspberry Pi Imager:
   https://www.raspberrypi.com/software/
2. Choose your Raspberry Pi device.
3. Choose **Raspberry Pi OS Desktop 64-bit**.
4. Choose your microSD card.
5. Open **Edit Settings** or **OS Customisation**.
6. Set:
   - Hostname, for example `caroline-pi`
   - Username and password
   - Wi-Fi details if you are not using Ethernet
   - Locale/timezone
7. Enable **SSH** in the services/settings area.
8. Write the card.
9. Put the card in the Pi and boot it.

Use **Raspberry Pi OS Desktop**, not Lite, if you want the fullscreen kiosk on the Pi screen.

Need more detail on Raspberry Pi Imager?

[How to create a VM, USB installer, or Raspberry Pi SD card](how-to-create-install-media.md)

## 2. Find the Pi Address

On the Pi, open Terminal:

```bash
hostname -I
```

Or check your router's device list for `caroline-pi`.

If you enabled SSH, you can connect from another computer:

```bash
ssh YOUR_USER@PI-IP-ADDRESS
```

Example:

```bash
ssh dave@192.168.1.50
```

## 3. Give the Pi a Stable IP

Before installing Caroline, reserve the Pi's IP address in your router if possible.

Use this guide:

[How to set up SSH and a stable IP](network-prep.md)

## 4. Install Caroline

Open Terminal on the Pi, or SSH into it, then run:

```bash
curl -fsSL https://raw.githubusercontent.com/daveeuson/project-caroline/master/install.sh | bash
```

Recommended answers:

- Local Ollama fallback: **No** for the fastest, most reliable beta setup
- Kiosk mode: **Yes** if this Pi has a dedicated screen
- Telemetry: your choice; it is optional

You can add an OpenRouter API key later in Caroline Settings for faster, better replies.

## 5. Reboot

When the installer finishes:

```bash
sudo reboot
```

If kiosk mode is enabled, Caroline should open fullscreen after reboot.

## 6. Open Caroline from Another Browser

From another computer on the same network:

```text
http://PI-IP-ADDRESS:8080/
```

Example:

```text
http://192.168.1.50:8080/
```

## 7. First Setup in Caroline

Open **Settings** and add only what you need:

- **AI:** OpenRouter API key
- **Connect:** Google Calendar, Spotify, Hue, Discord
- **Widgets:** location, weather, tides, video channels

## Quick Test

Try these:

```text
Can you add test Caroline calendar event at 9pm tonight?
What is on my calendar today?
Add buy milk to my tasks.
Turn off my Hue lights.
```

## Troubleshooting

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

Update Caroline:

```bash
curl -fsSL https://raw.githubusercontent.com/daveeuson/project-caroline/master/install.sh | bash
```
