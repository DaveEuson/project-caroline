# Project: Caroline

Your personal AI sidekick kiosk for home dashboards, reminders, calendar help, music, lights, local tasks, and a little cyberpunk companionship.

![Project: Caroline avatar](assets/caroline.gif)
![Project: Caroline interface](Screenshot_7.png)

## Install

Run this on Raspberry Pi OS or Ubuntu:

```bash
curl -fsSL https://raw.githubusercontent.com/daveeuson/project-caroline/master/install.sh | bash
```

Caroline installs Node.js, Node-RED, nginx, the web UI, optional local AI, and the system service.

For microphone input from another browser, use Chrome or Chromium with the secure voice URL printed by the installer:

```text
https://YOUR-CAROLINE-IP:8444/
```

On a Raspberry Pi kiosk, the installer prefers Chromium because Firefox does not support Caroline's browser wake-word input.

The normal `http://YOUR-CAROLINE-IP:8080/` URL still works for typing/chat.

## Pick Your Setup

| Platform | Status | Best For |
|---|---|---|
| Raspberry Pi OS Desktop 64-bit | Primary beta | Dedicated kiosk screen |
| Ubuntu Server 64-bit | Supported | Server/client mode from another browser |
| Ubuntu Desktop 64-bit | Works, less tested | Desktop testing or local browser use |
| WSL Ubuntu | Dev/test only | Windows-side browser testing |

## Beta Kits

DIY install is the main path for now. I am also considering a small run of ready-to-go Project Caroline Raspberry Pi kits for people who want a turnkey setup. If that would be useful to you, reach out so I can gauge demand.

## Beginner Guides

- [Start here: choose the right install guide](docs/how-to.md)
- [How to create a VM, USB installer, or Raspberry Pi SD card](docs/how-to-create-install-media.md)
- [How to install on Raspberry Pi OS](docs/how-to-raspberry-pi-os.md)
- [How to install on Ubuntu Server](docs/how-to-ubuntu-server.md)
- [How to install on Ubuntu Desktop](docs/how-to-ubuntu-desktop.md)
- [How to set up SSH and a stable IP](docs/network-prep.md)
- [How to set up Google Calendar OAuth](docs/google-oauth.md)
- [Clean uninstall/reinstall QA checklist](docs/clean-reinstall-qa.md)

## Requirements

- 64-bit Raspberry Pi OS or Ubuntu
- 4GB RAM minimum; 6-8GB is better for local AI
- Internet during install
- A stable local IP address is strongly recommended
- Do not expose Caroline directly to the public internet

## What Caroline Can Do

- Chat with local Ollama or cloud models through OpenRouter
- Add, read, and delete Google Calendar events
- Manage local tasks
- Control Philips Hue lights
- Show weather, news, video, tides, radio, Pomodoro, memory, and system widgets
- Run as a fullscreen kiosk or as a server opened from another browser

## Optional Integrations

Add these later in **Settings**:

- OpenRouter API key for fast cloud AI
- Google Calendar OAuth
- Spotify client ID
- Philips Hue bridge/key
- Discord bot token and channel ID
- NOAA tide station

## Update

Use **Settings > About > Update**, or rerun:

```bash
curl -fsSL https://raw.githubusercontent.com/daveeuson/project-caroline/master/install.sh | bash
```

Settings, API keys, tasks, and memory are preserved.

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/daveeuson/project-caroline/master/uninstall.sh | sudo bash
```

## Safety

Caroline is designed for your local network. Keep ports `8080`, `1880`, `8443`, `8444`, and SSH private unless you are using a VPN such as Tailscale or WireGuard.

## Support

Caroline is free to use. If you enjoy it and want to support future builds:

https://buymeacoffee.com/daveeuson
