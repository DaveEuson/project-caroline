# Caroline Clean Reinstall QA Guide

Use this when you want to wipe a Pi or disposable Linux VM back to a clean Caroline state, reinstall from GitHub, and verify the core release paths.

This guide has two reset levels:

- **Recommended reset:** removes Caroline services, launchers, profiles, app data, and source clone. It leaves shared packages such as Node.js, Node-RED, nginx, Firefox, and Ollama installed.
- **Full package purge:** optional destructive cleanup for disposable QA machines only. Do this only if you are sure those packages are not used by anything else.

## Before You Start

- Confirm you have SSH, Raspberry Pi Connect, or VM console access before enabling kiosk mode.
- Save any local credentials or notes you still need from `~/caroline`.
- Rotate any secrets that may have been used in test installs if the machine was shared or exposed.
- Do not port-forward Caroline ports to the public internet.
- Treat Node-RED and the kiosk as trusted-LAN services. Settings and System controls can save credentials, reboot the device, exit kiosk mode, and launch local diagnostics.

Ports used by Caroline:

| Service | Port |
|---|---:|
| Kiosk web UI | `8080` |
| Node-RED backend | `1880` |
| HTTPS OAuth proxy | `8443` |
| Ollama, when installed | `11434` |

## Quick Clean Reinstall

Run this on the Pi or Linux VM:

```bash
curl -fsSL https://raw.githubusercontent.com/daveeuson/project-caroline/master/uninstall.sh | sudo bash -s -- --yes
curl -fsSL https://raw.githubusercontent.com/daveeuson/project-caroline/master/install.sh | bash
sudo reboot
```

After reboot, open:

```text
http://<pi-or-vm-ip>:8080/
```

## Interactive Uninstall

Use this when you want the safety prompt:

```bash
curl -fsSL https://raw.githubusercontent.com/daveeuson/project-caroline/master/uninstall.sh | sudo bash
```

Type exactly:

```text
UNINSTALL CAROLINE
```

## Keep Data But Remove Services

Use this if you want to preserve `~/caroline` while removing services and launchers:

```bash
curl -fsSL https://raw.githubusercontent.com/daveeuson/project-caroline/master/uninstall.sh | sudo bash -s -- --keep-data
```

## Verify Uninstall

After uninstall, these should be gone:

```bash
systemctl status caroline
ls -ld ~/caroline ~/project-caroline
ls ~/.config/autostart/caroline-kiosk.desktop
ls ~/Desktop/"Project Caroline.desktop" ~/Desktop/"Project Caroline Kiosk.desktop"
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
sudo apt-get purge -y nodejs npm nginx firefox firefox-esr

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
command -v firefox || true
command -v firefox-esr || true
command -v ollama || true
```

If these commands print no paths, the package purge is clean enough for installer QA.

## Fresh Install Checklist

Run:

```bash
curl -fsSL https://raw.githubusercontent.com/daveeuson/project-caroline/master/install.sh | bash
```

During install, record:

- OS and version.
- CPU architecture from `uname -m`.
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
curl -s http://localhost:1880/health
ls -l ~/caroline/index.html ~/caroline/flows.json ~/caroline/caroline_settings.json
```

Expected:

- `caroline` service is active.
- `nginx` service is active.
- `http://localhost:8080/` returns an HTTP response.
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

## Reboot And Kiosk QA

After install:

```bash
sudo reboot
```

After reboot:

- Caroline web UI still loads on port `8080`.
- `caroline` service restarted.
- `nginx` service restarted.
- Desktop shortcuts exist on Raspberry Pi OS Desktop.
- Kiosk autostart works if kiosk mode was enabled.
- SSH or Raspberry Pi Connect still works for recovery.

## Upgrade QA

Rerun the installer:

```bash
curl -fsSL https://raw.githubusercontent.com/daveeuson/project-caroline/master/install.sh | bash
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

## Release Gate

Do not call the clean reinstall good until these pass:

- Fresh install from public `curl` command.
- Reboot survival.
- Settings save/reload.
- Widget persistence.
- Task add/complete.
- Calendar setup error path or real Google Calendar add/delete path.
- Upgrade over existing install.
- Uninstall and reinstall.
- Recovery access confirmed before kiosk mode.
