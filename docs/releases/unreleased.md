# Project: Caroline Unreleased

Draft notes for the next public beta. Move these into a versioned release note file when the release is tagged.

## Added

- Added a downloadable Steam Deck installer launcher so Desktop Mode users can start the guided SteamOS install without typing Konsole commands.
- Added `caroline-deck-installer/`, a Tauri-based Steam Deck installer and maintenance GUI for install, update, repair, uninstall, and launch actions.
- Added a Steam Hub kiosk widget with Library/Downloads shortcuts, custom `steam://run/<appid>` game launch tiles, local recent-launch history, and host-side recently played sync.
- Added controller navigation for kiosk controls using the browser Gamepad API, with a Settings -> Look & Feel toggle.
- Added Steam Deck install docs for the no-typing launcher, Desktop Mode shortcuts, and adding Caroline Kiosk to Gaming Mode as a non-Steam game.

## Changed

- Steam Deck docs now point public beta users at the `release` SteamOS installer by default, with `nightly` reserved for testing.
- SteamOS installer completion output now calls out the created desktop launchers and Gaming Mode add path.

## Fixed

- None yet.

## Removed

- None yet.

## Known Issues

- None yet.
