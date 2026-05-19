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
curl -fsSL https://raw.githubusercontent.com/Project-Caroline/project-caroline/release/install.sh | bash
```

A tagged release can be installed by replacing `release` with the tag and passing the channel:

```bash
curl -fsSL https://raw.githubusercontent.com/Project-Caroline/project-caroline/v0.3.0-beta.3/install.sh | bash -s -- --channel v0.3.0-beta.3
```

## Release Checklist

1. Run GitHub Actions **Release Readiness** and **Secret Scan** on `nightly`.
2. Run a clean Ubuntu Server install in server/client mode.
3. Run a clean Raspberry Pi OS Desktop install with kiosk mode.
4. Verify update, uninstall, reboot, settings save, Hue discovery, Spotify redirect, Google OAuth import, and system widgets.
5. Bump `CAROLINE_VERSION` in `install.sh` from `0.3.0-dev` to the release version.
6. Commit the version bump.
7. Merge or fast-forward `release` to the tested `nightly` commit:

```bash
git switch release
git merge --ff-only nightly
git push origin release
```

8. Create and push an annotated tag from `release`:

```bash
git tag -a v0.3.0-beta.3 -m "Project: Caroline v0.3.0 beta 3"
git push origin release v0.3.0-beta.3
```

9. Create a GitHub Release from the tag with short notes and known limitations.
10. After release, bump `CAROLINE_VERSION` back to the next `-dev` version on `nightly`.

## Ubuntu Release Focus

For Ubuntu, the recommended release path is Ubuntu Server 64-bit in server/client mode. Choose **No** for kiosk mode, keep the Caroline host on a stable LAN IP, and open Caroline from another browser at:

```text
http://<ubuntu-ip>:8080/
```

Use `https://<ubuntu-ip>:8444/` for browser microphone and wake-word testing after accepting the local self-signed certificate.
