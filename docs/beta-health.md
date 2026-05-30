# Project: Caroline Beta Health

This page is the human-verified public beta health snapshot. It is not live telemetry and does not include private user data, chat content, API keys, OAuth tokens, Discord tokens, or calendar details.

## Current Public Beta Focus

- Raspberry Pi OS Desktop 64-bit as the primary kiosk path.
- Ubuntu Desktop and Ubuntu Server as general Linux host paths.
- Debian and Ubuntu-family desktops such as Pop!_OS, Linux Mint, Zorin OS, and elementary OS as acknowledged beta-family paths.
- Steam Deck / SteamOS as the experimental local-AI path.
- Bazzite / NVIDIA laptops as GPU-backed Linux local-AI hosts.
- Phone and tablet browsers as lightweight LAN clients.
- Project: Caroline Companion App as the desktop buddy-list client and future setup hub.

## Platform Status

| Platform | Current status | Notes |
| --- | --- | --- |
| Raspberry Pi OS Desktop 64-bit | Validated beta path | Best dedicated kiosk target. Watch CPU, browser load, and optional local AI. |
| Ubuntu Desktop / Pop!_OS | Validated beta path | Good host/client balance for ordinary Linux PCs and VMs. |
| Ubuntu Server | Active beta target | Best for headless hosts, GPU laptops, and server-style testing. Needs browser access from another device. |
| Debian / Mint / Zorin / elementary | Acknowledged beta-family path | Installer recognizes Debian/Ubuntu-family systems, but treat them as smoke-test targets until validated. |
| Steam Deck / SteamOS | Experimental beta path | Strong local-AI candidate. Keep an eye on CPU, thermals, and model choice. |
| Bazzite 44 / NVIDIA laptop | Smoke-validated beta path | Validated on RTX 2070 Max-Q with LAN browser/Companion access. Full popular + Gemma 4 sweep recommends `mistral:7b`; `qwen3:1.7b` remains the fast fallback. |
| Windows desktop / RTX 4070 | Local benchmark host | `gemma4:e4b` won the full popular + Gemma 4 direct Ollama sweep; `mistral:7b` is the faster high-quality option. |
| Phone / tablet browser | Active mobile client | Intended for chat, avatar presence, status, settings, sync code, and compact controls. |
| Companion App | Validated desktop client | Pairing, chat, buddy switching, updates, and early host setup are the priority surfaces. |

## Feature Health

| Area | Health | What beta testers should check |
| --- | --- | --- |
| Chat | Core beta | Send normal greetings, follow-up questions, and one command-like request. |
| Local AI | Experimental | See [local model recommendations](local-ai-models.md). The installer now checks OS, CPU architecture, RAM, and detectable GPU/VRAM. Current picks: Pi/Ubuntu CPU-only `qwen2.5:1.5b`, Steam Deck `qwen3:1.7b`, Bazzite RTX 2070 `mistral:7b`, RTX 4070 desktop `gemma4:e4b`. |
| OpenRouter AI | Recommended beta | Best default is `google/gemini-2.5-flash-lite` for polished replies, low cost, and lower host load. Budget fallback: `mistralai/mistral-small-24b-instruct-2501`; free experiment: `openrouter/free`. |
| Memory | Core beta | Save, hide, delete, and correct a simple fact. |
| Calendar | Core beta | Connect Google, read events, and create one test event. |
| Tasks | Core beta | Add, complete, and refresh tasks. |
| Spotify / Hue / Discord | Optional beta | Test only if you already use those services. Setup should be clearer over time. |
| Mobile browser | Active polish | Confirm no sideways scrolling and that chat/settings/status are usable. |
| Companion setup hub | In progress | Pair with a host, load host setup, edit safe settings, and save back to the host. |

## Known Beta Risks

- Local models can be slow or odd on small hardware. OpenRouter with Gemini 2.5 Flash Lite is still the best public beta default.
- Discord self-hosted bot setup is powerful but not beginner-friendly yet.
- Some browser voice input paths need HTTPS or localhost, especially from a phone or remote browser.
- Optional integrations can show confusing states when credentials are partly configured.
- Companion host setup is useful but should still be treated as early beta.

## What Counts As A Good Beta Report

- Device and OS version.
- Fresh install, update, or reinstall.
- Browser or Companion App version.
- AI provider and model.
- Which integrations were enabled.
- One thing that worked surprisingly well.
- One thing that was confusing, slow, or broken.

Submit reports with the [beta test report template](../.github/ISSUE_TEMPLATE/beta_test_report.md).
