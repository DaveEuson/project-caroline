# ✦ Project: Caroline

**Your source-available, highly personalized digital sidekick.**

> "Not a voice assistant you talk at. A co-pilot that's actually on your side."

![Project: Caroline avatar](assets/caroline.gif)
![Project: Caroline interface](Screenshot_7.png)

---

## ⚡ What It Does

- **Cyberpunk UI** — Ambient kiosk interface on port 8080
- **Persistent Memory** — AI chat that remembers conversations
- **Productivity** — Create calendar events & manage local tasks
- **Local & Cloud AI** — Free Ollama models or OpenRouter (~$0.05/month)
- **Built-in Widgets** — News, weather, radio, Pomodoro, tasks, video
- **Smart Home** — Philips Hue light control
- **Proactive** — Checks in 4x daily with lightweight context
- **Privacy-First** — Your data stays local or encrypted

---

## 🚀 Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/daveeuson/project-caroline/master/install.sh | bash
```

**Requirements:** Raspberry Pi 4/5 or 64-bit Ubuntu/Debian, 4GB+ RAM, internet during install.

The installer handles everything: Node.js, Node-RED, nginx, optional Ollama, and setup wizard.

---

## 🔧 Setup Paths

| Platform | Server Role | Client Display |
|---|---|---|
| **Raspberry Pi OS Desktop 64-bit** | ✅ Primary beta | ✅ Firefox kiosk |
| **Ubuntu Server 64-bit** | ✅ Full support | Use any LAN browser |
| **WSL Ubuntu** | 🔧 Dev/test only | Via `localhost:8080` |
| **Any modern browser** | N/A | ✅ From any LAN device |

**First time?** Start with Raspberry Pi OS or Ubuntu Server. [Detailed setup guide →](docs/clean-reinstall-qa.md)

---

## ⚙️ Optional Integrations

Click **Settings → Connect** in Caroline to add:

| Service | Purpose | Setup Effort |
|---|---|---|
| **OpenRouter** | Cloud AI (Claude/others) | Paste API key |
| **Google Calendar** | Calendar sync & event creation | OAuth setup (~5 min) |
| **Spotify** | Music control & playback | OAuth setup (~5 min) |
| **Philips Hue** | Smart light control | Pair bridge (~2 min) |
| **Discord** | Channel messaging | Paste bot token & channel ID |
| **Ollama** | Local AI (free) | Choose model during install |
| **Tides** | Tide predictions | Paste NOAA station ID |

You don't need all of these—just pick what matters to you.

---

## 🛡️ Privacy & Safety

- **Local-first by default:** Chat, tasks, and calendar can stay on your network
- **Transparent telemetry:** Optional anonymous install/update pings only
- **No harvesting:** No tracking, keystroke logging, or forced cloud storage
- **Network-safe:** Never expose Caroline to the public internet; use VPN/SSH for remote access

---

## 📊 Stack

| Layer | Tech |
|---|---|
| Frontend | Single HTML file |
| Backend | Node-RED (systemd service) |
| Web server | nginx (port 8080) |
| AI (local) | Ollama |
| AI (cloud) | OpenRouter API |
| Display | Firefox kiosk or web browser |

---

## 💰 Cost

| What | Cost | Notes |
|---|---|---|
| **Ollama** (local AI) | $0 | Free forever |
| **OpenRouter** (cloud AI) | ~$0.05/month | Claude Haiku ~200K tokens |
| **Total** | **<$1/month** | Optional services only |

---

## 🎨 Customize Your Sidekick

Caroline learns your vibe during setup. To go deeper:

1. **In another AI** (ChatGPT, Claude), run this prompt:
   > *"I'm setting up a digital sidekick kiosk. Write a concise personality prompt tailored to my workflow and communication style."*

2. **Paste the result** into **Settings → AI → Personality → Imported memory prompt**

3. **Caroline merges** your setup answers + imported memory for a truly personalized sidekick

---

## 📋 System Requirements

**Recommended:**
- Raspberry Pi 4 or 5
- 4GB+ RAM
- 32GB+ microSD card
- 64-bit OS (Raspberry Pi OS Desktop or Ubuntu Server)

**Minimum:**
- 64-bit Linux (Ubuntu, Debian, Raspberry Pi OS)
- 4GB RAM (6-8GB better with Ollama)
- 16GB storage (64GB+ if using local AI)

**Network:**
- Internet during install
- Stable local IP (use DHCP reservation or static IP)

**Avoid:**
- 32-bit OS or systems
- Port-forwarding Caroline ports to the internet

---

## 🔄 Upgrade & Uninstall

**Upgrade:**
```bash
curl -fsSL https://raw.githubusercontent.com/daveeuson/project-caroline/master/install.sh | bash
```
Your settings, API keys, tasks, and memory are preserved.

**Uninstall:**
```bash
curl -fsSL https://raw.githubusercontent.com/daveeuson/project-caroline/master/uninstall.sh | sudo bash
```

---

## 📈 Roadmap

```
v0.1 — Core kiosk, chat, widgets, smart home      [██████████] Done
v0.2 — Agent loop, auto-tasks, installer, CI      [██████████] Done
v0.3 — Tabbed settings, Spotify PKCE, launch      [████████░░] ← You are here
v1.0 — Multi-platform (Windows, Mac, tablet)      [░░░░░░░░░░]
v2.0 — Virtual Sidekick (moods, adaptive)         [░░░░░░░░░░]
```

---

## 🧩 Upcoming Modules

New integrations and features coming to Caroline:

| Module | Purpose | Status |
|---|---|---|
| **Telegram** | Direct messaging & notifications | 🔜 Planned |
| **Nano Leaf** | Smart light panels & ambience | 🔜 Planned |
| **iTunes / Apple Music** | Music control & library sync | 🔜 Planned |
| **Stream Deck** | Physical button integration | 🔜 Planned |
| **Extended Hue Profiles** | Focus, calm, morning, evening, cybercore themes | 🔜 Planned |

### Platform Expansion

Coming soon, Caroline will run on more platforms and devices:

- **Server Platforms:** Windows (native), macOS (native), EC2 & remote servers
- **Display Clients:** Android & iOS native apps (in addition to web browser)
- **Containerization:** Docker support for quick cloud deployment
- **Visual Themes:** Brighter cybercore mode, dark terminal/archive variants, anime-themed UI

### 🎬 Looking for Animators

We're seeking talented animators to help bring Caroline to life! If you're interested in creating custom avatars, idle animations, and character interactions for Project: Caroline, [reach out on GitHub Discussions](https://github.com/DaveEuson/project-caroline/discussions) or contact Dave directly.

---

## 📜 License & Terms

**Source-available public beta** — Not open source (MIT/Apache/GPL).

- ✅ Install, inspect, and modify for personal use
- ✅ Run locally, no restrictions
- ❌ Sell, rebrand, or remove attribution
- ❌ Publish competing packaged derivatives

See [LICENSE](LICENSE) and [NOTICE.md](NOTICE.md) for full terms.

**Copyright © 2026 Dave Euson. All rights reserved.**

---

## 💝 Support Development

Project: Caroline is free. If it makes your desk feel alive and you'd like to support continued development:

→ [Buy me a coffee ☕](https://buymeacoffee.com/daveeuson)

---

## 🔗 Links & More

- **GitHub:** [github.com/daveeuson/project-caroline](https://github.com/daveeuson/project-caroline)
- **Full QA Checklist:** [docs/clean-reinstall-qa.md](docs/clean-reinstall-qa.md)
- **Full Setup Docs:** [docs/](docs/)

---

*Built by Dave Euson*
