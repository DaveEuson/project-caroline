# Caroline Clean Reinstall QA Guide

Use this when you want to wipe a Pi or disposable Linux VM back to a clean Caroline state, reinstall from GitHub, and verify the core release paths. For Ubuntu VM testing, the recommended setup is Ubuntu Server with Caroline opened from an external browser.

This guide has two reset levels:

- **Recommended reset:** removes Caroline services, launchers, profiles, app data, and source clone. It leaves shared packages such as Node.js, Node-RED, nginx, Chromium/Firefox, and Ollama installed.
- **Full package purge:** optional destructive cleanup for disposable QA machines only. Do this only if you are sure those packages are not used by anything else.

## Before You Start

- Confirm you have SSH, Raspberry Pi Connect, or VM console access before enabling kiosk mode.
- For Ubuntu VM QA, use Ubuntu Server 64-bit when possible, choose **No** for kiosk mode, and open Caroline from another machine at `http://<vm-ip>:8080/`. If you enable local browser login, log in as `caroline`; the installer prints the password file path.
- Ubuntu Desktop VM is validated for server/client mode from another browser. Use local fullscreen kiosk behavior only when you specifically want to test that desktop path.
- For Ubuntu Desktop VM local AI QA, allocate about 50GB of disk before installing Ollama. CPU-only Ollama with `qwen2.5:1.5b` is validated; 12GB images are too small after OS and runtime packages.
- Ubuntu-based distributions such as Pop!_OS, Linux Mint, Zorin OS, and elementary OS are expected to work best in server/client mode, but treat them as unverified until install, reboot, update, and integration checks pass.
- For Ubuntu Server, VM, or server/client installs, give the Caroline host a stable local IP. A router DHCP reservation is recommended because it keeps setup simple; a manual static IP also works if you know your network settings.
- Save any local credentials or notes you still need from `~/caroline`.
- Rotate any secrets that may have been used in test installs if the machine was shared or exposed.
- Do not port-forward Caroline ports to the public internet.
- Treat Node-RED and the kiosk as trusted-LAN services. Settings and System controls can save credentials, reboot the device, exit kiosk mode, and launch local diagnostics.

Ports used by Caroline:

| Service | Port |
|---|---:|
| Kiosk web UI | `8080` |
| Node-RED backend | `1880` localhost only |
| HTTPS OAuth proxy | `8443` |
| Secure voice UI | `8444` |
| Ollama, when installed | `11434` localhost only |

## Quick Clean Reinstall

Run this on the Pi or Linux VM:

```bash
curl -fsSL https://raw.githubusercontent.com/Project-Caroline/project-caroline/release/uninstall.sh | tr -d '\r' | sudo bash -s -- --yes
curl -fsSL https://raw.githubusercontent.com/Project-Caroline/project-caroline/release/install.sh | tr -d '\r' | bash -s --
sudo reboot
```

To force Caroline's optional local browser login off during reinstall:

```bash
curl -fsSL https://raw.githubusercontent.com/Project-Caroline/project-caroline/release/install.sh | tr -d '\r' | CAROLINE_LOCAL_AUTH=false bash -s --
```

After reboot, open:

```text
http://<pi-or-vm-ip>:8080/
```

If you enabled Caroline's optional local browser login, username is `caroline`; on the Caroline host, view the generated password with:

```bash
cat ~/caroline/caroline_admin_password.txt
```

On an Ubuntu Server VM, open that URL from your Windows/macOS/Linux host browser. The VM does not need to run a local GUI. The installer prints the exact client URL at the end:

```text
From another device: http://<vm-ip>:8080/
```

## Server/Client Mode Expectations

Use this path for Ubuntu Server, Proxmox/Hyper-V/VirtualBox VMs, Ubuntu-based desktop distributions, or any Linux box that should host Caroline without running a local kiosk browser.

Before connecting integrations, reserve a stable IP for the Caroline host if this install will be used beyond one test session. A DHCP reservation in your router is the best default. A static IP inside Ubuntu is fine for advanced setups. If the IP changes later, open Caroline at the new URL and update any integration redirect URLs that include the old address.

Expected to work from the external client browser:

- First-run setup and Settings save/reload.
- Chat through OpenRouter or Ollama running on the Caroline host.
- Local Ollama with `qwen2.5:1.5b` on a 50GB Ubuntu Desktop VM in server/client mode.
- Ollama on another LAN machine if **Settings -> AI -> Ollama URL** points to it.
- Weather, timezone, news, video, radio, Pomodoro, local tasks, calendar, Spotify, Hue, Discord, update, reboot, and CPU/RAM monitor.
- Google and Spotify setup, as long as the browser can reach the VM on ports `8080` and `8443`.
- Spotify may need you to open `https://<vm-ip>:8443/` once and accept Caroline's local self-signed certificate before the OAuth callback can complete.
- Browser microphone and wake-word input in Chrome/Chromium from `https://<vm-ip>:8444/` after accepting Caroline's local self-signed certificate.

Expected limitations in server/client mode:

- Boot-to-kiosk, local terminal launch, and exit-kiosk controls only make sense on a desktop/kiosk host.
- Browser microphone and wake-word input usually will not work from `http://<vm-ip>:8080/` because browsers require HTTPS or localhost for mic access. Use `https://<vm-ip>:8444/` for voice. Type/chat still works normally on HTTP.
- VM NAT networking may need port forwarding for `8080`, `8443`, and `8444`; bridged networking is easier for QA.

## Interactive Uninstall

Use this when you want the safety prompt:

```bash
curl -fsSL https://raw.githubusercontent.com/Project-Caroline/project-caroline/release/uninstall.sh | tr -d '\r' | sudo bash -s --
```

Type exactly:

```text
UNINSTALL CAROLINE
```

## Keep Data But Remove Services

Use this if you want to preserve `~/caroline` while removing services and launchers:

```bash
curl -fsSL https://raw.githubusercontent.com/Project-Caroline/project-caroline/release/uninstall.sh | tr -d '\r' | sudo bash -s -- --keep-data
```

## Verify Uninstall

After uninstall, these should be gone:

```bash
systemctl status caroline
ls -ld ~/caroline ~/project-caroline
ls ~/.config/autostart/caroline-kiosk.desktop
ls ~/Desktop/"Project: Caroline.desktop" ~/Desktop/"Project: Caroline Kiosk.desktop"
```

Expected results:

- `caroline.service` is not found or inactive.
- `~/caroline` is gone unless you used `--keep-data`.
- `~/project-caroline` is gone unless you used `--keep-data`.
- Caroline desktop/autostart launchers are gone.

## Optional Full Package Purge

Use this only on a disposable QA Pi or VM. It removes shared runtime packages that may be used by other projects.

```bash
sudo systemctl stop caroline nginx ollama 2>/dev/null || true
sudo systemctl disable caroline nginx ollama 2>/dev/null || true

sudo npm uninstall -g node-red 2>/dev/null || true
sudo apt-get purge -y nodejs npm nginx chromium chromium-browser firefox firefox-esr

sudo rm -f /usr/local/bin/ollama
sudo rm -f /etc/systemd/system/ollama.service
sudo rm -rf /usr/share/ollama /var/lib/ollama /etc/systemd/system/ollama.service.d

sudo apt-get autoremove -y
sudo apt-get autoclean
sudo systemctl daemon-reload
```

Then verify:

```bash
command -v node || true
command -v npm || true
command -v node-red || true
command -v nginx || true
command -v chromium || true
command -v chromium-browser || true
command -v firefox || true
command -v firefox-esr || true
command -v ollama || true
```

If these commands print no paths, the package purge is clean enough for installer QA.

## Fresh Install Checklist

Run:

```bash
curl -fsSL https://raw.githubusercontent.com/Project-Caroline/project-caroline/release/install.sh | tr -d '\r' | bash -s --
```

During install, record:

- OS and version.
- CPU architecture from `uname -m`.
- GPU from `nvidia-smi --query-gpu=name,memory.total --format=csv,noheader` when NVIDIA is available, otherwise `lspci | grep -Ei 'vga|3d|display'`.
- RAM from `free -h`.
- Whether you selected kiosk mode.
- Whether you installed Ollama.
- Any warning messages from the installer.

## Post-Install Verification

Run:

```bash
systemctl status caroline --no-pager
systemctl status nginx --no-pager
curl -I http://localhost:8080/
curl -s http://localhost:8080/health
# If local browser login is enabled instead:
curl -s -u "caroline:$(cat ~/caroline/caroline_admin_password.txt)" http://localhost:8080/health
curl -k -I https://localhost:8444/
ls -l ~/caroline/index.html ~/caroline/flows.json ~/caroline/caroline_settings.json
```

Expected:

- `caroline` service is active.
- `nginx` service is active.
- `http://localhost:8080/` returns an HTTP response, or `401 Unauthorized` without credentials if optional local browser login is enabled.
- `http://localhost:8080/health` returns Caroline's backend health JSON through nginx.
- `https://localhost:8444/` returns an HTTPS response with `curl -k`, or `401 Unauthorized` without credentials if optional local browser login is enabled.
- `~/caroline/caroline_settings.json` exists and is owned by your user.

## Browser QA Checklist

Open Caroline at:

```text
http://<pi-or-vm-ip>:8080/
```

Check:

- First-run boot sequence appears on a clean install.
- Settings opens and closes.
- Settings save works.
- Node-RED URL test passes.
- Widget toggles persist after reload.
- Time format persists after reload.
- Temperature unit persists after reload.
- OpenRouter key field can be saved without displaying the key later.
- Ollama provider can be selected.
- Hue IP/key fields can be saved without displaying the key later.
- Spotify Client ID field saves and shows the correct redirect URI.
- Google OAuth JSON import rejects service-account JSON and accepts Desktop OAuth JSON.
- Tasks can be added manually.
- Chat can add a task.
- Chat can complete a task.
- Calendar refresh gives a clear setup message if Google is not connected.
- Meeting reminders are off by default; if enabled, a timed calendar event within the reminder window speaks/shows one heads-up and does not repeat.

## Reboot And Kiosk QA

After install:

```bash
sudo reboot
```

After reboot:

- Caroline web UI still loads on port `8080`.
- `caroline` service restarted.
- `nginx` service restarted.
- Desktop shortcuts exist on Raspberry Pi OS Desktop or Ubuntu Desktop if a desktop environment was used.
- Kiosk autostart works if kiosk mode was enabled on a desktop environment.
- Raspberry Pi kiosk opens in Chromium when available; Firefox fallback is typing/chat only for voice purposes.
- Ubuntu Server VM remains reachable from an external browser at `http://<vm-ip>:8080/`.
- SSH or Raspberry Pi Connect still works for recovery.

## Upgrade QA

Rerun the installer:

```bash
curl -fsSL https://raw.githubusercontent.com/Project-Caroline/project-caroline/release/install.sh | tr -d '\r' | bash -s --
```

Check:

- Existing `caroline_settings.json` is backed up.
- Saved settings are preserved.
- API key fields still show saved/configured status without exposing values.
- Services restart cleanly.
- Browser reload shows the updated UI.

## Logs To Collect For Bugs

```bash
sudo journalctl -u caroline --since today --no-pager
sudo journalctl -u nginx --since today --no-pager
cat /tmp/caroline-apt-update.log 2>/dev/null || true
cat /tmp/caroline-apt-install.log 2>/dev/null || true
cat /tmp/caroline-npm.log 2>/dev/null || true
cat /tmp/caroline-git.log 2>/dev/null || true
cat /tmp/caroline-ollama.log 2>/dev/null || true
```

When reporting a bug, include:

- Pi model or VM type.
- OS version.
- `uname -m`.
- Whether this was fresh install, upgrade, or reinstall.
- The exact installer choice path.
- Browser used.
- Relevant log snippets.

## Ubuntu Browser Already Running Dialog

If Ubuntu shows `Firefox is already running, but is not responding`, or Chromium refuses to open after kiosk autostart, clear the stale Caroline browser lock and rerun the installer:

```bash
pkill -f 'firefox.*caroline' 2>/dev/null || true
pkill -f 'chromium.*caroline' 2>/dev/null || true
pkill -f 'chrome.*caroline' 2>/dev/null || true
rm -rf "/tmp/caroline-kiosk-$(id -u).lock"
rm -f ~/.mozilla/firefox/caroline-kiosk/parent.lock ~/.mozilla/firefox/caroline-kiosk/lock ~/.mozilla/firefox/caroline-kiosk/.parentlock
rm -rf ~/.config/caroline/chromium-kiosk ~/.config/caroline/chromium-window
rm -f ~/.local/bin/caroline-window ~/.local/bin/caroline-kiosk
curl -fsSL https://raw.githubusercontent.com/Project-Caroline/project-caroline/release/install.sh | tr -d '\r' | bash -s --
sudo reboot
```

For Ubuntu QA, the validated server/client path is to keep kiosk mode off and open Caroline from an external browser at `http://<vm-ip>:8080/`. Ubuntu Desktop VM local AI is validated with a 50GB disk and CPU-only Ollama using `qwen2.5:1.5b`. Only rerun the installer to enable kiosk autostart if you intentionally want to test Ubuntu Desktop fullscreen behavior.

## Release Gate

Do not call the clean reinstall good until these pass:

- Fresh install from public `curl` command.
- Reboot survival.
- Settings save/reload.
- Settings > System Check shows no failures; optional integrations may show notes when intentionally disconnected.
- Widget persistence.
- Task add/complete.
- Calendar setup error path or real Google Calendar add/delete path.
- Upgrade over existing install.
- Uninstall and reinstall.
- Recovery access confirmed before kiosk mode.
