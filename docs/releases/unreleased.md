# Project: Caroline Unreleased

Draft notes for the next public beta. Move these into a versioned release note file when the release is tagged.

## Added

- Added a downloadable Steam Deck installer launcher so Desktop Mode users can start the guided SteamOS install without typing Konsole commands.
- Added `caroline-deck-installer/`, a Tauri-based Steam Deck installer and maintenance GUI for install, update, repair, uninstall, and launch actions.
- Added a Steam Hub kiosk widget with Library/Downloads shortcuts, custom `steam://run/<appid>` game launch tiles, local recent-launch history, and host-side recently played sync.
- Added local Steam account detection and installed-game import for Steam Deck hosts, so Steam Hub can work without asking most users for a Steam Web API key.
- Added Steam library awareness to chat prompts and direct replies, so the assistant can answer from imported Steam Hub games instead of guessing.
- Added active widget context snapshots to chat prompts, so the assistant can answer from the visible dashboard state for weather, calendar, music, Pomodoro, Steam, tasks, and other enabled widgets.
- Added an always-visible Signal widget for IP, internet, CPU/RAM, and active AI model status.
- Added a Steam Hub topbar dropdown that appears only when the Steam widget is enabled and focuses on Steam account, installed games, recent activity, last played/imported title, Library, Downloads, Store, Friends, Detect, and Import actions.
- Added richer Steam Deck Hub status from local Steam metadata: player name, installed count, recent play, last Caroline launch, and visible download/update progress when Steam exposes it on disk.
- Added an Exit Kiosk button beside Settings so fullscreen users have an obvious way out.
- Added controller navigation for kiosk controls using the browser Gamepad API, with a Settings -> Look & Feel toggle.
- Added Steam Deck install docs for the no-typing launcher, Desktop Mode shortcuts, and adding Caroline Kiosk to Gaming Mode as a non-Steam game.

## Changed

- Steam Deck docs now point public beta users at the `release` SteamOS installer by default, with `nightly` reserved for testing.
- SteamOS installer completion output now calls out the created desktop launchers and Gaming Mode add path.
- Steam Hub setup now treats the Steam Web API key as an advanced optional path for cloud recent-play sync rather than a required first-run step.
- Host signal data now lives in the left rail instead of crowding the topbar or hiding inside Steam-only controls.
- Removed the duplicate Steam right-rail panel; Steam Hub now lives in the top dropdown when enabled.
- Steam Hub labels now separate recent Steam play from Caroline launch history, avoiding confusing text like a vague "1 recent" counter or treating an imported game as the last launch.
- Settings now shows connection setup only for enabled widgets, keeping Steam, Hue, Spotify, and Google setup out of the way until the matching widget is on.
- Avatar art and assistant personality style are now separate, so users can pair any visual avatar with any tone.
- Removed the unfinished placeholder avatar from active kiosk avatar and personality choices; old saved selections now fall back to the default avatar safely.

## Fixed

- Controller navigation now handles settings dropdowns more cleanly on Steam Deck instead of stealing selection input.
- Malformed local-model action markers such as orphan `[ACTION]` tags are now stripped from visible replies.

## Known Issues

- None yet.
