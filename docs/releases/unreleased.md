# Project: Caroline Unreleased

Draft notes for the next public beta. Move these into a versioned release note file when the release is tagged.

## Added

- Added a Privacy Dashboard for nightly builds that shows chat/memory counts, retention state, integration status, and host/browser data locations without exposing saved secrets.
- Added host privacy endpoints for companion setup workflows: `/admin/privacy-summary` and `/admin/privacy-clear`.
- Added Routine Coach presets on the kiosk for Morning, Focus, Study, Reset, and Wind Down sessions.
- Added companion-driven document review for text, Markdown, JSON, CSV, logs, and code files.
- Added Screen Ask support from the companion app, routing one captured screenshot through cloud vision when an OpenRouter key is configured.

## Changed

- Companion Host Setup Hub can now refresh privacy status, view host memory shards, and clear host chat, memory, or profile prompts from the desktop app.
- Companion Host Setup Hub now covers common host setup fields for AI, calendar, Spotify, Discord, voice, Hue, tides, and widget toggles.
- Screen Ask now uses a dedicated cloud vision model setting so screenshot questions do not inherit a text-only or provider-incompatible chat model.

## Fixed

- Clear Chat and Clear Memory now clear host-side Caroline data as well as browser-local data when the host endpoint is available.
- Update Caroline status now strips terminal color/spinner control codes before showing progress in Settings.
- Companion document drops no longer get misclassified as beta feedback when the attached file contains feedback/test wording.
- Companion-saved widget changes now re-apply on open kiosks, including enabling the Memes widget without a manual refresh.

## Removed

- None yet.

## Known Issues

- None yet.
