# Project: Caroline Companion

The companion app is an optional retro messenger-style desktop client for talking to a Project: Caroline host on your local network.

## Download

Latest companion release:

https://github.com/Project-Caroline/project-caroline/releases/tag/companion-v0.1.8

Choose the package for your platform:

| Platform | File |
|---|---|
| Windows | `.msi` |
| Ubuntu / Pop!_OS | `.deb` |
| Steam Deck Desktop Mode | `.AppImage` |
| macOS Apple Silicon | `aarch64.dmg` |
| macOS Intel | `x86_64.dmg` |

## Connect

On the Project: Caroline kiosk, copy the `SYNC:` code from the top bar.

In the companion app:

1. Set the WebSocket URL to `ws://YOUR-CAROLINE-IP:8080/ws/caroline`.
2. Enter your companion display name.
3. Paste the kiosk `SYNC:` code.
4. Click **Connect**.

Each saved host keeps its own WebSocket URL and pairing code, so one companion app can switch between multiple Project: Caroline hosts.

## Ubuntu / Pop!_OS Notes

Install the `.deb` package from the release page. If your desktop blocks the first launch, open the app from the application menu after install or run it once from a terminal to see missing dependency messages.

## Steam Deck Notes

Use Desktop Mode and launch the `.AppImage` release asset. SteamOS does not include Debian package tools by default, so the `.deb` package is for Ubuntu/Pop!_OS rather than the Deck.

## Smoke Test

After pairing, send a short message from the companion and confirm it appears on the kiosk. Then send a kiosk message and confirm the companion transcript updates.
