# How to Install Caroline on Ubuntu Desktop

Ubuntu Desktop works, but it is less tested than Raspberry Pi OS and Ubuntu Server. For beta, use Ubuntu Desktop when you want to test Caroline on a normal Linux desktop or VM.

For the most reliable Ubuntu setup, use [Ubuntu Server](how-to-ubuntu-server.md) and open Caroline from another browser.

## What You Need

- A PC, mini PC, VM, or laptop
- Ubuntu Desktop 64-bit
- 4GB RAM minimum; 6-8GB is better
- Internet during install

## 1. Install Ubuntu Desktop

1. Download Ubuntu Desktop:
   https://ubuntu.com/download/desktop
2. Write the ISO to a USB drive.
   - On Windows, use Rufus, Balena Etcher, or Raspberry Pi Imager.
   - On macOS or Linux, Balena Etcher works well.
3. Boot the computer from the USB drive.
4. Choose **Install Ubuntu**.
5. Create a username and password.
6. Finish install and reboot.

Need help creating the USB installer or VM first?

[How to create a VM, USB installer, or Raspberry Pi SD card](how-to-create-install-media.md)

## 2. Open Terminal

Press:

```text
Ctrl + Alt + T
```

Update the package list:

```bash
sudo apt-get update
```

## 3. Optional: Enable SSH

SSH is helpful if the machine is attached to a screen or is hard to reach.

```bash
sudo apt-get install -y openssh-server
sudo systemctl enable --now ssh
hostname -I
```

Then connect from another computer:

```bash
ssh YOUR_USER@UBUNTU-IP
```

## 4. Give the Machine a Stable IP

Use your router's DHCP reservation if possible.

Guide:

[How to set up SSH and a stable IP](network-prep.md)

## 5. Install Caroline

Run:

```bash
curl -fsSL https://raw.githubusercontent.com/daveeuson/project-caroline/master/install.sh | bash
```

Recommended answers:

- Local Ollama fallback: **No** unless your computer has enough RAM/CPU
- Kiosk mode: **No** for testing
- Kiosk mode: **Yes** only if this is a dedicated display machine

If kiosk or XRDP behaves strangely on Ubuntu Desktop, use server/client mode instead:

```text
http://UBUNTU-IP:8080/
```

Open that from another browser on your network.

## 6. Open Caroline Locally

On the Ubuntu Desktop machine:

```text
http://localhost:8080/
```

From another computer:

```text
http://UBUNTU-IP:8080/
```

For microphone input or activation-word mode from another computer, use Chrome or Chromium and open:

```text
https://UBUNTU-IP:8444/
```

Accept the local certificate warning once. The normal HTTP URL still works for typing/chat.

## 7. First Setup in Caroline

Open **Settings**:

- **AI:** add OpenRouter API key
- **Connect:** add Google Calendar, Spotify, Hue, or Discord if needed
- **Widgets:** set location, timezone, weather, tides, and video channels

## Quick Test

Try:

```text
Can you add test Caroline event at 9pm tonight?
What is on my calendar today?
Add buy milk to my tasks.
Turn off my Hue lights.
```

## Troubleshooting

Check services:

```bash
sudo systemctl status caroline
sudo systemctl status nginx
```

Restart Caroline:

```bash
sudo systemctl restart caroline
```

Logs:

```bash
journalctl -u caroline -n 120 --no-pager
```

If local kiosk mode is weird, disable kiosk expectations and use another browser pointed at:

```text
http://UBUNTU-IP:8080/
```
