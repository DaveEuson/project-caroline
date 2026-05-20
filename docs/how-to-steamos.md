# SteamOS / Steam Deck Experimental Install

Project: Caroline can run on Steam Deck without disabling SteamOS read-only mode.
This path is experimental and installs everything under the `deck` user's home directory.

## What This Does

- Downloads a portable Node.js runtime into `~/.local/caroline-node`
- Clones Project: Caroline into `~/project-caroline`
- Installs Caroline runtime files into `~/caroline`
- Installs Node-RED locally under `~/caroline/node-red-runtime`
- Runs Caroline as a user systemd service
- Optionally installs portable Ollama under `~/.local/ollama` and runs it as a user systemd service
- Serves the UI locally at `http://localhost:8080/` and on your private LAN at `http://STEAM_DECK_IP:8080/`
- Keeps browser API access limited to localhost/private-network origins and writes private settings/token files with owner-only permissions
- Asks the same first-run identity/privacy/AI questions as the main installer, adapted for SteamOS

It does **not** install system packages with `pacman`, change SteamOS read-only mode, or configure nginx.

When you choose local AI, the installer can download Ollama's Linux archive into your home directory, start `ollama.service` with `systemctl --user`, and pull the selected model. This is experimental and can take a while because the Ollama runtime archive and first model pull are both large.

## Install

In Steam Deck Desktop Mode, open Konsole and run:

```bash
curl -fsSL https://raw.githubusercontent.com/Project-Caroline/project-caroline/nightly/install-steamos.sh | bash
```

Then open Caroline on the Deck:

```bash
caroline-steamos-open
```

For a fullscreen/kiosk-style launch:

```bash
caroline-steamos-kiosk
```

Or open Firefox and go to:

```text
http://localhost:8080/
```

From another computer on the same private network, use:

```text
http://STEAM_DECK_IP:8080/
```

## Useful Commands

```bash
systemctl --user status caroline
journalctl --user -u caroline -f
systemctl --user restart caroline
systemctl --user stop caroline
```

Ollama, when installed:

```bash
systemctl --user status ollama
journalctl --user -u ollama -f
~/.local/bin/ollama list
~/.local/bin/ollama pull qwen3:1.7b
```

Node-RED editor:

```text
http://localhost:8080/red
```

## View From Another Computer

The experimental SteamOS install listens on your private LAN. If you prefer not to expose Carl directly on the LAN, use an SSH tunnel instead:

```bash
ssh -L 8088:127.0.0.1:8080 deck@STEAM_DECK_IP
```

Then open this on your computer:

```text
http://localhost:8088/
```

The browser origin guard allows local/private Caroline pages and blocks non-private browser origins from calling the Deck's local Node-RED endpoints.

## Current Limits

- Local Ollama on SteamOS is experimental and may be slower than OpenRouter on first replies.
- HTTPS/voice proxy is not configured yet.
- Kiosk mode is a fullscreen browser launcher, not a locked-down appliance mode yet.
- Auto-start before login may require:

```bash
sudo loginctl enable-linger deck
```

- This path is intended for Desktop Mode first. Gaming Mode launch tile support is planned later.
