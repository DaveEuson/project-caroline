# Contributing to Project: Caroline

Thanks for wanting to make Caroline better. Here's what you need to know.

## Ground Rules

- **Privacy first.** No telemetry, tracking, or phoning home — ever. Don't add features that send user data anywhere without explicit opt-in.
- **Single-file frontend.** `caroline-kiosk.html` is one file on purpose. Keep it that way.
- **No Docker.** Node-RED runs as a bare-metal systemd service. Don't add container dependencies.
- **The WebSocket ID `f3e0e445bed3987b` is sacred.** Changing it breaks every existing install. Don't touch it.

## How to Contribute

1. Fork the repo and create a feature branch: `git checkout -b feature/your-thing`
2. Make your changes. Test on a Pi if possible — that's the target hardware.
3. Run the secret scanner: `gitleaks detect --no-git` before committing. No API keys in code.
4. Open a pull request with a clear description of what changed and why.

## What We Welcome

- New widgets for the left panel
- Additional Node-RED flow modules (optional add-ons)
- Installer improvements and broader OS support
- Bug fixes with reproduction steps
- Documentation and translation improvements

## What We Don't Want

- Features that require cloud accounts as a hard dependency
- Changes to the WebSocket node ID or core flow structure
- Anything that adds a runtime Docker/container requirement
- Hardcoded API keys, credentials, or test tokens

## Reporting Bugs

Open an issue at [github.com/daveeuson/project-caroline/issues](https://github.com/daveeuson/project-caroline/issues) with:
- What happened vs. what you expected
- Pi model and OS version
- Relevant logs: `sudo journalctl -u caroline --since today`

## Questions

Start a Discussion on GitHub — not an issue.
