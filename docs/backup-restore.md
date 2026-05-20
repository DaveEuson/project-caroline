# Backup And Restore

Use this before major updates, reinstall tests, SD-card swaps, or moving Caroline to another host.

Caroline's important local state lives in:

```text
~/caroline
```

The repo cache at `~/project-caroline` can be recreated by the installer and normally does not need to be backed up.

## Sensitive Files

Treat backups as private. Do not attach them to GitHub issues or bug reports.

These files may contain API keys, OAuth tokens, private memory, personal calendar state, or local passwords:

- `caroline_settings.json`
- `google_oauth.json`
- `spotify_auth.json`
- `caroline-calendar.json`
- `service-account.json`
- `caroline_history.json`
- `caroline_context.json`
- `caroline_tasks.json`
- `caroline_mind.json`
- `caroline_feedback.jsonl`
- `caroline_telemetry.jsonl`
- `caroline_admin_password.txt`
- `.credential_secret`

## State-Only Backup

This is the recommended backup. It saves settings, credentials, memory, tasks, and build/channel metadata without copying generated dependencies.

Run on the Caroline host:

```bash
mkdir -p ~/caroline-backups
backup="$HOME/caroline-backups/caroline-state-$(date +%Y%m%d-%H%M%S).tgz"
cd ~/caroline
files=(
  caroline_settings.json
  google_oauth.json
  spotify_auth.json
  caroline-calendar.json
  service-account.json
  caroline_history.json
  caroline_context.json
  caroline_tasks.json
  caroline_mind.json
  caroline_feedback.jsonl
  caroline_telemetry.jsonl
  caroline_admin_password.txt
  caroline_build.json
  caroline_channel
  .credential_secret
)
existing=()
for file in "${files[@]}"; do
  [ -e "$file" ] && existing+=("$file")
done
tar -czf "$backup" "${existing[@]}"
chmod 600 "$backup"
echo "$backup"
```

## Full Folder Backup

Use this if you want an emergency snapshot of the whole installed app folder. It excludes the large generated Node-RED dependency folder used by SteamOS.

```bash
mkdir -p ~/caroline-backups
tar \
  --exclude='caroline/node-red-runtime/node_modules' \
  --exclude='caroline/.config.nodes.json' \
  --exclude='caroline/.config.runtime.json' \
  -czf "$HOME/caroline-backups/caroline-full-$(date +%Y%m%d-%H%M%S).tgz" \
  -C "$HOME" caroline
```

## Restore On Raspberry Pi Or Ubuntu

1. Install Caroline first, or make sure `~/caroline` exists.
2. Stop the services:

```bash
sudo systemctl stop caroline nginx
```

3. Restore the backup:

```bash
tar -xzf ~/caroline-backups/caroline-state-YYYYMMDD-HHMMSS.tgz -C ~/caroline
chmod 600 \
  ~/caroline/caroline_settings.json \
  ~/caroline/google_oauth.json \
  ~/caroline/spotify_auth.json \
  ~/caroline/caroline-calendar.json \
  ~/caroline/service-account.json \
  ~/caroline/caroline_history.json \
  ~/caroline/caroline_context.json \
  ~/caroline/caroline_tasks.json \
  ~/caroline/caroline_mind.json \
  ~/caroline/caroline_feedback.jsonl \
  ~/caroline/caroline_telemetry.jsonl \
  ~/caroline/caroline_admin_password.txt \
  ~/caroline/caroline_channel \
  ~/caroline/.credential_secret 2>/dev/null || true
```

4. Start the services:

```bash
sudo systemctl start caroline nginx
```

5. Verify:

```bash
curl -fsS http://localhost:8080/health
```

## Restore On Steam Deck

SteamOS uses a user service instead of the system service:

```bash
systemctl --user stop caroline
tar -xzf ~/caroline-backups/caroline-state-YYYYMMDD-HHMMSS.tgz -C ~/caroline
chmod 600 \
  ~/caroline/caroline_settings.json \
  ~/caroline/google_oauth.json \
  ~/caroline/spotify_auth.json \
  ~/caroline/caroline_history.json \
  ~/caroline/caroline_context.json \
  ~/caroline/caroline_tasks.json \
  ~/caroline/caroline_mind.json \
  ~/caroline/caroline_feedback.jsonl \
  ~/caroline/caroline_telemetry.jsonl \
  ~/caroline/caroline_channel \
  ~/caroline/.credential_secret 2>/dev/null || true
systemctl --user start caroline
curl -fsS http://127.0.0.1:8080/health
```

## Safe Bug Report Diagnostics

For bug reports, prefer summaries over raw files:

```bash
curl -fsS http://localhost:8080/health
sudo journalctl -u caroline -n 120 --no-pager
sudo journalctl -u nginx -n 80 --no-pager
```

Before sharing logs, remove API keys, OAuth tokens, private calendar details, passwords, and personal memory content.
