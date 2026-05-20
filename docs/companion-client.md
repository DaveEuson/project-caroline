# Project: Caroline Companion

The companion app is an optional retro messenger-style desktop client for talking to one or more Project: Caroline hosts on your local network.

![Project: Caroline Companion buddy list](../Screenshots/companion-buddies.png)

Use it when you want Caroline as a desktop chat buddy while the main kiosk keeps running on a Pi, Ubuntu box, Pop!_OS desktop, or Steam Deck. Each saved host appears as a buddy, so you can switch between Caroline, Carl, Catoline, Robot, and future hosts without retyping connection settings.

## Download

Latest companion release:

https://github.com/Project-Caroline/project-caroline/releases/tag/companion-v0.1.9

Choose the package for your platform:

| Platform | File |
|---|---|
| Windows | `Windows_Project.Caroline.Companion_0.1.9_x64_en-US.msi` |
| Ubuntu / Pop!_OS | `Linux_Project.Caroline.Companion_0.1.9_amd64.deb` |
| Steam Deck Desktop Mode | `Linux_Project.Caroline.Companion_0.1.9_amd64.AppImage` |
| macOS Apple Silicon | `MacAppleSilicon_Project.Caroline.Companion_0.1.9_aarch64.dmg` |
| macOS Intel | `MacIntel_Project.Caroline.Companion_0.1.9_x64.dmg` |

## Connect

On the Project: Caroline kiosk, copy the `SYNC:` code from the top bar.

In the companion app:

1. Pick the saved bot profile, such as **Caroline**, **Carl**, **Catoline**, or **Robot**.
2. Set that profile's WebSocket URL to `ws://YOUR-CAROLINE-IP:8080/ws/caroline`.
3. Enter your companion display name.
4. Paste that kiosk's `SYNC:` code.
5. Click **Connect**.

Each saved host keeps its own WebSocket URL and pairing code, so one companion app can switch between multiple Project: Caroline hosts. The buddy list also tracks per-host transcripts, unread messages, and connection status.

Chat history is saved locally on the computer running the companion app. Use **Settings > Delete All Chats** to wipe saved companion transcripts and unread counts from that computer.

## Ubuntu / Pop!_OS Notes

Install the `.deb` package from the release page. If your desktop blocks the first launch, open the app from the application menu after install or run it once from a terminal to see missing dependency messages.

## Steam Deck Notes

Use Desktop Mode and launch the `.AppImage` release asset. SteamOS does not include Debian package tools by default, so the `.deb` package is for Ubuntu/Pop!_OS rather than the Deck.

SteamOS Caroline binds to localhost by default. To use the **Carl / Steam Deck** saved profile from another computer, start an SSH tunnel first:

```bash
ssh -L 8088:127.0.0.1:8080 deck@STEAM_DECK_IP
```

Then use this companion URL for Carl:

```text
ws://127.0.0.1:8088/ws/caroline
```

## Smoke Test

After pairing, send a short message from the companion and confirm it appears on the kiosk. Then send a kiosk message and confirm the companion transcript updates.
