# Project: Caroline Unreleased

Draft notes for the next public beta. Move these into a versioned release note file when the release is tagged.

## Added

- Added avatar-based default personalities for Caroline, Carl, Catoline, Robot, and Frog Pilot.
- Added first-launch and boot-splash copy that explains each avatar's default style.
- Added Robot awake/sleeping avatar art and a coming-soon placeholder for Frog Pilot.
- Added default companion bot profiles for Caroline on Pi, Carl on Steam Deck, and Catoline on Pop!_OS.
- Added live multi-host buddy switching in the companion app, with per-buddy transcripts, status, and unread message badges.
- Added local companion chat history with a privacy control to delete all saved chats.
- Added companion buddy cleanup so unpaired placeholder hosts no longer appear in the buddy list.
- Added per-host device type labels for companion buddies, covering Pi, Steam, Ubuntu, Mac, and Windows hosts.
- Added Hide/Show controls for memory shards so sensitive shard text can be concealed without deleting it.
- Added a SteamOS user-space update helper so Steam Deck builds can update without relying on `/usr/local/sbin`.
- Added architecture and backup/restore docs.
- Added a practical release checklist with device QA, smoke tests, and rollback notes.

## Changed

- Reduced the avatar roster to the named Project: Caroline characters instead of generic avatar choices.
- Expanded the README and companion guide to explain Caroline as a host/kiosk that can be reached from LAN browsers or the desktop companion app.
- Bumped the companion app version and download links to `0.1.9`.
- Updated companion release artifact names so installers clearly identify Windows, Linux, Steam Deck, Mac Intel, and Mac Apple Silicon downloads.
- Updated companion docs to explain the Steam Deck SSH tunnel profile.
- Updated Steam Deck companion guidance to prefer the `.AppImage` build.
- Preserved existing AI provider/model settings during noninteractive SteamOS updates.
- Made dashboard feature toggles persist immediately when changed, including Spotify and Calendar widget selections.
- Persisted selected Google read/write calendars through the settings API.
- Opened the companion app to the chat view by default and widened the default desktop window.
- Clarified that `/ws/caroline` is the fixed WebSocket route, while the host's configured AI name is synced separately.

## Fixed

- Fixed AI name saving so the hidden duplicate settings field can no longer overwrite Carl back to Caroline.
- Fixed `/health` build reporting so installed commit and channel data come from `caroline_build.json`.
- Fixed SteamOS updates when the cached repo has local changes by preserving the dirty cache and recloning.
- Fixed SteamOS update status so it can read the helper log and report completion.
- Fixed Linux/Pi update status so updater logs survive the installer cleanup and service restart.

## Removed

- Removed generated release artifacts and large temporary companion/dependency folders from the working tree.

## Known Issues

- The Catoline companion profile still needs the real Pop!_OS IP address before it can connect.
- Frog Pilot is a placeholder until final avatar artwork is added.
