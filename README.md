# Project: Caroline

**Your source-available, highly personalized digital sidekick.**

> "Not a voice assistant you talk at. A co-pilot that's actually on your side."

---

![Project: Caroline avatar](assets/caroline.gif)
![Project: Caroline interface](Screenshot_7.png)
## The Story

Project: Caroline is your portal to an ambient digital sidekick completely personalized to you. When they wake up, a brief setup wizard establishes their baseline personality. From there, you can dive into the settings to fully customize their core system prompt — creating a smart dashboard that truly understands how you work, think, and communicate.

---

## Beta Status

Project: Caroline is public beta software. The core kiosk, local AI chat, weather, news, radio, Pomodoro, local tasks, and display settings are designed to work from the Caroline GUI after the one-command installer. Some integrations still require patience and developer-style setup.

You do **not** need every integration to use Caroline. Local Ollama mode can run without an OpenRouter key, Google Cloud project, Spotify Developer app, Discord bot, or Philips Hue bridge. Optional services such as Google Calendar, Spotify, Discord, Hue, and cloud AI are powerful, but they may require creating OAuth clients, copying redirect URLs exactly, pairing devices, or troubleshooting account/provider limitations. If you are new to Raspberry Pi, Linux, OAuth, or developer dashboards, expect some fiddly configuration and ask for help when needed.

The goal is not to scare anyone off. It is to be honest: Caroline is usable today, but it is still an enthusiast project, not a polished consumer appliance.

---

## Optional Support

Project: Caroline is free to install and use. Donations are never required, but if Caroline makes your desk feel a little more alive and you want to support continued development, you can buy Dave a coffee:

https://buymeacoffee.com/daveeuson

---

## License & Ownership

Project: Caroline is currently **source-available public beta software**, not MIT/Apache/GPL open source. You can install it, inspect the code, modify it for your own personal non-commercial setup, and contribute fixes back through GitHub.

You may not sell it, rebrand it, remove attribution, publish a competing packaged derivative, or present Project: Caroline as your own product without written permission.

Copyright (c) 2026 Dave Euson. All rights reserved. See [LICENSE](LICENSE) and [NOTICE.md](NOTICE.md) for the full beta terms.

---

## Privacy First

One of the core values of this project is that your information is safe. Caroline does not harvest personal information, chat prompts, memory, calendar data, OAuth tokens, API keys, location, ZIP code, or IP address.

The installer includes a transparent privacy prompt for project-health telemetry. You can opt in to an anonymous install/update count, opt in separately to safe troubleshooting diagnostics, or decline remote telemetry entirely. Your choice does not change any Caroline features or functionality. If you decline, Caroline records that choice locally in `~/caroline/caroline_telemetry.jsonl`; it only sends a one-time anonymous opt-out count if you explicitly allow that too.

If you choose to run the AI in **Local** mode (via Ollama), your prompts, calendar events, and tasks never even leave your local network. Your data is yours.

---

## What It Does

- **Cyberpunk UI** — Ambient kiosk interface served on port 8080
- **Robust Backend** — Node-RED on port 1880 as a bare-metal system service
- **Persistent Memory** — AI chat with memory across sessions
- **Productivity** — Creates calendar events and manages a local task list via chat
- **Calendar Reminders** — Optional spoken/display heads-up before upcoming meetings
- **Proactive AI** — Caroline checks in four times a day with lightweight context
- **Local & Cloud AI** — Ollama (gemma3:1b, qwen3:0.6b, smollm2:360m) free forever, or OpenRouter (Claude Haiku) for ~$0.05/month
- **Built-in Widgets** — Live news, weather, tides, radio, Pomodoro timer, task lists, and TV channels
- **Smart Home** — Philips Hue control
- **Optional Integrations** — Google Calendar, Spotify, Hue, Discord, and cloud AI can be connected from Settings, but some require external developer accounts or OAuth setup

---

## System Requirements

| Category | Recommended | Minimum / Alternate |
|---|---|---|
| Hardware | Raspberry Pi 4 or 5 | 64-bit Ubuntu/Debian/Linux server VM or desktop host |
| RAM | 4GB+ | 4GB recommended; 6-8GB nicer with local AI |
| OS | Raspberry Pi OS Desktop 64-bit | Ubuntu Server 64-bit VM for headless hosting; Ubuntu Desktop only for experimental local kiosk testing |
| CPU architecture | `arm64` / `aarch64` | `x86_64` / `amd64` also works |
| Storage | 32GB+ microSD card | 16GB microSD minimum if skipping local AI/Ollama |
| Local AI storage | 64GB+ microSD card | Recommended when installing Ollama/local models |
| Network | Internet access during install | Local network access from your browser/client to the Caroline host |
| Recovery access | Raspberry Pi Connect or SSH before kiosk testing | Strongly recommended before enabling boot-to-kiosk |
| Runtime | Node.js 18+ | Installed by the Caroline installer when available |

Tested release targets are Raspberry Pi OS Desktop and Ubuntu Server. Ubuntu-based distributions such as Pop!_OS, Linux Mint, Zorin OS, and elementary OS are expected to work best in **server/client mode** because they share the same Debian/Ubuntu package base, but they are not fully tested yet. Local desktop kiosk behavior may need distro-specific adjustment.

### Server vs Client Support

Caroline has two parts:

- **Server/host**: the machine running the installer, Node-RED, nginx, settings, updates, optional Ollama, and local integrations.
- **Client/display**: the browser that opens the Caroline GUI at `http://<host-ip>:8080/`.

| Platform | As Caroline server/host | As browser client/display |
|---|---|---|
| Raspberry Pi OS Desktop 64-bit | Supported and primary beta target | Supported, including kiosk mode |
| Ubuntu Server 64-bit | Supported server/client target | Use another browser device for display |
| Ubuntu Desktop / Debian desktop | Experimental | Supported as a browser client |
| WSL Ubuntu on Windows | Experimental development/server host | Windows browser usually opens `http://localhost:8080/` |
| macOS | Not first-beta supported as a one-command server install | Supported as a browser client |
| Windows native | Not first-beta supported as a one-command server install | Supported as a browser client |
| iPad/tablet/phone | Not a server target | Supported for basic dashboard viewing; kiosk/voice behavior varies |

In plain English: the first beta supports **Pi or Ubuntu as the host**, and almost any modern browser as the client. A Mac, Windows PC, tablet, or phone can view and control Caroline if it can reach the host URL on your trusted LAN or VPN.

For Ubuntu Server, VM, or any server/client install, give the Caroline host a stable local IP address. A router DHCP reservation is usually the easiest choice; a manually configured static IP also works if you know your LAN settings. If the host IP changes later, your browser URL and some integration redirect URLs may need to be updated.

Small Ubuntu Server VMs can run out of memory while installing Node.js or Node-RED. The installer creates a temporary swap cushion on low-memory hosts when there is enough disk space, but 2GB+ RAM is still the smoother minimum for beta QA.

Avoid 32-bit `i386` VM images for this release. NodeSource does not publish Node 20 packages for `i386`, official Node.js 18 Linux binaries do not include 32-bit x86, and many 32-bit distro repositories only provide old Node.js packages.

Kiosk mode requires a desktop environment and is primarily tested on Raspberry Pi OS Desktop. For an Ubuntu VM, the recommended path is **server mode**: install Caroline on Ubuntu Server, leave kiosk mode off, and open the GUI from another machine on your LAN at `http://<vm-ip>:8080/`.

---

## Network Safety

Caroline is designed for a trusted home LAN or VPN. Do not port-forward or publicly expose the kiosk, Node-RED backend, OAuth proxy, or Ollama ports (`8080`, `1880`, `8443`, or `11434`). Several Settings and System buttons intentionally control the local machine from the GUI, including save settings, update, reboot, kiosk exit, and optional terminal launch. Those routes assume you trust the devices on your local network.

For remote access, use Raspberry Pi Connect, SSH over a VPN, Tailscale, WireGuard, or another private access method instead of opening Caroline directly to the public internet.

---

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/daveeuson/project-caroline/master/install.sh | bash
```

The installer asks for your name, privacy/telemetry choices, kiosk mode, and whether to install Ollama. On first launch, Caroline walks through location/timezone, identity, personality, dashboard widget choices, and optional integrations. Caroline supports both **local Ollama** and **OpenRouter** chat. Local Ollama is private and free, but it needs patience on small devices; first replies can take 20-60 seconds while the model warms up. OpenRouter remains the faster, more polished option when a cloud API key is available.

Maintainer note: remote project-health pings are only attempted when `CAROLINE_TELEMETRY_ENDPOINT` is set for the installer environment. Without that endpoint, telemetry choices and events are still written locally but nothing is sent off-device.

| Local model | Recommendation | Notes |
|---|---|---|
| `gemma3:1b` | Best local default | Friendlier and more coherent in local testing; still much slower than OpenRouter. |
| `qwen3:0.6b` | Speed fallback | Smaller/faster candidate when Gemma feels heavy. |
| `smollm2:360m` | Tiny emergency fallback | Fastest tiny model tested, but quality is limited. |
| `tinyllama` | Legacy fallback | Also small; can be unpredictable. |
| `llama3.2:1b` | Advanced / slow | Works on stronger small devices, but replies can take ~20-60 seconds. |
| `gemma2:2b` / larger | Desktop or patient users | Expect slow replies, heat, and sustained CPU load. |

You can also run Ollama on another computer and use the Caroline device only as the kiosk. In **Settings -> AI**, set **AI provider** to **Ollama** and set **Ollama URL** to the other machine, for example `http://192.168.1.50:11434`. On that computer, Ollama must listen on the network, usually by setting `OLLAMA_HOST=0.0.0.0:11434`, and your firewall must allow the Caroline device to reach port `11434`. Keep this on your LAN or VPN; do not expose Ollama directly to the public internet.

The core kiosk, chat, weather, news, radio, Pomodoro, local tasks, and display preferences work from the Caroline GUI. Some optional widgets and integrations require outside accounts, API keys, OAuth clients, or device pairing before they can be used. Not every user will be able to create every outside key, and that is okay; Caroline is intended to degrade gracefully when optional services are left disconnected.

Platform note: this release is designed for Raspberry Pi first. If you do not want to use a Pi, a 64-bit Ubuntu/Debian/Linux VM should also work as a **server host**. On an Ubuntu VM, use Ubuntu Server 64-bit, enable networking, choose **No** when the installer asks about kiosk mode, then open Caroline from an external browser at `http://<vm-ip>:8080/`. Ubuntu-based desktop distributions may also work, especially as server/client hosts, but fullscreen kiosk autostart is only lightly tested outside Raspberry Pi OS. Ubuntu Desktop kiosk mode is possible, but it is not the recommended VM path because VM display layers such as Hyper-V Enhanced Session/XRDP and snap Firefox can interfere with fullscreen kiosk behavior.

WSL Ubuntu on Windows should work for development-style server/client testing: install Caroline inside WSL, then open the GUI from Windows at `http://localhost:8080/` or the WSL host address. This is useful for testing the Ubuntu install path without a separate VM, but it is not the best always-on kiosk target because WSL depends on the Windows host session, power state, and networking. External LAN clients may need WSL mirrored networking or Windows port forwarding.

macOS and Windows native installs are not first-beta server targets because the installer assumes Linux tooling such as `apt`, Linux paths, and system service setup. Macs and Windows PCs are excellent **browser clients**, though: open `http://<caroline-host-ip>:8080/` from Safari, Chrome, Edge, or Firefox and Caroline should behave like the same GUI. Hardware-local features such as kiosk autostart, wake word, microphone permissions, terminal launch, and reboot/update controls apply to the Linux host, not the client device.

On desktop Linux, the installer also tries to create two desktop shortcuts:

- **Project Caroline** — opens Caroline in a normal Firefox window.
- **Project Caroline Kiosk** — opens Caroline in fullscreen kiosk mode.

The kiosk uses Firefox because it has been the most stable display browser for Caroline in Pi testing. Browser-based voice input depends on Chrome-family speech recognition, so voice is best treated as experimental until Caroline has a local speech-to-text service.

### Ubuntu VM Server Mode

For VM testing or non-Pi installs, treat Caroline like a small home-server app:

1. Install Ubuntu Server 64-bit in the VM.
2. Give the VM network access. Bridged networking is easiest; NAT also works if you can reach the VM IP from your browser.
3. Reserve a stable IP for the VM if you plan to keep using it. A DHCP reservation in your router is recommended; a static IP inside Ubuntu is fine for advanced setups.
4. Run the one-command installer.
5. Choose **No** for kiosk mode.
6. After reboot, find the VM IP with `hostname -I`.
7. Open `http://<vm-ip>:8080/` from your normal desktop browser.

At the end of install, Caroline prints host-specific next steps. On a Raspberry Pi, it points to the Pi display/kiosk path and still shows browser fallback URLs. On an Ubuntu/server host, it points users to the client-browser URL:

```text
On this host:        http://localhost:8080/
From client browser: http://<vm-ip>:8080/
```

This mode tests the installer, nginx web UI, Node-RED backend, settings persistence, AI provider routing, integrations, update, and reboot paths. It does not test local fullscreen kiosk autostart, local browser microphone permissions, or VM display wake/sleep behavior.

In server/client mode, the Ubuntu Server VM is the Caroline host and your normal browser is the client. The same GUI still controls the host: Settings save to the VM, chat routes through Node-RED on the VM, the CPU/RAM pill reports the VM, and Update/Reboot act on the VM. The expected exceptions are display-only controls such as local kiosk autostart, local terminal launch, kiosk exit, and browser microphone/wake-word behavior over plain LAN HTTP. Voice input in a remote browser needs a secure browser context, such as HTTPS, or a future local speech-to-text service.

### WSL Development Mode

On Windows, WSL Ubuntu can be used like a lightweight Ubuntu Server host for testing:

1. Install Ubuntu in WSL.
2. Open the WSL terminal.
3. Run the Caroline installer.
4. Choose **No** for kiosk mode.
5. Open Caroline from Windows at:

```text
http://localhost:8080/
```

If `localhost` does not work immediately after install, reboot Windows or run `wsl --shutdown` from PowerShell, reopen Ubuntu, and try again. You can also check the WSL IP with `hostname -I` inside WSL and try `http://<wsl-ip>:8080/`. For other devices on your LAN to reach a WSL-hosted Caroline, you may need WSL mirrored networking or Windows port forwarding.

WSL is best treated as a developer/test host. It is convenient, but Windows sleep, reboots, firewall rules, and WSL lifecycle behavior can stop or change the Caroline host.

### Browser Clients

Any modern browser on your trusted LAN can be a Caroline display/client:

```text
http://<caroline-host-ip>:8080/
```

This includes macOS, Windows, Linux desktops, tablets, and phones. The browser client shows and controls the same Caroline GUI, but the backend still runs on the Linux host. Settings, chat, integrations, Update, Reboot, and CPU/RAM status apply to the host. Local display features such as boot-to-kiosk, kiosk exit, local terminal launch, and microphone/wake-word behavior depend on the browser/device and are not guaranteed in remote client mode.

### Upgrading

To upgrade an existing Caroline install after a new GitHub release, rerun the installer:

```bash
curl -fsSL https://raw.githubusercontent.com/daveeuson/project-caroline/master/install.sh | bash
```

On an existing install, the script pulls the latest repository into `~/project-caroline`, copies the updated app and Node-RED flows into `~/caroline`, preserves `caroline_settings.json` by merging new defaults underneath your current settings, backs that settings file up with a timestamp, and restarts the Caroline services.

Your API keys, Hue pairing, Discord token, Google/Spotify credentials, local tasks, memory, and OAuth files are preserved. If you edited files directly inside `~/caroline`, move those changes into your repo first because the runtime app files are replaced during upgrade.

### Uninstalling

To remove Caroline from a device and start fresh:

```bash
curl -fsSL https://raw.githubusercontent.com/daveeuson/project-caroline/master/uninstall.sh | sudo bash
```

The uninstaller asks you to type `UNINSTALL CAROLINE` before it removes anything. It removes Caroline services, nginx site config, desktop launchers, kiosk autostart entries, Firefox Caroline profiles, `~/caroline`, and `~/project-caroline`. Shared packages such as Node.js, Node-RED, nginx, Firefox, and Ollama are left installed in case other projects use them.

For automated QA on a disposable VM:

```bash
curl -fsSL https://raw.githubusercontent.com/daveeuson/project-caroline/master/uninstall.sh | sudo bash -s -- --yes
```

Use `--keep-data` if you only want to remove services and launchers while preserving `~/caroline`.

After install, open **Settings** in Caroline for any optional services you want to use:

- **Google:** create a Desktop OAuth client, then import or paste the OAuth JSON before using **Connect Google** for Calendar. Client ID alone is not enough because Caroline also needs the client secret from that JSON. The old Sheets/service-account path is kept only as an advanced fallback.
- **Spotify:** open Settings → Connect → Spotify. The settings panel shows your exact redirect URI (usually `https://<host-ip>:8443/spotify/callback`). Add that URI in your [Spotify Developer Dashboard](https://developer.spotify.com/dashboard) under your app → Edit → Redirect URIs, then click **Connect Spotify**.
- **Hue / Discord / OpenRouter:** paste credentials directly in Settings.
- **Display preferences:** Settings → Widgets controls 12/24-hour time and Fahrenheit/Celsius for weather and device health.

Spotify's LAN redirect uses Caroline's self-signed HTTPS proxy on port `8443`. In server/client mode, open `https://<host-ip>:8443/` once from the same browser and accept the local certificate warning before connecting Spotify.

### Before QA: Remote Access

For clean installs, wipes, and kiosk debugging, set up Raspberry Pi Connect before you depend on the kiosk screen alone. It gives you browser-based access to the Pi desktop or shell, which is helpful if the kiosk browser opens full-screen or the Pi is across the room.

- Raspberry Pi Connect requires Raspberry Pi OS Bookworm or later.
- Raspberry Pi OS Desktop and Full include Connect by default; Raspberry Pi OS Lite includes the remote-shell-only variant.
- Screen sharing requires the Wayland desktop session, which is the default on current Raspberry Pi OS Desktop releases.
- Turn it on from the desktop tray icon with **Turn On Raspberry Pi Connect**, or run `rpi-connect on`, then `rpi-connect signin` and finish sign-in with your Raspberry Pi ID.
- Access the Pi later from [connect.raspberrypi.com](https://connect.raspberrypi.com/).

Official guide: [Raspberry Pi Connect documentation](https://www.raspberrypi.com/documentation/services/connect.html)

### Local Pi Update During QA

When testing local changes before a GitHub release, copy only the file you changed, keep a timestamped backup on the Pi, then restart nginx:

```powershell
$ts = Get-Date -Format "yyyyMMdd-HHmmss"
ssh davee@192.168.1.50 "cp /home/davee/caroline/index.html /home/davee/caroline/index.html.backup-$ts"
scp .\index.html davee@192.168.1.50:/home/davee/caroline/index.html
ssh davee@192.168.1.50
sudo systemctl restart nginx
exit
```

Use Bash commands after you are inside the Pi shell. PowerShell syntax such as `(Invoke-WebRequest ...).Content` only works from Windows PowerShell, not from the Pi terminal.

### QA Checklist

For a full wipe/reinstall runbook, see [docs/clean-reinstall-qa.md](docs/clean-reinstall-qa.md).

Before calling a release good, test these paths on a clean Pi or VM:

- Fresh install from the public `curl -fsSL ... install.sh | bash` command.
- Reboot after install and confirm Caroline, nginx, kiosk autostart, and desktop shortcuts still work.
- Settings save/reopen for every integration: OpenRouter, Ollama, Hue, Spotify, Discord, Google, Tides, time format, and temperature unit.
- Calendar: add an event, confirm Upcoming sorts the next real event first, remove that same event, then refresh.
- Tasks: add a task by chat, confirm it appears in the Tasks widget, complete it, then refresh.
- Widgets: close a widget with its `X`, reload the kiosk, and confirm the disabled state persists.
- Upgrade by rerunning the installer and confirm saved settings/API keys still show as saved or connected.
- Uninstall with `uninstall.sh`, then reinstall cleanly.
- Kiosk recovery: Raspberry Pi Connect or SSH is available before enabling boot-to-kiosk on a physical display.
- Voice input: treat browser voice as experimental in the Firefox kiosk until Caroline has a local speech-to-text service.

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
8. Import or paste the OAuth JSON.
9. Click **Connect Google** and finish the browser sign-in. In server/client mode, a `127.0.0.1 refused to connect` page after Google approval is expected; copy that full address-bar URL back into **Finish Google Sign-In** in Caroline.

This setup is free for normal Caroline calendar use and does not require paid Google Cloud billing.

The Calendar ID can usually stay `primary`. After Google is connected, use **Load Calendars** in Settings to pick a specific writable calendar by name.

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
6. Click **Connect Spotify**. Caroline shows a small Spotify login panel with the exact redirect URI and a login link, so the kiosk stays on Caroline while you finish sign-in.

The redirect URI must match exactly, including trailing slash.

In server/client mode, the Spotify redirect uses Caroline's local HTTPS proxy on port `8443`. If your browser warns about the certificate, accept it once for your Caroline host before finishing Spotify login.

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
| Display | Firefox kiosk on Pi/desktop, or any modern client browser in server mode |

---

## Architecture

```
Browser
  ├── HTTP GET (port 8080) ──────► nginx ──► index.html
  └── WebSocket (port 1880) ─────► Node-RED ──► Ollama (host or LAN server)
                                            └──► OpenRouter (cloud)
```

Node-RED runs as a bare-metal systemd service. nginx serves the static kiosk on port 8080 and an HTTPS proxy on port 8443 for OAuth callbacks. WebSocket traffic goes directly to Node-RED on port 1880. Spotify uses a PKCE OAuth popup through `/spotify/callback`, so the Caroline GUI stays in place while Spotify redirects back to the Caroline host.

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

> *"I am setting up a source-available digital sidekick kiosk called Project: Caroline. Since you already know my workflow, personality, communication style, and support needs, write a concise user profile I can paste into Caroline. Focus on how I think, what helps me follow through, how direct or gentle the assistant should be, what drains or motivates me, and any recurring patterns worth remembering. Keep it practical, strictly platonic, and formatting-free. Do not include secrets, private contact details, or anything I would not want stored on my own kiosk."*

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

### Upcoming Feature Ideas

- More Hue light profiles, including richer focus, calm, morning, evening, and cybercore ambience presets.
- Discord direct-message mode as an alternative to channel relay. This is possible, but it needs extra setup for Discord user IDs, DM channel creation, shared-server/privacy handling, and clearer troubleshooting.
- Multi-calendar Google reads so Caroline can summarize events across more than one selected calendar instead of only the configured primary calendar.
- Calendar delete/cancel support, with safe confirmation before removing events from Google Calendar.
- More curated default video channels that fit the early-90s anime/cybercore feel, especially official anime, cartoon, kaiju, science, and calm global-news sources.
- Additional visual themes, including a brighter cybercore mode and darker terminal/archive variants.

---

## What Makes It Unique

Few kiosk projects combine conversational AI with persistent memory, local model support, a distinct sidekick personality, proactive ambient messages, and a one-command install. MagicMirror² is the closest comparison, but it's a static dashboard. Project: Caroline is an active participant in your day.

---

## Links & Credits

- **GitHub:** [github.com/daveeuson/project-caroline](https://github.com/daveeuson/project-caroline)
- **License:** Source-available public beta; see [LICENSE](LICENSE)
- Built by Dave Euson
