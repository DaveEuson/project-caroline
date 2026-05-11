# SteamOS / Steam Deck Experimental Install

Project: Caroline can run on Steam Deck without disabling SteamOS read-only mode.
This path is experimental and installs everything under the `deck` user's home directory.

## What This Does

- Downloads a portable Node.js runtime into `~/.local/caroline-node`
- Clones Project: Caroline into `~/project-caroline`
- Installs Caroline runtime files into `~/caroline`
- Installs Node-RED locally under `~/caroline/node-red-runtime`
- Runs Caroline as a user systemd service
- Serves the UI locally at `http://localhost:8080/`

It does **not** install system packages with `pacman`, change SteamOS read-only mode, configure nginx, or install Ollama.

## Install

In Steam Deck Desktop Mode, open Konsole and run:

```bash
curl -fsSL https://raw.githubusercontent.com/Project-Caroline/project-caroline/nightly/install-steamos.sh | bash
```

Then open Caroline on the Deck:

```bash
caroline-steamos-open
```

Or open Firefox and go to:

```text
http://localhost:8080/
```

## Useful Commands

```bash
systemctl --user status caroline
journalctl --user -u caroline -f
systemctl --user restart caroline
systemctl --user stop caroline
```

Node-RED editor:

```text
http://localhost:8080/red
```

## View From Another Computer

The experimental SteamOS install binds to localhost for safety. To view it from another computer, create an SSH tunnel:

```bash
ssh -L 8088:127.0.0.1:8080 deck@STEAM_DECK_IP
```

Then open this on your computer:

```text
http://localhost:8088/
```

## Current Limits

- Local Ollama is not installed by this experimental path yet.
- HTTPS/voice proxy is not configured yet.
- Auto-start before login may require:

```bash
sudo loginctl enable-linger deck
```

- This path is intended for Desktop Mode first. Gaming Mode launch tile support is planned later.
