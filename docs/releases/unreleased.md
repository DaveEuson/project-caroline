# Project: Caroline Unreleased

Draft notes for the next public beta. Move these into a versioned release note file when the release is tagged.

## Added

- Added a Privacy Dashboard for nightly builds that shows chat/memory counts, retention state, integration status, and host/browser data locations without exposing saved secrets.
- Added host privacy endpoints for companion setup workflows: `/admin/privacy-summary` and `/admin/privacy-clear`.
- Added Routine Coach presets on the kiosk for Morning, Focus, Study, Reset, and Wind Down sessions.
- Added companion-driven document review for text, Markdown, JSON, CSV, logs, and code files.
- Added Screen Ask support from the companion app, routing one captured screenshot through cloud vision when an OpenRouter key is configured.
- Added WSL-aware Windows desktop launchers for Start Server, Open Caroline, browser kiosk mode, and Companion app installation.
- Improved local browser login setup with installer password choice, clearer saved-password output, and a Settings > System reset action.
- Added an expandable Recent Conversation tray on the kiosk with a one-tap expand/collapse button and drag handle for desktop/kiosk layouts.
- Added Touch Mode to first-boot setup and Look & Feel settings for larger tap targets on touchscreen kiosks and couch/Deck use.

## Changed

- Companion Host Setup Hub can now refresh privacy status, view host memory shards, and clear host chat, memory, or profile prompts from the desktop app.
- Companion Host Setup Hub now covers common host setup fields for AI, calendar, Spotify, Discord, voice, Hue, tides, and widget toggles.
- Linux installers now report detectable GPU/VRAM, use it for local Ollama model recommendations, and acknowledge Debian/Ubuntu-family tester platforms more clearly.
- WSL installs now present a clearer Windows-hosted testing path instead of treating kiosk mode like a native Linux desktop.
- WSL local AI now installs and uses Ollama inside Ubuntu WSL instead of steering users toward a Windows Ollama bridge.
- OpenRouter text chat now defaults to `google/gemini-2.5-flash-lite`, with settings/docs recommending Gemini Flash Lite as the affordable hosted default, Mistral Small 24B as the ultra-budget paid option, OpenRouter Free as experimental, and DeepSeek V3.2 as a quality fallback.
- OpenRouter model choices now use clearer cost/quality labels and include current Gemini, Mistral, DeepSeek, OpenAI, and Claude fallback options.
- Local chat now follows through when the user accepts the assistant's own offer with short replies like "sure" or "why not."
- Screen Ask now uses a dedicated cloud vision model setting so screenshot questions do not inherit a text-only or provider-incompatible chat model.
- Local AI recommendations now include `gemma3:4b` as a WSL/desktop responsive fallback for short conversational checks.

## Fixed

- Clear Chat and Clear Memory now clear host-side Caroline data as well as browser-local data when the host endpoint is available.
- Update Caroline status now strips terminal color/spinner control codes before showing progress in Settings.
- Companion document drops no longer get misclassified as beta feedback when the attached file contains feedback/test wording.
- Companion-saved widget changes now re-apply on open kiosks, including enabling the Memes widget without a manual refresh.
- Kiosk chat placeholders now use the configured bot name instead of always saying Caroline.
- Calendar chat replies now distinguish a disabled Calendar widget from an unlinked Google Calendar account.
- Calendar refresh now de-duplicates events across selected calendars before updating the kiosk widget and chat context.
- Calendar refresh attempts now appear in the Settings event log so connection failures are visible during testing.
- Local Ollama chat now handles responsiveness tests locally so short pings like "Test 123" do not trigger anxious or productivity-heavy replies.
- WSL browser setup now keeps Node-RED actions on the Windows-reachable `localhost:8080` URL instead of drifting back to a stale `172.31.x.x` WSL adapter address.
- WSL Start Server now opens an on-brand Project: Caroline status console with the browser URL, retry/log options, and no automatic close.
- WSL Start Server now includes a local browser login password reset option, and the kiosk labels the `8080` proxy as the Caroline Host URL instead of implying raw Node-RED is exposed there.
- Local AI transport failures now show a friendly offline/setup reply instead of leaking raw Ollama `ECONNREFUSED` errors into chat.
- Retired OpenRouter Gemini model ids now migrate to current Gemini 2.5 Flash models, and cloud model errors no longer show the local AI fallback message.
- Successful OpenRouter replies that mention auth/API-key troubleshooting are no longer misclassified as key failures.
- Credential safety guards now distinguish setup/troubleshooting questions from attempts to reveal saved secrets.
- The Ollama settings panel now treats host-side `ok:false` responses as offline, can discover browser-local Ollama models from `localhost:11434` during WSL/localhost testing, and disables host load/pull actions when the Caroline host cannot reach Ollama.
- Repository hygiene now ignores local VM SSH keys and temporary benchmark artifacts so private test files are harder to commit by accident.

## Removed

- None yet.

## Known Issues

- None yet.
