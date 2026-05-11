#!/usr/bin/env bash
set -Eeuo pipefail

# Project: Caroline experimental SteamOS installer.
# This intentionally avoids pacman/system package installs and does not disable
# SteamOS read-only mode. Everything lives under the deck user's home directory.

CAROLINE_VERSION="0.3.0-beta.2"
CAROLINE_REPO_URL="${CAROLINE_REPO_URL:-https://github.com/Project-Caroline/project-caroline.git}"
CAROLINE_CHANNEL="${CAROLINE_CHANNEL:-nightly}"
CAROLINE_PORT="${CAROLINE_PORT:-8080}"
NODE_MAJOR="${CAROLINE_STEAMOS_NODE_MAJOR:-22}"

CYAN="\033[36m"
MAGENTA="\033[35m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
BOLD="\033[1m"
DIM="\033[2m"
RESET="\033[0m"

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME="$(eval echo "~$REAL_USER")"
CAROLINE_DIR="$REAL_HOME/caroline"
CLONE_DIR="$REAL_HOME/project-caroline"
NODE_ROOT="$REAL_HOME/.local/caroline-node"
NODE_CURRENT="$NODE_ROOT/current"
NODERED_RUNTIME="$CAROLINE_DIR/node-red-runtime"
export CAROLINE_DIR

say() { echo -e "$*"; }
need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    say "${RED}  x Missing required command: $1${RESET}"
    exit 1
  fi
}

is_steamos() {
  [ -r /etc/os-release ] && . /etc/os-release && [ "${ID:-}" = "steamos" ]
}

if ! is_steamos; then
  say "${RED}This experimental installer is only for SteamOS.${RESET}"
  say "${DIM}Use install.sh for Raspberry Pi OS, Ubuntu, or Debian.${RESET}"
  exit 1
fi

need_cmd curl
need_cmd git
need_cmd tar
need_cmd sed
need_cmd systemctl

ARCH="$(uname -m)"
case "$ARCH" in
  x86_64|amd64) NODE_ARCH="x64" ;;
  *) say "${RED}Unsupported SteamOS CPU architecture: ${ARCH}${RESET}"; exit 1 ;;
esac

say ""
say "${CYAN}  ____            _           _        ____                 _ _            ${RESET}"
say "${CYAN} |  _ \\ _ __ ___ (_) ___  ___| |_     / ___|__ _ _ __ ___ | (_)_ __   ___ ${RESET}"
say "${MAGENTA} | |_) | '__/ _ \\| |/ _ \\/ __| __|   | |   / _\` | '__/ _ \\| | | '_ \\ / _ \\${RESET}"
say "${MAGENTA} |  __/| | | (_) | |  __/ (__| |_    | |__| (_| | | | (_) | | | | | |  __/${RESET}"
say "${CYAN} |_|   |_|  \\___// |\\___|\\___|\\__|    \\____\\__,_|_|  \\___/|_|_|_| |_|\\___|${RESET}"
say "${CYAN}              |__/                                                        ${RESET}"
say ""
say "${BOLD}${CYAN}  Project: Caroline${RESET} ${DIM}SteamOS experimental installer v${CAROLINE_VERSION}${RESET}"
say "${DIM}  Home-directory install. No pacman installs. No SteamOS read-only changes.${RESET}"
say ""

say "${MAGENTA}  // STEAMOS PREFLIGHT${RESET}"
. /etc/os-release
say "${DIM}  OS: ${PRETTY_NAME:-SteamOS} ${VERSION_ID:-unknown}${RESET}"
say "${DIM}  Arch: ${ARCH}${RESET}"
if command -v steamos-readonly >/dev/null 2>&1; then
  READONLY_STATUS="$(steamos-readonly status 2>/dev/null || true)"
  say "${DIM}  SteamOS readonly: ${READONLY_STATUS:-unknown}${RESET}"
fi
say ""

say "${MAGENTA}  // PORTABLE NODE.JS${RESET}"
mkdir -p "$NODE_ROOT"
if [ ! -x "$NODE_CURRENT/bin/node" ] || [ ! -x "$NODE_CURRENT/bin/npm" ]; then
  NODE_BASE_URL="https://nodejs.org/dist/latest-v${NODE_MAJOR}.x"
  say "${YELLOW}  > Finding latest Node ${NODE_MAJOR}.x build...${RESET}"
  NODE_VERSION="$(
    curl -fsSL "$NODE_BASE_URL/SHASUMS256.txt" |
      sed -n "s/^.*  node-\\(v[0-9.]*\\)-linux-${NODE_ARCH}\\.tar\\.xz$/\\1/p" |
      head -1
  )"
  if [ -z "$NODE_VERSION" ]; then
    say "${RED}  x Could not resolve Node ${NODE_MAJOR}.x for linux-${NODE_ARCH}.${RESET}"
    exit 1
  fi
  NODE_TARBALL="node-${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz"
  TMP_NODE="/tmp/${NODE_TARBALL}"
  say "${YELLOW}  > Downloading ${NODE_TARBALL}...${RESET}"
  curl -fsSL "$NODE_BASE_URL/$NODE_TARBALL" -o "$TMP_NODE"
  rm -rf "$NODE_ROOT/node-${NODE_VERSION}-linux-${NODE_ARCH}"
  tar -C "$NODE_ROOT" -xf "$TMP_NODE"
  ln -sfn "$NODE_ROOT/node-${NODE_VERSION}-linux-${NODE_ARCH}" "$NODE_CURRENT"
fi
export PATH="$NODE_CURRENT/bin:$PATH"
say "${GREEN}  ✓ Node $(node --version) ready at ${NODE_CURRENT}${RESET}"
say "${GREEN}  ✓ npm $(npm --version) ready${RESET}"
say ""

say "${MAGENTA}  // PROJECT FILES${RESET}"
if [ -d "$CLONE_DIR/.git" ]; then
  say "${DIM}  Existing repo found; syncing ${CAROLINE_CHANNEL}.${RESET}"
  git -C "$CLONE_DIR" remote set-url origin "$CAROLINE_REPO_URL" >/dev/null 2>&1 || true
  git -C "$CLONE_DIR" fetch --tags origin
else
  git clone --no-checkout "$CAROLINE_REPO_URL" "$CLONE_DIR"
fi

if git -C "$CLONE_DIR" show-ref --verify --quiet "refs/remotes/origin/${CAROLINE_CHANNEL}"; then
  git -C "$CLONE_DIR" checkout -B "$CAROLINE_CHANNEL" "origin/${CAROLINE_CHANNEL}"
elif git -C "$CLONE_DIR" show-ref --verify --quiet "refs/tags/${CAROLINE_CHANNEL}"; then
  git -C "$CLONE_DIR" checkout --detach "refs/tags/${CAROLINE_CHANNEL}"
else
  say "${RED}  x Channel not found: ${CAROLINE_CHANNEL}${RESET}"
  exit 1
fi

mkdir -p "$CAROLINE_DIR"
rm -rf "$CAROLINE_DIR/.git"
tar --exclude='./.git' -C "$CLONE_DIR" -cf - . | tar -C "$CAROLINE_DIR" -xf -

CAROLINE_DIR_SED="$(printf '%s' "$CAROLINE_DIR" | sed 's/[&#]/\\&/g')"
for json in "$CAROLINE_DIR/flows.json" "$CAROLINE_DIR/caroline-agent-loop.json" "$CAROLINE_DIR/caroline-auto-tasks.json" "$CAROLINE_DIR/caroline-wonder-loop.json"; do
  [ -f "$json" ] || continue
  sed -i "s#/home/davee/caroline#${CAROLINE_DIR_SED}#g" "$json"
done

node <<'NODE_MERGE'
const fs = require('fs');
const path = process.env.CAROLINE_DIR;
const files = ['flows.json', 'caroline-agent-loop.json', 'caroline-auto-tasks.json', 'caroline-wonder-loop.json'];
const merged = [];
for (const file of files) {
  const full = `${path}/${file}`;
  if (!fs.existsSync(full)) continue;
  const data = JSON.parse(fs.readFileSync(full, 'utf8'));
  if (!Array.isArray(data)) throw new Error(`${file} is not a flow array`);
  merged.push(...data);
}
fs.writeFileSync(`${path}/flows.json`, JSON.stringify(merged, null, 2) + '\n');
NODE_MERGE

if [ ! -s "$CAROLINE_DIR/google_oauth.json" ]; then printf '{}\n' > "$CAROLINE_DIR/google_oauth.json"; fi
if [ ! -s "$CAROLINE_DIR/caroline_tasks.json" ]; then printf '{\n  "tasks": [],\n  "updatedAt": null\n}\n' > "$CAROLINE_DIR/caroline_tasks.json"; fi
if [ ! -s "$CAROLINE_DIR/caroline_mind.json" ]; then printf '{\n  "version": 1,\n  "mood": { "curiosity": 0.62, "energy": 0.55, "socialPull": 0.35, "frustration": 0.1, "trust": 0.5 },\n  "wonderQueue": [],\n  "findings": [],\n  "lastOutboundAt": 0,\n  "lastCouncil": null,\n  "updatedAt": null\n}\n' > "$CAROLINE_DIR/caroline_mind.json"; fi
chmod 600 "$CAROLINE_DIR/google_oauth.json" "$CAROLINE_DIR/caroline_tasks.json" "$CAROLINE_DIR/caroline_mind.json" 2>/dev/null || true
printf '%s\n' "$CAROLINE_CHANNEL" > "$CAROLINE_DIR/caroline_channel"
say "${GREEN}  ✓ Caroline files ready at ${CAROLINE_DIR}${RESET}"
say ""

say "${MAGENTA}  // NODE-RED RUNTIME${RESET}"
mkdir -p "$NODERED_RUNTIME"
npm --prefix "$NODERED_RUNTIME" install --no-audit --no-fund node-red node-red-contrib-google-calendar node-red-contrib-google-sheets

cat > "$CAROLINE_DIR/settings.js" <<SETTINGS_EOF
const path = require('path');
const carolineDir = process.env.CAROLINE_DIR || __dirname;

module.exports = {
  uiPort: process.env.PORT || ${CAROLINE_PORT},
  uiHost: "127.0.0.1",
  httpAdminRoot: "/red",
  httpNodeRoot: "/",
  httpStatic: carolineDir,
  flowFile: "flows.json",
  httpRequestTimeout: 120000,
  httpNodeCors: { origin: "*", methods: "GET,PUT,POST,DELETE,OPTIONS" },
  functionExternalModules: true,
  functionGlobalContext: {
    fs: require("fs"),
    crypto: require("crypto"),
  },
  contextStorage: {
    default: { module: "localfilesystem" }
  },
}
SETTINGS_EOF
say "${GREEN}  ✓ Node-RED runtime installed locally${RESET}"
say ""

say "${MAGENTA}  // USER SERVICE${RESET}"
mkdir -p "$REAL_HOME/.config/systemd/user" "$REAL_HOME/.local/bin" "$REAL_HOME/.local/share/applications"
cat > "$REAL_HOME/.config/systemd/user/caroline.service" <<SERVICE_EOF
[Unit]
Description=Project: Caroline SteamOS experimental service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${CAROLINE_DIR}
Environment=PATH=${NODE_CURRENT}/bin:/usr/local/bin:/usr/bin:/bin
Environment=CAROLINE_DIR=${CAROLINE_DIR}
Environment=PORT=${CAROLINE_PORT}
ExecStart=${NODERED_RUNTIME}/node_modules/.bin/node-red --userDir ${CAROLINE_DIR} --port ${CAROLINE_PORT}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
SERVICE_EOF

cat > "$REAL_HOME/.local/bin/caroline-steamos-open" <<OPEN_EOF
#!/usr/bin/env bash
set -e
URL="http://localhost:${CAROLINE_PORT}/"
if command -v flatpak >/dev/null 2>&1 && flatpak info org.mozilla.firefox >/dev/null 2>&1; then
  exec flatpak run org.mozilla.firefox "\$URL"
fi
exec xdg-open "\$URL"
OPEN_EOF
chmod +x "$REAL_HOME/.local/bin/caroline-steamos-open"

cat > "$REAL_HOME/.local/bin/caroline-steamos-kiosk" <<KIOSK_EOF
#!/usr/bin/env bash
set -e
URL="http://localhost:${CAROLINE_PORT}/"
PROFILE="\$HOME/.local/share/caroline/firefox-kiosk"
mkdir -p "\$PROFILE"
if command -v flatpak >/dev/null 2>&1 && flatpak info org.mozilla.firefox >/dev/null 2>&1; then
  exec flatpak run org.mozilla.firefox --kiosk --new-window "\$URL"
fi
if command -v firefox >/dev/null 2>&1; then
  exec firefox --no-remote --new-instance --profile "\$PROFILE" --kiosk "\$URL"
fi
if command -v chromium >/dev/null 2>&1; then
  exec chromium --kiosk --app="\$URL"
fi
exec xdg-open "\$URL"
KIOSK_EOF
chmod +x "$REAL_HOME/.local/bin/caroline-steamos-kiosk"

cat > "$REAL_HOME/.local/share/applications/caroline-steamos.desktop" <<DESKTOP_EOF
[Desktop Entry]
Type=Application
Name=Project Caroline
Comment=Open Project Caroline
Exec=${REAL_HOME}/.local/bin/caroline-steamos-open
Terminal=false
Categories=Utility;
DESKTOP_EOF

cat > "$REAL_HOME/.local/share/applications/caroline-steamos-kiosk.desktop" <<DESKTOP_EOF
[Desktop Entry]
Type=Application
Name=Project Caroline Kiosk
Comment=Open Project Caroline fullscreen
Exec=${REAL_HOME}/.local/bin/caroline-steamos-kiosk
Terminal=false
Categories=Utility;
DESKTOP_EOF

cp -f "$REAL_HOME/.local/share/applications/caroline-steamos.desktop" "$REAL_HOME/Desktop/Project Caroline.desktop" 2>/dev/null || true
cp -f "$REAL_HOME/.local/share/applications/caroline-steamos-kiosk.desktop" "$REAL_HOME/Desktop/Project Caroline Kiosk.desktop" 2>/dev/null || true
chmod +x "$REAL_HOME/Desktop/Project Caroline.desktop" "$REAL_HOME/Desktop/Project Caroline Kiosk.desktop" 2>/dev/null || true

systemctl --user daemon-reload
systemctl --user enable --now caroline.service

if command -v sudo >/dev/null 2>&1; then
  if sudo -n true >/dev/null 2>&1; then
    sudo loginctl enable-linger "$REAL_USER" >/dev/null 2>&1 || true
  else
    say "${DIM}  Linger not enabled automatically because sudo needs a password.${RESET}"
    say "${DIM}  For auto-start before login, run: sudo loginctl enable-linger ${REAL_USER}${RESET}"
  fi
fi

say "${GREEN}  ✓ Caroline user service started${RESET}"
say ""

say "${MAGENTA}  // VERIFY${RESET}"
for i in $(seq 1 45); do
  if curl -fsS "http://127.0.0.1:${CAROLINE_PORT}/" >/dev/null 2>&1; then
    READY=true
    break
  fi
  sleep 1
done

if [ "${READY:-false}" = "true" ]; then
  say "${GREEN}  ✓ Caroline is responding on the Steam Deck${RESET}"
else
  say "${YELLOW}  ! Caroline did not respond yet. Check logs:${RESET}"
  say "${DIM}    journalctl --user -u caroline -n 80 --no-pager${RESET}"
fi

say ""
say "${BOLD}${GREEN}  Project: Caroline SteamOS experimental install complete.${RESET}"
say "${CYAN}  URL on Steam Deck:${RESET} ${BOLD}http://localhost:${CAROLINE_PORT}/${RESET}"
say "${CYAN}  Open command:${RESET} ${BOLD}caroline-steamos-open${RESET}"
say "${CYAN}  Kiosk command:${RESET} ${BOLD}caroline-steamos-kiosk${RESET}"
say "${CYAN}  Logs:${RESET} ${BOLD}journalctl --user -u caroline -f${RESET}"
say "${CYAN}  Editor:${RESET} ${BOLD}http://localhost:${CAROLINE_PORT}/red${RESET}"
say ""
