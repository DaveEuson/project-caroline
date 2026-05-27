# Project: Caroline Beta 1.0 Draft

Draft notes for the first broader public beta. This is not a published release tag yet. Move these notes into a versioned release file when the Beta 1.0 candidate is frozen.

## Release Theme

Beta 1.0 is the "new tester can actually try it" milestone: clearer install paths, safer setup, better platform detection, a usable Companion app, and honest limits for local AI and optional integrations.

## Highlights

- Local-first AI kiosk for Raspberry Pi OS, Ubuntu, SteamOS/Bazzite, and trusted-LAN browser clients.
- Desktop Companion app for buddy-list chat, multi-host pairing, host status, document review, Screen Ask, and early host setup.
- Mobile browser layout focused on avatar, chat, status, sync code, and compact controls.
- Installer hardware preflight for OS, CPU architecture, RAM, and detectable GPU/VRAM.
- Local model recommendations by platform, including Steam Deck, Bazzite RTX 2070-class hosts, and RTX 4070-class desktops.
- Clearer beta docs for install, clean reinstall QA, Discord, Google OAuth, network prep, model recommendations, and tester reports.

## Added Since v0.3.0-beta.4

- Privacy Dashboard for nightly builds, showing chat/memory counts, retention state, integration status, and host/browser data locations without exposing saved secrets.
- Host privacy endpoints for Companion setup workflows: `/admin/privacy-summary` and `/admin/privacy-clear`.
- Routine Coach presets on the kiosk for Morning, Focus, Study, Reset, and Wind Down sessions.
- Companion-driven document review for text, Markdown, JSON, CSV, logs, and code files.
- Screen Ask support from the Companion app, routing one captured screenshot through a dedicated cloud vision model when an OpenRouter key is configured.
- GPU/VRAM-aware installer reporting and local model selection.
- Debian and Ubuntu-family OS acknowledgement for Pop!_OS, Linux Mint, Zorin OS, and elementary OS.

## Changed Since v0.3.0-beta.4

- Companion Host Setup Hub is split into smaller sections for Buddy, Host, Identity, AI, Connect, Widgets, Privacy, and App.
- Companion Host Setup Hub can refresh privacy status, view host memory shards, and clear host chat, memory, or profile prompts from the desktop app.
- Companion Host Setup Hub now covers common host setup fields for AI, calendar, Spotify, Discord, voice, Hue, tides, and widget toggles.
- Linux installers report detectable GPU/VRAM and use it for local Ollama model recommendations.
- `install.sh` now redirects SteamOS/Bazzite users to `install-steamos.sh` instead of continuing toward an apt failure.
- Screen Ask now uses a dedicated cloud vision model setting so screenshot questions do not inherit a text-only or provider-incompatible chat model.

## Fixed Since v0.3.0-beta.4

- Clear Chat and Clear Memory now clear host-side Caroline data as well as browser-local data when the host endpoint is available.
- Update Caroline status now strips terminal color/spinner control codes before showing progress in Settings.
- Companion document drops no longer get misclassified as beta feedback when the attached file contains feedback/test wording.
- Companion-saved widget changes now re-apply on open kiosks, including enabling the Memes widget without a manual refresh.
- Kiosk chat placeholders now use the configured bot name instead of always saying Caroline.
- Bazzite/NVIDIA hosts are no longer described as generic Ubuntu/Linux x86_64 in the installer preflight when GPU data is detectable.

## Beta 1.0 Known Limits

- OpenRouter is still the recommended public beta AI path for polished replies and lower device load.
- Local Ollama remains experimental, especially on Raspberry Pi and Steam Deck-class hardware.
- Discord setup still requires a Discord bot token for the self-hosted channel/DM bridge.
- Browser microphone support requires HTTPS or localhost; plain LAN HTTP is typing/chat only.
- Companion host setup is useful, but still considered early beta.
- SteamOS/Bazzite uses a home-directory installer and avoids system package-manager changes.
- Do not expose Caroline directly to the public internet.

## Candidate Validation Required

- [ ] Release Readiness passes on candidate commit.
- [ ] Secret Scan passes on candidate commit.
- [ ] Fresh install: Raspberry Pi OS Desktop.
- [ ] Fresh install: Ubuntu Server.
- [ ] Install/update: Ubuntu Desktop VM.
- [ ] Install/update: SteamOS or Bazzite with `install-steamos.sh`.
- [ ] Companion app build and installer artifacts.
- [ ] Mobile browser smoke.
- [ ] README install commands and download links verified.
