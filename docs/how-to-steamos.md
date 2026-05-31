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

## Easiest Install: Downloadable Launcher

Use this path if you are comfortable using the Steam Deck desktop but do not want to type commands in Konsole.

1. Hold the power button and choose **Switch to Desktop**.
2. Open Firefox and go to the Project: Caroline GitHub page.
3. Download [`Project-Caroline-SteamDeck-Installer.desktop`](../Project-Caroline-SteamDeck-Installer.desktop).
4. Open **Downloads** in Dolphin.
5. If SteamOS asks whether the file can run, choose **Allow Launching** or open **Properties -> Permissions** and enable **Is executable**.
6. Double-click **Project Caroline Steam Deck Installer**.
7. A terminal window opens automatically and runs the guided installer.

This launcher uses the public `release` channel. It does not disable SteamOS read-only mode, install system packages with `pacman`, or ask you to paste commands.

After install, Caroline creates two Desktop Mode launchers:

- **Project: Caroline** opens the normal windowed dashboard.
- **Project: Caroline Kiosk** opens the fullscreen couch/kiosk view.

To add Caroline to Gaming Mode, open Steam in Desktop Mode, choose **Games -> Add a Non-Steam Game to My Library**, and select **Project: Caroline Kiosk**.

## Console Install

In Steam Deck Desktop Mode, open Konsole and run:

```bash
curl -fsSL https://raw.githubusercontent.com/Project-Caroline/project-caroline/release/install-steamos.sh | tr -d '\r' | CAROLINE_CHANNEL=release bash -s --
```

For nightly testing, replace `release` with `nightly`.

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

On Bazzite NVIDIA laptops with RTX 2070-class GPUs and 8GB VRAM, the current recommendation is `mistral:7b`. It scored 10/10 in the Caroline conversational sweep, averaged under a second for warm replies, and stayed 100% GPU-resident on the RTX 2070 Max-Q. Use `qwen3:1.7b` as the fast fallback. `gemma4:e4b` also scored 10/10, but it spills across CPU/GPU on 8GB VRAM.

Good non-Qwen experiments:

- `mistral:7b` scored well on Steam Deck but is slow enough to feel heavy there.
- `gemma3:4b` and `phi4-mini` are reasonable quality fallbacks.
- `smollm2:1.7b` is a lightweight fallback when speed matters.
- `deepseek-r1` was not a good fit for Caroline-style short conversational replies in this test.

For the cross-platform model table, see [Local AI model recommendations](local-ai-models.md).

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

- Local Ollama on SteamOS is experimental and may be slower than OpenRouter with Gemini 2.5 Flash Lite on first replies.
- HTTPS/voice proxy is not configured yet.
- Kiosk mode is a fullscreen browser launcher, not a locked-down appliance mode yet.
- Auto-start before login may require:

```bash
sudo loginctl enable-linger deck
```

- This path is intended for Desktop Mode first. Gaming Mode launch tile support is planned later.
