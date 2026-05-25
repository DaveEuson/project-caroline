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
- Serves the UI locally at `http://localhost:8080/`
- Uses the Steam Deck readable display preset by default: Noto Sans, larger text, and comfortable spacing
- Keeps browser API access limited to localhost/private-network origins and writes private settings/token files with owner-only permissions
- Asks the same first-run identity/privacy/AI questions as the main installer, adapted for SteamOS

It does **not** install system packages with `pacman`, change SteamOS read-only mode, or configure nginx.

When you choose local AI, the installer can download Ollama's Linux archive into your home directory, start `ollama.service` with `systemctl --user`, and pull the selected model. This is experimental and can take a while because the Ollama runtime archive and first model pull are both large.

## Install

In Steam Deck Desktop Mode, open Konsole and run:

```bash
curl -fsSL https://raw.githubusercontent.com/Project-Caroline/project-caroline/nightly/install-steamos.sh | tr -d '\r' | bash -s --
```

Then open Caroline on the Deck:

```bash
caroline-steamos-open
```

For a fullscreen/kiosk-style launch:

```bash
caroline-steamos-kiosk
```

To leave kiosk mode, open **Settings -> System** in Caroline and use **Exit Kiosk**. On SteamOS this closes the local fullscreen browser process; it is not just a normal browser fullscreen toggle.

Or open Firefox and go to:

```text
http://localhost:8080/
```

If the Deck is across the room, open `Settings` -> `Look & Feel` -> `Display preset` and choose `Steam Deck - 3 ft`, `Couch / small TV`, or `Wall kiosk`.

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

## Local Model Notes

The current Steam Deck recommendation is `qwen3:1.7b`. A direct Ollama benchmark across Qwen, Llama, Gemma, Phi, DeepSeek, Mistral, SmolLM2, and TinyLlama kept `qwen3:1.7b` as the best balance: coherent enough for Caroline behavior while still averaging around a few seconds per reply on the Deck.

Good non-Qwen experiments:

- `mistral:7b` scored well but is slow enough to feel heavy.
- `gemma3:4b` and `phi4-mini` are reasonable quality fallbacks.
- `smollm2:1.7b` is a lightweight fallback when speed matters.
- `deepseek-r1` was not a good fit for Caroline-style short conversational replies in this test.

The SteamOS beta install disables the Node-RED editor route by default.

## View From Another Computer

The experimental SteamOS install binds Caroline to localhost by default. To view it from another computer on your private network, use an SSH tunnel:

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
