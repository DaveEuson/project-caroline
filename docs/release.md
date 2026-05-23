# Project: Caroline Release Process

Use this when promoting Project: Caroline from the moving `nightly` branch to a public beta/stable release.

## Channels

| Channel | Source | Use |
|---|---|---|
| Nightly/dev | `nightly` branch | Latest tested fixes and experiments |
| Release | `release` branch | Recommended public install |
| Frozen tag | GitHub release tag, for example `v0.3.0-beta.3` | Exact archived build |

The regular install command follows `release`:

```bash
curl -fsSL https://raw.githubusercontent.com/Project-Caroline/project-caroline/release/install.sh | tr -d '\r' | bash -s --
```

A tagged release can be installed by replacing `release` with the tag and passing the channel:

```bash
curl -fsSL https://raw.githubusercontent.com/Project-Caroline/project-caroline/v0.3.0-beta.3/install.sh | tr -d '\r' | bash -s -- --channel v0.3.0-beta.3
```

## Release Checklist

Use this checklist before promoting `nightly` to `release`.

### 1. Prepare The Notes

1. Update [Unreleased](releases/unreleased.md).
2. Move the unreleased notes into a versioned file, for example `docs/releases/v0.3.0-beta.4.md`.
3. Update [Release notes](releases/README.md) so the new file appears under Published Notes.
4. Keep `Known Issues` honest. It is better to name a limitation than let users discover it cold.

### 2. Run Local Sanity Checks

Run these from the repo root:

```bash
node -e "JSON.parse(require('fs').readFileSync('flows.json','utf8'))"
bash -n install.sh
bash -n install-steamos.sh
bash -n uninstall.sh
node --test tests/command-language.test.js
```

If the companion app changed, run this from the companion worktree:

```bash
npm install --no-audit --no-fund
npm run build
```

Remove generated `node_modules` or `dist` folders from the worktree before committing unless the package intentionally tracks them.

### 3. Run GitHub Checks

1. Run GitHub Actions **Release Readiness** on `nightly`.
2. Run GitHub Actions **Secret Scan** on `nightly`.
3. Confirm there are no unexpected files in `git status --short`.

### 4. Device QA Matrix

| Target | Required Check |
|---|---|
| Raspberry Pi OS Desktop | Fresh install, kiosk launch, update from previous build, `/health`, Settings save, Settings > System Check |
| Ubuntu Server | Fresh server/client install, browser access from another device, update, `/health`, Settings > System Check |
| Ubuntu Desktop or Pop!_OS | Install or update if touched, browser access, Settings > System Check, companion profile if relevant; Ubuntu Desktop VM server/client mode is validated with 50GB disk, CPU-only Ollama, and `qwen2.5:1.5b` |
| Steam Deck / SteamOS | Nightly install or update, local `http://localhost:8080/`, update status, Settings > System Check, companion SSH tunnel |
| Companion app | Build installer artifacts, connect to Caroline/Pi and Carl/Deck profiles |

Current smoke-validated hosts:

- Raspberry Pi OS Desktop kiosk: use the stable Pi IP and confirm `/system-resources` stays reasonable after the kiosk settles.
- Steam Deck / SteamOS: use the stable LAN IP for smoke runs; `steamdeck` mDNS can be slower or flaky from Windows.
- Ubuntu Desktop VM: validated for server/client mode with 50GB disk and CPU-only Ollama, but rerun smoke after confirming the VM is reachable on the LAN.

Useful health checks:

```bash
curl -fsS http://DEVICE-IP:8080/health
curl -fsS http://DEVICE-IP:8080/admin/update/status
```

For Steam Deck over SSH:

```bash
curl -fsS http://127.0.0.1:8080/health
curl -fsS http://127.0.0.1:8080/admin/update/status
```

### 5. Feature Smoke Test

Run the parts touched by the release:

1. Chat reply from the selected AI provider.
2. Calendar read and calendar add, if Google changed.
3. Local task add and complete.
4. Memory save and memory delete.
5. Hue on/off if Hue changed.
6. Spotify OAuth or playback controls if Spotify changed.
7. Companion WebSocket connect/disconnect if companion changed.
8. Update button and status endpoint.
9. Reboot/exit-kiosk controls if system controls changed.

### 6. Version And Promote

1. Bump `CAROLINE_VERSION` in `install.sh` and `install-steamos.sh` to the release version.
2. Commit the version bump and release-note changes.
3. Merge or fast-forward `release` to the tested `nightly` commit:

```bash
git switch release
git merge --ff-only nightly
git push origin release
```

4. Create and push an annotated tag from `release`:

```bash
git tag -a v0.3.0-beta.3 -m "Project: Caroline v0.3.0 beta 3"
git push origin release v0.3.0-beta.3
```

5. Create a GitHub Release from the tag with short notes and known limitations.
6. After release, bump `CAROLINE_VERSION` back to the next `-dev` version on `nightly` if that is the branch policy for the next cycle.

## Rollback

If a release goes bad, reinstall the last known-good tag:

```bash
curl -fsSL https://raw.githubusercontent.com/Project-Caroline/project-caroline/v0.3.0-beta.3/install.sh | tr -d '\r' | bash -s -- --channel v0.3.0-beta.3
```

For SteamOS, use the SteamOS installer from a known-good commit or tag:

```bash
curl -fsSL https://raw.githubusercontent.com/Project-Caroline/project-caroline/nightly/install-steamos.sh | tr -d '\r' | CAROLINE_CHANNEL=nightly bash -s --
```

If user state may be at risk, create a backup first. See [Backup and restore](backup-restore.md).

## Ubuntu Release Focus

For Ubuntu, the recommended release path is Ubuntu Server 64-bit in server/client mode. Choose **No** for kiosk mode, keep the Caroline host on a stable LAN IP, and open Caroline from another browser at:

```text
http://<ubuntu-ip>:8080/
```

Use `https://<ubuntu-ip>:8444/` for browser microphone and wake-word testing after accepting the local self-signed certificate.
