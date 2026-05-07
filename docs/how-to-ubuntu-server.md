# How to Install Caroline on Ubuntu Server

This is the recommended non-Pi setup. Caroline runs on the server, and you open the dashboard from another browser on your network.

## What You Need

- A PC, mini PC, VM, or server
- Ubuntu Server 64-bit
- 4GB RAM minimum; 6-8GB is better
- Internet during install
- Another computer or browser to open Caroline

If you are using Hyper-V, give the VM 4GB or more as the startup memory. If Dynamic Memory is enabled, set the minimum high enough that Ubuntu is not squeezed during installs, for example 4096MB.

## 1. Install Ubuntu Server

1. Download Ubuntu Server:
   https://ubuntu.com/download/server
2. Write the ISO to a USB drive.
   - On Windows, Raspberry Pi Imager, Rufus, or Balena Etcher can write the USB.
   - On macOS or Linux, Balena Etcher works well.
3. Boot the target computer from the USB drive.
4. Follow the installer.
5. Create a username and password.
6. When asked about SSH, install or enable **OpenSSH Server**.
7. Finish the install and reboot.

You do not need a desktop environment for Caroline server/client mode.

Need help creating a Hyper-V VM or writing the Ubuntu ISO to USB?

[How to create a VM, USB installer, or Raspberry Pi SD card](how-to-create-install-media.md)

## 2. Log In

After reboot, log in on the server console.

Find the server IP:

```bash
hostname -I
```

From another computer, connect with SSH:

```bash
ssh YOUR_USER@SERVER-IP
```

Example:

```bash
ssh dave@192.168.1.60
```

If SSH was not installed:

```bash
sudo apt-get update
sudo apt-get install -y openssh-server
sudo systemctl enable --now ssh
```

## 3. Give the Server a Stable IP

Reserve the server's IP address in your router if possible.

Use this guide:

[How to set up SSH and a stable IP](network-prep.md)

## 4. Install Caroline

Run:

```bash
curl -fsSL https://raw.githubusercontent.com/daveeuson/project-caroline/master/install.sh | bash
```

Recommended answers:

- Local Ollama fallback: **No** unless the machine has enough RAM/CPU
- Kiosk mode: **No**
- Telemetry: your choice; it is optional

Ubuntu Server should be used from another browser, not from a local kiosk browser.

## 5. Open Caroline

At the end, the installer prints a browser URL.

From another computer on the same network, open:

```text
http://SERVER-IP:8080/
```

Example:

```text
http://192.168.1.60:8080/
```

Node-RED is available at:

```text
http://SERVER-IP:1880/
```

You normally do not need Node-RED unless you are debugging or customizing flows.

## 6. First Setup in Caroline

Open **Settings**:

- **AI:** add OpenRouter API key
- **Connect:** add Google, Spotify, Hue, or Discord if needed
- **Widgets:** set location, timezone, weather, and video channels

## Quick Test

Try:

```text
Can you add dentist tomorrow at 2pm?
What is on my calendar today?
Add buy milk to my tasks.
Turn off my Hue lights.
```

## Troubleshooting

Check Caroline:

```bash
sudo systemctl status caroline
```

Restart:

```bash
sudo systemctl restart caroline
```

Logs:

```bash
journalctl -u caroline -n 120 --no-pager
```

If the browser cannot connect:

```bash
hostname -I
sudo systemctl status nginx
sudo systemctl status caroline
```

Make sure you are using the server's LAN IP, not `127.0.0.1`, from another computer.

If the installer says `Killed` during `apt-get install`, the VM probably ran out of usable memory or swap during package setup. Increase the VM memory, disable very-low Dynamic Memory minimums, then rerun the installer.

If `/tmp/caroline-node-apt.log` says `nodejs : Conflicts: npm`, rerun the installer from the latest `master`. NodeSource bundles npm inside its `nodejs` package, so older installers that ask apt for both packages can confuse Ubuntu's dependency solver.
