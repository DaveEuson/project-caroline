# Project: Caroline Deck Installer

Small Tauri installer and maintenance app for Steam Deck / SteamOS hosts.

## What it does

- Installs Project: Caroline using the SteamOS home-directory installer.
- Updates or repairs an existing SteamOS install.
- Removes Caroline launchers and services, with an option to keep user data.
- Opens the windowed or kiosk launchers after install.

The command layer uses fixed actions only. It does not expose a free-form shell input.

## Development

```bash
npm install
npm run build
npm run tauri:dev
```

## Packaging

Build the Steam Deck AppImage on a Linux or SteamOS runner:

```bash
npm run tauri:build
```

The Windows development host can validate the React build and Rust code, but AppImage packaging should happen on Linux.
