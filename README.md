# Project: Caroline

**Your open-source, highly personalized digital sidekick.**

> "Not a voice assistant you talk at. A co-pilot that's actually on your side."

---

![Project: Caroline avatar](assets/caroline.gif)
![Project: Caroline interface](Screenshot_7.png)
## The Story

Project: Caroline is your portal to an ambient digital sidekick completely personalized to you. When they wake up, a brief setup wizard establishes their baseline personality. From there, you can dive into the settings to fully customize their core system prompt — creating a smart dashboard that truly understands how you work, think, and communicate.

---

## Privacy First

One of the core values of this project is that your information is safe. There is no telemetry, no data harvesting, and no corporate oversight. Personal information is not collected.

If you choose to run the AI in **Local** mode (via Ollama), your prompts, calendar events, and tasks never even leave your local network. Your data is yours.

---

## What It Does

- **Cyberpunk UI** — Ambient kiosk interface served on port 8080
- **Robust Backend** — Node-RED on port 1880 as a bare-metal system service
- **Persistent Memory** — AI chat with memory across sessions
- **Productivity** — Creates calendar events and manages a local task list via chat
- **Proactive AI** — Caroline checks in four times a day with lightweight context
- **Local & Cloud AI** — Ollama (gemma3:1b, qwen3:0.6b, smollm2:360m) free forever, or OpenRouter (Claude Haiku) for ~$0.05/month
- **Built-in Widgets** — Live news, weather, tides, radio, Pomodoro timer, task lists, and TV channels
- **Smart Home** — Philips Hue control
- **OAuth Integrations** — Google and Spotify connect from the GUI; no JSON key upload required for normal setup

---

## System Requirements

| Category | Recommended | Minimum / Alternate |
|---|---|---|
| Hardware | Raspberry Pi 4 or 5 | 64-bit Ubuntu/Debian/Linux desktop or VM |
| RAM | 4GB+ | 4GB recommended for a smooth kiosk experience |
| OS | Raspberry Pi OS Desktop 64-bit | 64-bit Ubuntu/Debian/Linux |
| CPU architecture | `arm64` / `aarch64` | `x86_64` / `amd64` also works |
| Storage | 32GB+ microSD card | 16GB microSD minimum if skipping local AI/Ollama |
| Local AI storage | 64GB+ microSD card | Recommended when installing Ollama/local models |
| Network | Internet access during install | Local network access for kiosk and integrations |
| Recovery access | Raspberry Pi Connect or SSH before kiosk testing | Strongly recommended before enabling boot-to-kiosk |
| Runtime | Node.js 18+ | Installed by the Caroline installer when available |

Avoid 32-bit `i386` VM images for this release. NodeSource does not publish Node 20 packages for `i386`, official Node.js 18 Linux binaries do not include 32-bit x86, and many 32-bit distro repositories only provide old Node.js packages.

Kiosk mode requires a desktop environment. Raspberry Pi OS Lite can run the services and web UI, but it is not the recommended path for the dedicated fullscreen display experience.

---

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/daveeuson/project-caroline/master/install.sh | bash
```

The installer asks for your name, kiosk mode, and whether to install Ollama. On first launch, Caroline walks through location/timezone, identity, personality, dashboard widget choices, and optional integrations. For Raspberry Pi installs, **OpenRouter is the recommended chat provider**. Local Ollama on a Pi is best treated as an experimental/offline fallback: it is private and free, but it can pin the CPU, take 20-60 seconds, and small models may answer oddly.

| Local model | Pi recommendation | Notes |
|---|---|---|
| `gemma3:1b` | Best local fallback | Friendlier and more coherent in Pi testing; still much slower than OpenRouter. |
| `qwen3:0.6b` | Speed fallback | Smaller/faster candidate when Gemma feels heavy. |
| `smollm2:360m` | Tiny emergency fallback | Fastest tiny model tested, but quality is limited. |
| `tinyllama` | Legacy fallback | Also small; can be unpredictable. |
| `llama3.2:1b` | Advanced / slow | Works on an 8GB Pi, but replies can take ~20-60 seconds. |
| `gemma2:2b` / larger | Desktop or patient Pi users | Expect slow replies, heat, and sustained CPU load. |

You can also run Ollama on another computer and use the Pi only as the kiosk. In **Settings -> AI**, set **AI provider** to **Ollama** and set **Ollama URL** to the other machine, for example `http://192.168.1.50:11434`. On that computer, Ollama must listen on the network, usually by setting `OLLAMA_HOST=0.0.0.0:11434`, and your firewall must allow the Pi to reach port `11434`. Keep this on your LAN or VPN; do not expose Ollama directly to the public internet.

The core kiosk, chat, weather, news, radio, Pomodoro, local tasks, and display preferences work from the Caroline GUI. Some optional widgets and integrations require outside accounts, API keys, OAuth clients, or device pairing before they can be used.

Platform note: this release is designed for Raspberry Pi first. If you do not want to use a Pi, a 64-bit Ubuntu/Debian/Linux desktop or VM should also work.

On desktop Raspberry Pi OS, the installer also creates two desktop shortcuts:

- **Project Caroline** — opens Caroline in a normal Firefox window.
- **Project Caroline Kiosk** — opens Caroline in fullscreen kiosk mode.

### Upgrading

To upgrade an existing Caroline install after a new GitHub release, rerun the installer:

```bash
curl -fsSL https://raw.githubusercontent.com/daveeuson/project-caroline/master/install.sh | bash
```

On an existing install, the script pulls the latest repository into `~/project-caroline`, copies the updated app and Node-RED flows into `~/caroline`, preserves `caroline_settings.json` by merging new defaults underneath your current settings, backs that settings file up with a timestamp, and restarts the Caroline services.

Your API keys, Hue pairing, Discord token, Google/Spotify credentials, local tasks, memory, and OAuth files are preserved. If you edited files directly inside `~/caroline`, move those changes into your repo first because the runtime app files are replaced during upgrade.

### Uninstalling

To remove Caroline from a Pi and start fresh:

```bash
curl -fsSL https://raw.githubusercontent.com/daveeuson/project-caroline/master/uninstall.sh | sudo bash
```

The uninstaller asks you to type `UNINSTALL CAROLINE` before it removes anything. It removes Caroline services, nginx site config, desktop launchers, kiosk autostart entries, Firefox Caroline profiles, `~/caroline`, and `~/project-caroline`. Shared packages such as Node.js, Node-RED, nginx, Firefox, and Ollama are left installed in case other projects use them.

For automated QA on a disposable VM:

```bash
curl -fsSL https://raw.githubusercontent.com/daveeuson/project-caroline/master/uninstall.sh | sudo bash -s -- --yes
```

Use `--keep-data` if you only want to remove services and launchers while preserving `~/caroline`.

After install, open **Settings** in Caroline:

- **Google:** create a Desktop OAuth client, import its OAuth JSON or paste the Client ID, then use **Connect Google** for Calendar. The old Sheets/service-account path is kept only as an advanced fallback.
- **Spotify:** open Settings → Connect → Spotify. The settings panel shows your exact redirect URI (e.g. `http://localhost:1880/spotify/callback`). Add that URI in your [Spotify Developer Dashboard](https://developer.spotify.com/dashboard) under your app → Edit → Redirect URIs, then click **Connect Spotify**.
- **Hue / Discord / OpenRouter:** paste credentials directly in Settings.
- **Display preferences:** Settings → Widgets controls 12/24-hour time and Fahrenheit/Celsius for weather and Pi health.

### Before QA: Remote Access

For clean installs, wipes, and kiosk debugging, set up Raspberry Pi Connect before you depend on the kiosk screen alone. It gives you browser-based access to the Pi desktop or shell, which is helpful if Firefox opens full-screen or the Pi is across the room.

- Raspberry Pi Connect requires Raspberry Pi OS Bookworm or later.
- Raspberry Pi OS Desktop and Full include Connect by default; Raspberry Pi OS Lite includes the remote-shell-only variant.
- Screen sharing requires the Wayland desktop session, which is the default on current Raspberry Pi OS Desktop releases.
- Turn it on from the desktop tray icon with **Turn On Raspberry Pi Connect**, or run `rpi-connect on`, then `rpi-connect signin` and finish sign-in with your Raspberry Pi ID.
- Access the Pi later from [connect.raspberrypi.com](https://connect.raspberrypi.com/).

Official guide: [Raspberry Pi Connect documentation](https://www.raspberrypi.com/documentation/services/connect.html)

### QA Checklist

Before calling a release good, test these paths on a clean Pi or VM:

- Fresh install from the public `curl -fsSL ... install.sh | bash` command.
- Reboot after install and confirm Caroline, nginx, kiosk autostart, and desktop shortcuts still work.
- Settings save/reopen for every integration: OpenRouter, Ollama, Hue, Spotify, Discord, Google, Tides, time format, and temperature unit.
- Upgrade by rerunning the installer and confirm saved settings/API keys still show as saved or connected.
- Uninstall with `uninstall.sh`, then reinstall cleanly.
- Kiosk recovery: Raspberry Pi Connect or SSH is available before enabling boot-to-kiosk on a physical display.

### Advanced Widget Setup

Most advanced setup happens outside Caroline first, then you paste credentials into **Settings**.

#### OpenRouter Cloud AI

Use this if you want Claude/other cloud models instead of local Ollama.

1. Create an account at [openrouter.ai](https://openrouter.ai/).
2. Create an API key.
3. In Caroline, open **Settings -> AI**.
4. Choose **OpenRouter**, paste the key, and pick the model.
5. Save, then check that the top bar no longer says the AI key is needed.

#### Google Calendar

Use this for calendar context and calendar event creation.

1. Open [Google Cloud Console](https://console.cloud.google.com/).
2. Create or choose a project.
3. Enable the Google Calendar API.
4. Configure an OAuth consent screen.
5. Create an OAuth client of type **Desktop app**.
6. Download the OAuth JSON.
7. In Caroline, open **Settings → Connect → Google**.
8. Import the OAuth JSON, or paste the Client ID.
9. Click **Connect Google** and finish the browser sign-in.

The Calendar ID can usually stay `primary`.

#### Google Sheets Legacy Sync

This is optional and only needed if you are using the older Sheets/task sync path.

1. Create or choose a Google Sheet.
2. Copy the spreadsheet ID from the sheet URL.
3. In Caroline, open **Settings → Connect → Google → Advanced Google options**.
4. Paste the spreadsheet ID.
5. If using a service account, upload or paste the service account JSON and share the sheet with the service account email.

Normal Calendar setup does not require this.

#### Spotify

Use this for Spotify account connection/control.

1. Open the [Spotify Developer Dashboard](https://developer.spotify.com/dashboard).
2. Create an app.
3. In Caroline, open **Settings → Connect → Spotify** and copy the redirect URI shown there.
4. In Spotify, add that exact redirect URI under **Edit Settings → Redirect URIs**.
5. Copy the Spotify Client ID into Caroline.
6. Click **Connect Spotify** and finish sign-in.

The redirect URI must match exactly, including trailing slash.

#### Discord

Use this for Discord channel messaging.

1. Open the [Discord Developer Portal](https://discord.com/developers/applications).
2. Create an application, then add a bot.
3. Copy the bot token. It should look like a long secret token, not a numeric channel/user ID.
4. Invite the bot to your server with permission to read and send messages in the target channel.
5. Enable Developer Mode in Discord, right-click the channel, and copy the channel ID.
6. In Caroline, open **Settings → Connect → Discord**.
7. Enable Discord, paste the bot token and channel ID, then use **Test Discord**.

#### Philips Hue

Use this for Hue lights.

1. Make sure the Pi and Hue Bridge are on the same network.
2. In Caroline, open **Settings → Connect → Hue**.
3. Enter the bridge IP, or use the detect button if available.
4. Press the physical link button on the Hue Bridge.
5. In Caroline, request/create the Hue API key.
6. Detect/select the Hue group to control.

#### Tides

Use this for tide predictions.

1. Find the nearest NOAA tide station ID from [NOAA Tides & Currents](https://tidesandcurrents.noaa.gov/).
2. In Caroline, open **Settings → Widgets**.
3. Paste the station ID into **Tides station**.
4. Save and wait for the tide widget to refresh.

If you leave it blank, Caroline uses a default station that may not match your location.

#### Custom Video Channels

Use this if you want custom streams in the video widget.

1. Open **Settings → Widgets → Video channels**.
2. Add a channel name and icon.
3. Paste a direct HLS `.m3u8` URL or a YouTube video ID.
4. Save and select the channel in the kiosk.

## Stack

| Layer | Technology |
|---|---|
| Frontend | Single HTML file |
| Backend | Node-RED (bare-metal systemd, no Docker) |
| Web server | nginx (serves HTML on port 8080) |
| AI (local/remote) | Ollama on `localhost:11434` or another LAN computer |
| AI (cloud) | OpenRouter API |
| Display | Firefox, kiosk mode, 1280×800 |

---

## Architecture

```
Browser
  ├── HTTP GET (port 8080) ──────► nginx ──► index.html
  └── WebSocket (port 1880) ─────► Node-RED ──► Ollama (Pi or LAN server)
                                            └──► OpenRouter (cloud)
```

Node-RED runs as a bare-metal systemd service. nginx serves the static kiosk on port 8080. WebSocket traffic goes directly to Node-RED on port 1880. Spotify uses a PKCE OAuth popup through Node-RED at `/spotify/callback`, so the kiosk stays in place and no HTTPS proxy is required.

---

## Cost Breakdown

| Service | Est. Monthly Cost | Details |
|---|---|---|
| Ollama | $0.00 | Local AI, free forever |
| OpenRouter + Claude Haiku | ~$0.05 | Cloud-based processing |
| **Target** | **Under $5.00** | A highly economical system |

---

## Deep Personality Customization

While the initial setup gives your sidekick a baseline vibe, you can deeply customize their brain in the Settings panel. If you use another AI regularly (like ChatGPT or Claude), it already knows your exact communication style.

Copy and paste this prompt into your existing AI to generate a highly tailored profile:

> *"I am setting up an open-source digital sidekick kiosk called Project: Caroline. Since you already know my workflow, personality, communication style, and support needs, write a concise user profile I can paste into Caroline. Focus on how I think, what helps me follow through, how direct or gentle the assistant should be, what drains or motivates me, and any recurring patterns worth remembering. Keep it practical, strictly platonic, and formatting-free. Do not include secrets, private contact details, or anything I would not want stored on my own kiosk."*

Paste the result into **Settings -> AI -> Personality -> Imported memory prompt**. The boot sequence writes Caroline's setup answers into **Setup memory prompt**, while the imported memory prompt tells Caroline how to support you based on what another AI already knows.

---

## Roadmap

```
v0.1 — Core kiosk: chat, widgets, smart home, Pomodoro.            [██████████]
v0.2 — Agent loop, auto-tasks, installer, CI pipeline.             [██████████]
v0.3 — Tabbed settings, meme widget, Spotify PKCE, public release. [████████░░]  ← you are here
v1.0 — Hardware agnostic (Windows, Mac, tablet, cloud).            [░░░░░░░░░░]
v2.0 — Virtual Sidekick mode — moods, adaptive workflow.           [░░░░░░░░░░]
```

---

## What Makes It Unique

No other open-source kiosk project combines conversational AI with persistent memory, local model support, a distinct sidekick personality, proactive ambient messages, and a one-command install. MagicMirror² is the closest comparison, but it's a static dashboard. Project: Caroline is an active participant in your day.

---

## Links & Credits

- **GitHub:** [github.com/daveeuson/project-caroline](https://github.com/daveeuson/project-caroline)
- **License:** MIT
- Built by Dave Euson
