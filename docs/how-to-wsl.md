# How to install Caroline in WSL on Windows

This is a beta/test path for Windows users who want Caroline's Linux server running in Ubuntu WSL while the browser, kiosk view, and Companion app run on Windows.

## Best Use

- Caroline backend: Ubuntu WSL
- Main view: Windows browser at `http://localhost:8080/`
- Kiosk view: Windows Edge or Chrome fullscreen
- Companion app: Windows `.msi`
- Local AI: OpenRouter with Gemini 2.5 Flash Lite for the easiest path, or Ollama installed inside Ubuntu WSL

WSL is not the same as a dedicated Raspberry Pi kiosk. It is best for development, smoke testing, and a Windows laptop/desktop that already has WSL installed.

## Install

In Ubuntu WSL:

```bash
sudo apt-get update && sudo apt-get install -y bash curl ca-certificates
curl -fsSL https://raw.githubusercontent.com/Project-Caroline/project-caroline/nightly/install.sh | tr -d '\r' | bash -s -- --nightly
```

When asked about kiosk mode, the installer automatically keeps WSL in server/client mode because the visible desktop belongs to Windows.

For local AI, choose the Ollama option during install if you want private on-device replies. The WSL path installs Linux Ollama inside Ubuntu WSL and keeps Caroline pointed at:

```text
http://localhost:11434
```

That avoids the extra Windows firewall and WSL bridge setup needed to share Ollama for Windows.

## Windows Desktop Icons

After install, Caroline creates a **Project Caroline** folder on your Windows desktop and adds shortcuts:

| Shortcut | What it does |
|---|---|
| Project Caroline - Start Server | Opens a branded status console, starts `nginx` and `caroline.service` inside WSL, shows the browser link, and can reset the local browser login password |
| Project Caroline - Open | Starts the WSL services, then opens `http://localhost:8080/` |
| Project Caroline - Kiosk | Starts the WSL services, then opens Edge or Chrome in kiosk mode |
| Project Caroline - Install Companion | Downloads and runs the Windows Companion app installer |

The shortcuts keep the WSL distro awake while Caroline is running. To stop everything from Windows, run:

```powershell
wsl.exe --shutdown
```

If shortcuts do not appear, run this from WSL:

```bash
~/.local/bin/caroline-wsl-start
```

Then open this in Windows:

```text
http://localhost:8080/
```

## Companion App

The WSL installer includes a Windows-side **Install Companion** launcher. You can also download it manually:

https://github.com/Project-Caroline/project-caroline/releases/tag/companion-v0.1.13

Use this Companion WebSocket URL for a local WSL host:

```text
ws://127.0.0.1:8080/ws/caroline
```

## Notes

- If WSL services do not start, make sure systemd is enabled in WSL.
- If `http://localhost:8080/` does not answer from Windows, run `wsl.exe --shutdown`, reopen Ubuntu, and start Caroline again.
- Phone access to a WSL host may need Windows firewall and port forwarding. A Pi, Ubuntu server, or Steam Deck is usually cleaner for LAN testing.
- If Settings says the browser can see Ollama but the Caroline host cannot, install/start Ollama inside WSL or set the Ollama URL back to `http://localhost:11434`.
