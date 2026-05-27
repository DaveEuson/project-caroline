# Project: Caroline Beta 1.0 Readiness

This is the go/no-go checklist for opening Project: Caroline to broader public beta testers. Beta 1.0 does not mean every integration is finished. It means a new tester can install Caroline, understand the expected limits, try the core loop, and file a useful report without private hand-holding.

## Release Goal

Beta 1.0 should be safe to recommend to curious testers on a trusted home LAN.

Required first impression:

- The README explains what Caroline is and which setup path to choose.
- The installer picks the right family for the host OS and fails kindly when the wrong installer is used.
- The kiosk, Companion app, and phone browser each have a clear role.
- Known limitations are visible before users hit them.

## Must Pass Before Beta 1.0

| Area | Gate | Status |
| --- | --- | --- |
| Repo sanity | `flows.json` parses, installer scripts pass shell syntax, command-language tests pass | Passing on nightly |
| GitHub checks | Release Readiness and Secret Scan pass on the candidate commit | Passing on latest nightly candidate |
| Installer routing | Pi/Ubuntu/Debian-family use `install.sh`; SteamOS/Bazzite use `install-steamos.sh` | Passing on nightly |
| Platform detection | Installer reports OS, CPU architecture, RAM, and detectable GPU/VRAM | Implemented on nightly |
| Core kiosk | Fresh install reaches first-run setup and Settings | Manual device pass required |
| Chat | OpenRouter chat works; local Ollama works on supported hosts | Manual device pass required |
| Memory | Save, recall, hide, and delete a simple memory | Manual device pass required |
| Calendar | Google connect, read, and create test event | Manual account pass required |
| Tasks | Add, complete, and refresh tasks | Manual device pass required |
| Update flow | Settings update status is readable and completes or fails clearly | Manual device pass required |
| Companion | Build passes, pairing/chat/buddy switching work against at least Pi and one non-Pi host | Build passing; manual device pass required |
| Mobile | Phone layout has no sideways scroll and supports chat/settings/status | Manual device pass required |
| Privacy | No secrets or private personal facts in repo; secret scan passes | Passing on latest nightly candidate |
| Docs | README, install guides, beta guide, and issue template are tester-friendly | In progress |

## Platform Matrix

| Platform | Beta 1.0 target | Required check |
| --- | --- | --- |
| Raspberry Pi OS Desktop 64-bit | Primary kiosk path | Fresh install, reboot, kiosk launch, `/health`, Settings save, chat, memory, tasks |
| Ubuntu Server 64-bit | Primary server/client path | Fresh install, browser from another device, `/health`, Settings save, chat, update status |
| Ubuntu Desktop 64-bit | Validated desktop/server-client path | Install/update, browser access, Settings save, local fullscreen only if intentionally testing |
| Steam Deck / SteamOS | Experimental handheld/local-AI path | `install-steamos.sh`, local URL, update status, companion connection or SSH tunnel |
| Bazzite / NVIDIA laptop | Experimental GPU-backed local-AI path | `install-steamos.sh`, GPU/VRAM detection, `mistral:7b` recommendation on 8GB NVIDIA, LAN browser access |
| Phone / tablet browser | Mobile client, not install target | Chat, avatar/status, settings, sync code, no sideways scrolling |
| Companion app | Desktop client and setup hub | Build artifacts, pair with hosts, chat, buddy switching, safe host setup save |

## Feature Smoke Checklist

Run the items that apply to the candidate release:

- [ ] First-run setup on a clean host.
- [ ] Send a normal greeting and a follow-up question.
- [ ] Ask a date/calendar question and confirm Caroline does not guess when disconnected.
- [ ] Add and complete a local task.
- [ ] Save, recall, hide, and delete one simple memory.
- [ ] Toggle at least one widget and confirm it updates on the kiosk.
- [ ] Save Settings, refresh the browser, and confirm values persist.
- [ ] Run Settings > System Check.
- [ ] Run Settings > Update and verify progress is readable.
- [ ] Pair the Companion app with one Pi host and one non-Pi host.
- [ ] Open the mobile view from a phone-sized viewport or real phone.

## Optional Integration Checks

These are beta-useful but not required for every tester:

- [ ] Google Calendar OAuth connect, read events, create one throwaway test event.
- [ ] Spotify OAuth connect and show active device/playback state.
- [ ] Hue on/off and one scene action.
- [ ] Discord channel or DM test message.
- [ ] Voice/microphone via HTTPS or localhost.

## Release Candidate Commands

Run from the main repo:

```bash
node -e "JSON.parse(require('fs').readFileSync('flows.json','utf8'))"
bash -n install.sh
bash -n install-steamos.sh
bash -n uninstall.sh
node tests/command-language.test.js
```

Run from the Companion app worktree:

```bash
npm ci
npm run build
npm run tauri:build
```

## Stop-Ship Conditions

Do not call it Beta 1.0 if any of these are true:

- Fresh install is broken on Pi or Ubuntu Server.
- Bazzite/SteamOS users are routed to the apt installer.
- Secret Scan fails.
- The app stores or publishes real private test data.
- Chat cannot answer a normal greeting on the recommended default path.
- Update status loops forever or shows raw terminal control noise.
- README install commands are stale or point to unavailable release assets.
- The Companion app cannot pair with a clean host using the displayed sync code.

## Manual Sign-Off

Before publishing, record:

- Candidate commit:
- Host release tag:
- Companion release tag:
- Pi result:
- Ubuntu result:
- SteamOS/Bazzite result:
- Companion artifact result:
- Known issues accepted for Beta 1.0:
