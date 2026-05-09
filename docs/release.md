# Project Caroline Release Process

Use this when promoting Caroline from the moving `master` branch to a public beta/stable release.

## Channels

| Channel | Source | Use |
|---|---|---|
| Nightly/dev | `master` branch | Latest fixes and experiments |
| Stable/beta | GitHub release tag, for example `v0.3.0-beta.1` | Recommended public install |

The regular install command follows `master`:

```bash
curl -fsSL https://raw.githubusercontent.com/Project-Caroline/project-caroline/master/install.sh | bash
```

A tagged release can be installed by replacing `master` with the tag:

```bash
curl -fsSL https://raw.githubusercontent.com/Project-Caroline/project-caroline/v0.3.0-beta.1/install.sh | bash
```

## Release Checklist

1. Run GitHub Actions **Release Readiness** and **Secret Scan** on `master`.
2. Run a clean Ubuntu Server install in server/client mode.
3. Run a clean Raspberry Pi OS Desktop install with kiosk mode.
4. Verify update, uninstall, reboot, settings save, Hue discovery, Spotify redirect, Google OAuth import, and system widgets.
5. Bump `CAROLINE_VERSION` in `install.sh` from `0.3.0-dev` to the release version.
6. Commit the version bump.
7. Create and push an annotated tag:

```bash
git tag -a v0.3.0-beta.1 -m "Project Caroline v0.3.0 beta 1"
git push origin master v0.3.0-beta.1
```

8. Create a GitHub Release from the tag with short notes and known limitations.
9. After release, bump `CAROLINE_VERSION` back to the next `-dev` version on `master`.

## Ubuntu Release Focus

For Ubuntu, the recommended release path is Ubuntu Server 64-bit in server/client mode. Choose **No** for kiosk mode, keep the Caroline host on a stable LAN IP, and open Caroline from another browser at:

```text
http://<ubuntu-ip>:8080/
```

Use `https://<ubuntu-ip>:8444/` for browser microphone and wake-word testing after accepting the local self-signed certificate.
