#!/bin/bash

# ============================================================
#   PROJECT: CAROLINE
#   Personal AI Kiosk — install.sh
#   github.com/DaveEuson/project-caroline
# ============================================================

set -e

# Fix Windows line endings if this script was edited on Windows
sed -i 's/\r//' "$0" 2>/dev/null || true

CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'


# ── SPINNER ───────────────────────────────────────────────────
spin() {
  local pid=$1 msg=$2
  local spin='⣾⣽⣻⢿⡿⣟⣯⣷'
  local i=0
  tput civis 2>/dev/null || true
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r  ${CYAN}${spin:$i:1}${RESET}  %s" "$msg"
    i=$(( (i+1) % ${#spin} ))
    sleep 0.1
  done
  tput cnorm 2>/dev/null || true
  printf "\r"
}

phase() {
  echo ""
  echo -e "${CYAN}  ╔══════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${CYAN}  ║  ${MAGENTA}$1${CYAN}$(printf '%*s' $((55 - ${#1})) '')║${RESET}"
  echo -e "${CYAN}  ╚══════════════════════════════════════════════════════════╝${RESET}"
  echo ""
}

# ── CONFIG ───────────────────────────────────────────────────
CAROLINE_VERSION="0.2.0"
NODE_RED_PORT=1880
KIOSK_PORT=8080
HTTPS_PROXY_PORT=8443
AI_MODEL="anthropic/claude-haiku-4.5"

# Node-RED palette nodes required by Caroline
PALETTE_NODES=(
  "node-red-contrib-google-calendar"
  "node-red-contrib-google-sheets"
)

# ── RESOLVE REAL USER (safe even if run with sudo) ───────────
REAL_USER=${SUDO_USER:-$USER}
REAL_HOME=$(eval echo "~$REAL_USER")
CAROLINE_DIR="$REAL_HOME/caroline"
SETTINGS_PATH="$CAROLINE_DIR/caroline_settings.json"

protect_secret_files() {
  local _secret
  for _secret in \
    "$CAROLINE_DIR/caroline_settings.json" \
    "$CAROLINE_DIR/google_oauth.json" \
    "$CAROLINE_DIR/caroline_tasks.json" \
    "$CAROLINE_DIR/caroline_mind.json" \
    "$CAROLINE_DIR/spotify_auth.json" \
    "$CAROLINE_DIR/caroline-calendar.json" \
    "$CAROLINE_DIR/service-account.json"; do
    [ -f "$_secret" ] || continue
    sudo chown "$REAL_USER":"$REAL_USER" "$_secret" 2>/dev/null || true
    chmod 600 "$_secret" 2>/dev/null || true
  done
}

configure_firefox_profile() {
  local _profile_dir="${1:-$FIREFOX_PROFILE_DIR}"
  mkdir -p "$_profile_dir"
  cat > "$_profile_dir/user.js" << 'USERJS'
user_pref("browser.sessionstore.resume_from_crash", false);
user_pref("browser.aboutwelcome.enabled", false);
user_pref("browser.startup.homepage_override.mstone", "ignore");
user_pref("profile.default_content_setting_values.notifications", 2);
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.tabs.warnOnClose", false);
user_pref("toolkit.telemetry.enabled", false);
user_pref("datareporting.healthreport.uploadEnabled", false);
USERJS
  chown -R "$REAL_USER:$REAL_USER" "$_profile_dir" 2>/dev/null || true
}

desktop_dir_for_user() {
  local _desktop="$REAL_HOME/Desktop"
  local _xdg_file="$REAL_HOME/.config/user-dirs.dirs"
  local _xdg_desktop=""
  if [ -f "$_xdg_file" ]; then
    _xdg_desktop=$(grep '^XDG_DESKTOP_DIR=' "$_xdg_file" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '"')
    _xdg_desktop="${_xdg_desktop/#\$HOME/$REAL_HOME}"
    [ -n "$_xdg_desktop" ] && _desktop="$_xdg_desktop"
  fi
  printf '%s' "$_desktop"
}

write_desktop_shortcuts() {
  local _desktop_dir="$1"
  local _windowed_file="$_desktop_dir/Project Caroline.desktop"
  local _kiosk_file="$_desktop_dir/Project Caroline Kiosk.desktop"

  mkdir -p "$_desktop_dir"
  cat > "$_windowed_file" << EOF
[Desktop Entry]
Type=Application
Name=Project Caroline
Comment=Launch Project: Caroline in a browser window
Exec=${BROWSER_BIN} --profile ${WINDOWED_PROFILE_DIR} --new-window ${KIOSK_URL}
Icon=web-browser
Terminal=false
Categories=Utility;
StartupNotify=true
EOF

  cat > "$_kiosk_file" << EOF
[Desktop Entry]
Type=Application
Name=Project Caroline Kiosk
Comment=Launch Project: Caroline fullscreen kiosk
Exec=${BROWSER_BIN} --kiosk --profile ${FIREFOX_PROFILE_DIR} ${KIOSK_URL}
Icon=web-browser
Terminal=false
Categories=Utility;
StartupNotify=true
EOF

  chmod +x "$_windowed_file" "$_kiosk_file"
  chown "$REAL_USER:$REAL_USER" "$_windowed_file" "$_kiosk_file" 2>/dev/null || true
  if command -v gio >/dev/null 2>&1; then
    sudo -u "$REAL_USER" gio set "$_windowed_file" metadata::trusted true 2>/dev/null || true
    sudo -u "$REAL_USER" gio set "$_kiosk_file" metadata::trusted true 2>/dev/null || true
  fi
}

ensure_browser() {
  if command -v firefox-esr >/dev/null 2>&1; then
    BROWSER_BIN=$(command -v firefox-esr)
    return 0
  fi
  if command -v firefox >/dev/null 2>&1; then
    BROWSER_BIN=$(command -v firefox)
    return 0
  fi

  sudo apt-get install -y -q firefox-esr >/tmp/caroline-browser-apt.log 2>&1 || \
  sudo apt-get install -y -q firefox >/tmp/caroline-browser-apt.log 2>&1 || {
    echo -e "${YELLOW}  ⚠ Browser install failed. Check: cat /tmp/caroline-browser-apt.log${RESET}"
    BROWSER_BIN=""
    return 1
  }

  if command -v firefox-esr >/dev/null 2>&1; then
    BROWSER_BIN=$(command -v firefox-esr)
  elif command -v firefox >/dev/null 2>&1; then
    BROWSER_BIN=$(command -v firefox)
  else
    echo -e "${YELLOW}  ⚠ Browser package installed but no Firefox command was found.${RESET}"
    BROWSER_BIN=""
    return 1
  fi
  return 0
}

clear

echo ""
echo -e "${CYAN}  ____            _           _        ____                 _ _            ${RESET}"
echo -e "${CYAN} |  _ \\ _ __ ___ (_) ___  ___| |_     / ___|__ _ _ __ ___ | (_)_ __   ___ ${RESET}"
echo -e "${MAGENTA} | |_) | '__/ _ \\| |/ _ \\/ __| __|   | |   / _\` | '__/ _ \\| | | '_ \\ / _ \\${RESET}"
echo -e "${MAGENTA} |  __/| | | (_) | |  __/ (__| |_    | |__| (_| | | | (_) | | | | | |  __/${RESET}"
echo -e "${CYAN} |_|   |_|  \\___// |\\___|\\___|\\__|    \\____\\__,_|_|  \\___/|_|_|_| |_|\\___|${RESET}"
echo -e "${CYAN}              |__/                                                        ${RESET}"
echo ""
echo -e "${BOLD}${CYAN}  Project: Caroline${RESET}  ${DIM}v${CAROLINE_VERSION}${RESET}"
echo -e "${DIM}  Your personal AI sidekick with a tiny neon pulse.${RESET}"
echo ""
echo -e "${CYAN}  ════════════════════════════════════════════════════════════${RESET}"
echo ""

sleep 1

# ── OS VERSION CHECK ─────────────────────────────────────────
OS_ID=$(. /etc/os-release 2>/dev/null && echo "$ID" || echo "unknown")
OS_VER=$(. /etc/os-release 2>/dev/null && echo "$VERSION_CODENAME" || echo "unknown")
if [[ "$OS_ID" != "raspbian" && "$OS_ID" != "debian" && "$OS_ID" != "ubuntu" ]]; then
  echo -e "${YELLOW}  ⚠ Unrecognized OS: ${OS_ID} ${OS_VER}${RESET}"
  echo -e "${DIM}  Caroline is designed for Raspberry Pi OS, with 64-bit Ubuntu/Debian/Linux as an alternate path.${RESET}"
  echo -e "${DIM}  Continuing anyway — things may break.${RESET}"
  echo ""
fi

# ── INTRO ────────────────────────────────────────────────────
echo -e "${BOLD}  Booting Project: Caroline for the first time.${RESET}"
echo -e "${DIM}  A few questions before the time gate opens.${RESET}"
echo -e "${DIM}  API keys and integrations are configured in her GUI after install.${RESET}"
echo -e "${DIM}  Press Enter to skip any field.${RESET}"
echo ""
echo -e "${CYAN}  ════════════════════════════════════════════════════════════${RESET}"
echo ""

# ── USER INPUT ───────────────────────────────────────────────
echo -e "${MAGENTA}  // IDENTITY MATRIX${RESET}"
echo ""
read -p "  Your name: " USER_NAME </dev/tty
read -p "  Your timezone (e.g. America/Los_Angeles): " TIMEZONE </dev/tty
read -p "  Your location (e.g. Portland, OR): " LOCATION </dev/tty
read -p "  ZIP code for weather (optional): " ZIP_CODE </dev/tty
echo ""

echo -e "${MAGENTA}  // NEURAL CORE SELECTION${RESET}"
echo ""
echo -e "${DIM}  Ollama = local AI, free forever, runs on your Pi. No API key.${RESET}"
echo -e "${DIM}  OpenRouter = cloud AI (Claude Haiku). Costs ~\$0.05/month. Needs a key.${RESET}"
echo ""

# Warn if RAM is low
TOTAL_RAM_MB=$(awk '/MemTotal/ {printf "%d", $2/1024}' /proc/meminfo 2>/dev/null || echo 0)
if [ "$TOTAL_RAM_MB" -gt 0 ] && [ "$TOTAL_RAM_MB" -lt 4096 ]; then
  echo -e "${YELLOW}  ⚠ ${TOTAL_RAM_MB}MB RAM detected. Ollama runs better with 4GB+.${RESET}"
  echo -e "${DIM}    gemma2:2b is the safest local default on smaller Pi installs.${RESET}"
  echo ""
fi

read -p "  Install Ollama for free local AI? (y/N): " INSTALL_OLLAMA </dev/tty
INSTALL_OLLAMA="${INSTALL_OLLAMA:-N}"
echo ""

if [ "$INSTALL_OLLAMA" = "y" ] || [ "$INSTALL_OLLAMA" = "Y" ]; then
  AI_PROVIDER="ollama"
  OLLAMA_MODEL="gemma2:2b"
  echo -e "${DIM}  Pulling gemma2:2b by default. Choose a different model if you want:${RESET}"
  echo -e "${DIM}  (Options: gemma2:2b, phi3:mini, llama3.2 — Enter to keep gemma2:2b)${RESET}"
  read -p "  Model [gemma2:2b]: " OLLAMA_MODEL_INPUT </dev/tty
  OLLAMA_MODEL="${OLLAMA_MODEL_INPUT:-gemma2:2b}"
  echo ""
  echo -e "${DIM}  Good. ${OLLAMA_MODEL} is her brain. Worth the wait.${RESET}"
else
  AI_PROVIDER="openrouter"
  OLLAMA_MODEL="gemma2:2b"
  echo -e "${DIM}  Cloud mode selected. Add your OpenRouter key in Caroline's settings after install.${RESET}"
fi
echo ""

echo -e "${MAGENTA}  // DISPLAY MODE${RESET}"
echo ""
echo -e "${DIM}  Kiosk mode opens Caroline fullscreen on boot — ideal for a dedicated Pi display.${RESET}"
echo -e "${DIM}  Skip this if you're just testing, or if you don't have a desktop environment.${RESET}"
echo ""
read -p "  Enable kiosk mode on boot? (y/N): " KIOSK_MODE </dev/tty
echo ""

echo -e "${CYAN}  ════════════════════════════════════════════════════════════${RESET}"
echo ""
echo -e "${BOLD}  Acknowledged. Preparing the local core at ~/caroline/...${RESET}"
echo ""
sleep 1

# ── DEPENDENCIES ─────────────────────────────────────────────
phase "PHASE 1 — ESTABLISHING UPLINK"

echo -e "${YELLOW}  ► Installing system dependencies...${RESET}"
sudo apt-get update -q >/tmp/caroline-apt-update.log 2>&1 || {
  echo -e "${RED}  ✗ apt-get update failed. Is the network up?${RESET}"
  echo -e "${DIM}    Log: cat /tmp/caroline-apt-update.log${RESET}"
  exit 1
}
sudo apt-get install -y -q curl git ca-certificates gnupg jq nginx python3-pip psmisc openssl >/tmp/caroline-apt-install.log 2>&1 || {
  echo -e "${RED}  ✗ apt-get failed. Is the network up?${RESET}"
  echo -e "${DIM}    Log: cat /tmp/caroline-apt-install.log${RESET}"
  echo -e "${DIM}    Try: sudo apt-get update && sudo apt-get install -y curl git jq nginx python3-pip psmisc openssl${RESET}"
  exit 1
}
echo -e "${GREEN}  ✓ System dependencies online${RESET}"

# ── NODE.JS ──────────────────────────────────────────────────
echo -e "${YELLOW}  ► Checking Node.js runtime...${RESET}"

node_major_from_version() {
  local _version="${1:-0}"
  local _major
  _major=$(printf '%s' "$_version" | sed -E 's/^v?([0-9]+).*/\1/')
  if [[ "$_major" =~ ^[0-9]+$ ]]; then
    printf '%s' "$_major"
  else
    printf '0'
  fi
}

node_apt_candidate() {
  apt-cache policy nodejs 2>/dev/null | awk '/Candidate:/ {print $2; exit}'
}

install_node_from_apt() {
  local _candidate _candidate_major
  _candidate=$(node_apt_candidate)
  _candidate_major=$(node_major_from_version "$_candidate")
  if [ "$_candidate_major" -lt 18 ]; then
    echo -e "${RED}  ✗ This OS repository offers Node.js ${_candidate:-unknown}, but Node-RED 4.x needs Node.js 18+.${RESET}"
    echo -e "${DIM}    Use a real Pi running Raspberry Pi OS 64-bit, or a 64-bit Ubuntu/Debian/Linux VM or desktop.${RESET}"
    echo -e "${DIM}    32-bit i386 VM images often only provide old Node.js packages and are not a reliable QA target.${RESET}"
    exit 1
  fi
  echo -e "${DIM}    Installing Node.js from OS package repositories...${RESET}"
  sudo apt-get install -y nodejs npm >/tmp/caroline-node-apt.log 2>&1 || {
    echo -e "${RED}  ✗ Node.js apt install failed. Check: cat /tmp/caroline-node-apt.log${RESET}"
    exit 1
  }
}

install_node_runtime() {
  ARCH=$(dpkg --print-architecture 2>/dev/null || uname -m)
  if [[ "$ARCH" == "i386" || "$ARCH" == "i686" ]]; then
    echo -e "${YELLOW}  ⚠ i386 VM detected. NodeSource does not publish Node 20 for i386.${RESET}"
    echo -e "${DIM}    Falling back to Raspberry Pi OS/Debian packages.${RESET}"
    install_node_from_apt
  else
    echo -e "${DIM}    Node.js not found — installing via NodeSource...${RESET}"
    if curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - >/tmp/caroline-nodesource.log 2>&1; then
      sudo apt-get install -y nodejs >/tmp/caroline-node-apt.log 2>&1 || {
        echo -e "${YELLOW}  ⚠ NodeSource package install failed — falling back to OS packages.${RESET}"
        install_node_from_apt
      }
    else
      echo -e "${YELLOW}  ⚠ NodeSource setup failed — falling back to OS packages.${RESET}"
      echo -e "${DIM}    Log: cat /tmp/caroline-nodesource.log${RESET}"
      install_node_from_apt
    fi
  fi
}

if ! command -v node &> /dev/null; then
  install_node_runtime
fi
NODE_MAJOR=$(node -p "parseInt(process.versions.node.split('.')[0], 10)" 2>/dev/null || echo 0)
if [ "$NODE_MAJOR" -lt 18 ]; then
  echo -e "${YELLOW}  ⚠ Node.js $(node --version 2>/dev/null || echo unknown) is too old. Trying to upgrade...${RESET}"
  install_node_runtime
  NODE_MAJOR=$(node -p "parseInt(process.versions.node.split('.')[0], 10)" 2>/dev/null || echo 0)
  if [ "$NODE_MAJOR" -lt 18 ]; then
    echo -e "${RED}  ✗ Node.js $(node --version 2>/dev/null || echo unknown) is too old. Node-RED 4.x needs Node.js 18+.${RESET}"
    echo -e "${DIM}    Use a real Pi running Raspberry Pi OS 64-bit, or a 64-bit Ubuntu/Debian/Linux VM or desktop.${RESET}"
    exit 1
  fi
fi
if ! command -v npm &> /dev/null; then
  install_node_from_apt
fi
echo -e "${GREEN}  ✓ Node.js $(node --version) ready${RESET}"

# ── NODE-RED ─────────────────────────────────────────────────
phase "PHASE 2 — WEAVING THE NEURAL WEB"

echo -e "${YELLOW}  ► Installing Node-RED (this takes 1-3 minutes)...${RESET}"
sudo npm install -g --unsafe-perm node-red >/tmp/caroline-npm.log 2>&1 &
NODERED_PID=$!
spin "$NODERED_PID" "Installing Node-RED..."
wait "$NODERED_PID" || {
  echo -e "${RED}  ✗ Node-RED install failed. Check: cat /tmp/caroline-npm.log${RESET}"
  exit 1
}

# Resolve binary path — npm global installs to /usr/local/bin, not /usr/bin
NODE_RED_BIN=$(which node-red)

echo -e "${GREEN}  ✓ Node-RED ready${RESET}"

# ── NODE-RED SETTINGS ────────────────────────────────────────
echo -e "${YELLOW}  ► Calibrating personality matrix...${RESET}"

mkdir -p "$CAROLINE_DIR"

# Write a minimal settings.js that enables require() in function nodes.
# Single-quoted heredoc delimiter prevents shell expansion of the JS content.
cat > "$CAROLINE_DIR/settings.js" << 'SETTINGS_EOF'
module.exports = {
    uiPort: process.env.PORT || 1880,
    uiHost: "0.0.0.0",
    flowFile: 'flows.json',
    httpRequestTimeout: 120000,
    httpNodeCors: { origin: "*", methods: "GET,PUT,POST,DELETE,OPTIONS" },
    functionGlobalContext: {
        fs:     require('fs'),
        crypto: require('crypto'),
    },
    contextStorage: {
        default: { module: 'localfilesystem' }
    },
}
SETTINGS_EOF

sudo chown "$REAL_USER":"$REAL_USER" "$CAROLINE_DIR/settings.js"

echo -e "${GREEN}  ✓ Node-RED configured${RESET}"

# ── OLLAMA (optional) ────────────────────────────────────────
if [ "$INSTALL_OLLAMA" = "y" ] || [ "$INSTALL_OLLAMA" = "Y" ]; then
  phase "PHASE 3 — INSTALLING NEURAL CORE (OLLAMA)"

  echo -e "${YELLOW}  ► Installing Ollama...${RESET}"
  if ! command -v ollama &> /dev/null; then
    curl -fsSL https://ollama.ai/install.sh | sh >/tmp/caroline-ollama.log 2>&1 || {
      echo -e "${RED}  ✗ Ollama install failed. Check your internet connection.${RESET}"
      echo -e "${DIM}    Manual install: curl -fsSL https://ollama.ai/install.sh | sh${RESET}"
    }
  fi
  echo -e "${GREEN}  ✓ Ollama installed${RESET}"

  echo -e "${YELLOW}  ► Configuring Ollama network access...${RESET}"
  sudo mkdir -p /etc/systemd/system/ollama.service.d/
  sudo tee /etc/systemd/system/ollama.service.d/env.conf > /dev/null << 'OLLAMA_ENV_EOF'
[Service]
Environment="OLLAMA_HOST=0.0.0.0"
Environment="OLLAMA_ORIGINS=*"
OLLAMA_ENV_EOF

  echo -e "${YELLOW}  ► Starting Ollama service...${RESET}"
  sudo systemctl enable ollama 2>/dev/null || true
  sudo systemctl daemon-reload
  sudo systemctl restart ollama 2>/dev/null || sudo systemctl start ollama 2>/dev/null || true
  ollama run "$OLLAMA_MODEL" "ready" > /dev/null 2>&1 &
  sleep 3

  echo -e "${YELLOW}  ► Verifying Ollama is responding...${RESET}"
  OLLAMA_READY=false
  for i in $(seq 1 15); do
    if curl -sf "http://localhost:11434/api/tags" > /dev/null 2>&1; then
      OLLAMA_READY=true
      break
    fi
    sleep 2
  done
  if [ "$OLLAMA_READY" = "true" ]; then
    echo -e "${GREEN}  ✓ Ollama responding at localhost:11434${RESET}"
  else
    echo -e "${YELLOW}  ⚠ Ollama not yet responding — run 'ollama serve' manually if needed${RESET}"
  fi

  echo -e "${YELLOW}  ► Pulling ${OLLAMA_MODEL} — this is her brain. Worth the wait.${RESET}"
  ollama pull "$OLLAMA_MODEL" >/tmp/caroline-pull.log 2>&1 &
  PULL_PID=$!
  spin "$PULL_PID" "Downloading ${OLLAMA_MODEL}..."
  if wait "$PULL_PID"; then
    echo -e "${GREEN}  ✓ Model ${OLLAMA_MODEL} locked and loaded${RESET}"
    echo -e "${YELLOW}  ► Warming ${OLLAMA_MODEL} into memory...${RESET}"
    ollama run "$OLLAMA_MODEL" "hello" >/dev/null 2>&1 || true
  else
    echo -e "${YELLOW}  ⚠ Model pull failed — run 'ollama pull ${OLLAMA_MODEL}' manually after install${RESET}"
    echo -e "${DIM}    Log: cat /tmp/caroline-pull.log${RESET}"
  fi
fi

# ── DATA DIRECTORY ───────────────────────────────────────────
echo -e "${YELLOW}  ► Initializing memory banks at ${CAROLINE_DIR}...${RESET}"

mkdir -p "$CAROLINE_DIR"
sudo chown "$REAL_USER":"$REAL_USER" "$CAROLINE_DIR"

echo -e "${GREEN}  ✓ Memory banks online${RESET}"
echo -e "${DIM}    Time gate stable; crystal bus humming.${RESET}"

# ── CAROLINE FILES ───────────────────────────────────────────
phase "PHASE 4 — DEPLOYING CAROLINE'S PAYLOAD"

mkdir -p "$CAROLINE_DIR"

echo -e "${YELLOW}  ► Cloning Caroline from GitHub...${RESET}"
echo -e "${DIM}    Fetching the airship manifest.${RESET}"

CLONE_DIR="$REAL_HOME/project-caroline"

if [ -d "$CLONE_DIR/.git" ]; then
  echo -e "${DIM}    Repo already present — pulling latest...${RESET}"
  git -C "$CLONE_DIR" pull --ff-only 2>/tmp/caroline-git.log || \
    echo -e "${YELLOW}    ⚠ git pull failed — using existing clone${RESET}"
else
  git clone "https://github.com/DaveEuson/project-caroline.git" "$CLONE_DIR" >/tmp/caroline-git.log 2>&1 || {
    echo -e "${RED}  ✗ Git clone failed. Check your internet connection.${RESET}"
    echo -e "${DIM}    Log: cat /tmp/caroline-git.log${RESET}"
    exit 1
  }
fi

echo -e "${DIM}    Copying payload to ${CAROLINE_DIR}...${RESET}"
echo -e "${DIM}    Robot manners module: polite.${RESET}"

# Existing installs may contain a .git directory with ownership left over from
# older installer runs. The runtime directory does not need Git metadata, so
# skip it entirely and copy only the deployable project files.
sudo chown -R "$REAL_USER":"$REAL_USER" "$CAROLINE_DIR" 2>/dev/null || true
rm -rf "$CAROLINE_DIR/.git"
tar --exclude='./.git' -C "$CLONE_DIR" -cf - . | tar -C "$CAROLINE_DIR" -xf -
sudo chown -R "$REAL_USER":"$REAL_USER" "$CAROLINE_DIR"

# The published flows are authored from the maintainer's home directory.
# Rewrite those paths at install time so memory, OAuth, and settings files
# live in the actual user's Caroline directory.
CAROLINE_DIR_SED=$(printf '%s' "$CAROLINE_DIR" | sed 's/[&#]/\\&/g')
for _json in "$CAROLINE_DIR/flows.json" "$CAROLINE_DIR/caroline-agent-loop.json" "$CAROLINE_DIR/caroline-auto-tasks.json" "$CAROLINE_DIR/caroline-wonder-loop.json"; do
  [ -f "$_json" ] || continue
  sed -i "s#/home/davee/caroline#${CAROLINE_DIR_SED}#g" "$_json"
done
unset _json CAROLINE_DIR_SED

# Flatten avatar GIFs to root — skip any placeholder stub (43 bytes); only copy files > 1 KB
for _gif in "$CAROLINE_DIR/assets/"*.gif; do
  [ -f "$_gif" ] || continue
  [ "$(stat -c%s "$_gif" 2>/dev/null || echo 0)" -gt 1024 ] && cp -f "$_gif" "$CAROLINE_DIR/" || \
    echo -e "${YELLOW}    ⚠ Skipped placeholder GIF: $(basename "$_gif")${RESET}"
done
unset _gif
# Ensure nginx (www-data) can read all files
sudo chmod -R 755 "$CAROLINE_DIR"
sudo chown -R www-data:www-data "$CAROLINE_DIR/assets" 2>/dev/null || true
protect_secret_files

if [ ! -f "$CAROLINE_DIR/index.html" ] || [ ! -f "$CAROLINE_DIR/flows.json" ]; then
  echo ""
  echo -e "${RED}  ✗ Core files missing after copy. Check clone at: ${CLONE_DIR}${RESET}"
  exit 1
fi

echo -e "${GREEN}  ✓ Caroline payload ready${RESET}"
echo -e "${DIM}    Chronal sweep clean; pilot sync stable.${RESET}"

# ── GOOGLE OAUTH TOKEN STORE ─────────────────────────────────
touch "$CAROLINE_DIR/google_oauth.json"
chmod 600 "$CAROLINE_DIR/google_oauth.json"
sudo chown "$REAL_USER":"$REAL_USER" "$CAROLINE_DIR/google_oauth.json"
if [ ! -f "$CAROLINE_DIR/caroline_tasks.json" ]; then
  printf '{\n  "tasks": [],\n  "updatedAt": null\n}\n' > "$CAROLINE_DIR/caroline_tasks.json"
fi
chmod 600 "$CAROLINE_DIR/caroline_tasks.json"
sudo chown "$REAL_USER":"$REAL_USER" "$CAROLINE_DIR/caroline_tasks.json"
if [ ! -f "$CAROLINE_DIR/caroline_mind.json" ]; then
  printf '{\n  "version": 1,\n  "mood": {\n    "curiosity": 0.62,\n    "energy": 0.55,\n    "socialPull": 0.35,\n    "frustration": 0.1,\n    "trust": 0.5\n  },\n  "wonderQueue": [],\n  "findings": [],\n  "lastOutboundAt": 0,\n  "lastCouncil": null,\n  "updatedAt": null\n}\n' > "$CAROLINE_DIR/caroline_mind.json"
fi
chmod 600 "$CAROLINE_DIR/caroline_mind.json"
sudo chown "$REAL_USER":"$REAL_USER" "$CAROLINE_DIR/caroline_mind.json"
echo -e "${DIM}  ℹ Google Calendar connects from Caroline Settings after install; tasks live in caroline_tasks.json${RESET}"

# ── IMPORT NODE-RED FLOWS ────────────────────────────────────
echo -e "${YELLOW}  ► Importing Node-RED flows...${RESET}"

# Merge optional flow modules into main flows
FLOWS_FILE="$CAROLINE_DIR/flows.json"
MERGED_FLOWS_FILE="/tmp/caroline-merged-flows.json"
rm -f "$MERGED_FLOWS_FILE"

if [ -f "$CAROLINE_DIR/caroline-agent-loop.json" ]; then
  jq -s '.[0] + .[1]' "$FLOWS_FILE" "$CAROLINE_DIR/caroline-agent-loop.json" > "${MERGED_FLOWS_FILE}.tmp"
  mv "${MERGED_FLOWS_FILE}.tmp" "$MERGED_FLOWS_FILE"
  FLOWS_FILE="$MERGED_FLOWS_FILE"
  echo -e "${DIM}    Merged agent loop into flows${RESET}"
fi

if [ -f "$CAROLINE_DIR/caroline-auto-tasks.json" ]; then
  jq -s '.[0] + .[1]' "$FLOWS_FILE" "$CAROLINE_DIR/caroline-auto-tasks.json" > "${MERGED_FLOWS_FILE}.tmp"
  mv "${MERGED_FLOWS_FILE}.tmp" "$MERGED_FLOWS_FILE"
  FLOWS_FILE="$MERGED_FLOWS_FILE"
  echo -e "${DIM}    Merged auto-tasks into flows${RESET}"
fi

if [ -f "$CAROLINE_DIR/caroline-wonder-loop.json" ]; then
  jq -s '.[0] + .[1]' "$FLOWS_FILE" "$CAROLINE_DIR/caroline-wonder-loop.json" > "${MERGED_FLOWS_FILE}.tmp"
  mv "${MERGED_FLOWS_FILE}.tmp" "$MERGED_FLOWS_FILE"
  FLOWS_FILE="$MERGED_FLOWS_FILE"
  echo -e "${DIM}    Merged wonder loop into flows${RESET}"
fi

cp "$FLOWS_FILE" "$CAROLINE_DIR/flows.json"

echo -e "${GREEN}  ✓ Flows imported${RESET}"

# ── GOOGLE SERVICE ACCOUNT PLACEHOLDER ───────────────────────
# ── NODE-RED PALETTE NODES ───────────────────────────────────
echo -e "${YELLOW}  ► Installing Node-RED palette nodes...${RESET}"

cd "$CAROLINE_DIR"
for NODE in "${PALETTE_NODES[@]}"; do
  npm install "$NODE" --save >/dev/null 2>&1 &
  NPM_PID=$!
  spin "$NPM_PID" "Installing $NODE..."
  wait "$NPM_PID" || echo -e "${YELLOW}    ⚠ $NODE install failed — can be added later via Node-RED palette manager${RESET}"
done

echo -e "${GREEN}  ✓ Palette nodes installed${RESET}"

# TTS (optional — non-blocking)
pip3 install edge-tts 2>/dev/null || true
echo -e "${GREEN}  ✓ edge-tts installed (or skipped)${RESET}"

# ── NGINX (serve kiosk on port 8080) ─────────────────────────
phase "PHASE 5 — ACTIVATING INTERFACE"

echo -e "${YELLOW}  ► Deploying kiosk interface on port ${KIOSK_PORT}...${RESET}"

# Clear the port before nginx tries to bind it
sudo fuser -k ${KIOSK_PORT}/tcp 2>/dev/null || true
sudo fuser -k ${HTTPS_PROXY_PORT}/tcp 2>/dev/null || true

# nginx runs as www-data — needs execute permission on the home directory
# to traverse into ~/caroline, and read access on the files themselves.
sudo chmod o+x "$REAL_HOME"
sudo chmod -R o+rX "$CAROLINE_DIR"
protect_secret_files

sudo mkdir -p /etc/caroline
if [ ! -f /etc/caroline/caroline-selfsigned.crt ] || [ ! -f /etc/caroline/caroline-selfsigned.key ]; then
  sudo openssl req -x509 -nodes -newkey rsa:2048 -days 3650 \
    -keyout /etc/caroline/caroline-selfsigned.key \
    -out /etc/caroline/caroline-selfsigned.crt \
    -subj "/CN=project-caroline.local" >/tmp/caroline-openssl.log 2>&1 || {
      echo -e "${YELLOW}  ⚠ HTTPS certificate generation failed${RESET}"
    }
  sudo chmod 600 /etc/caroline/caroline-selfsigned.key 2>/dev/null || true
fi
if [ ! -f /etc/caroline/caroline-selfsigned.crt ] || [ ! -f /etc/caroline/caroline-selfsigned.key ]; then
  echo -e "${RED}  ✗ HTTPS certificate is missing; nginx would fail to start.${RESET}"
  echo -e "${DIM}    Log: cat /tmp/caroline-openssl.log${RESET}"
  exit 1
fi

sudo tee /etc/nginx/sites-available/caroline > /dev/null << EOF
server {
    listen ${KIOSK_PORT};
    root ${CAROLINE_DIR};
    index index.html;
    autoindex off;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer" always;
    add_header Content-Security-Policy "default-src 'self' 'unsafe-inline' 'unsafe-eval' ws: wss: data: blob: https: http:;" always;

    location / {
        try_files \$uri \$uri/ /index.html;
    }
}

server {
    listen ${HTTPS_PROXY_PORT} ssl;
    server_name _;

    ssl_certificate /etc/caroline/caroline-selfsigned.crt;
    ssl_certificate_key /etc/caroline/caroline-selfsigned.key;

    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

    location / {
        proxy_pass http://127.0.0.1:${NODE_RED_PORT};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/caroline /etc/nginx/sites-enabled/caroline
sudo rm -f /etc/nginx/sites-enabled/default

# Systemd drop-in: clear the port before nginx binds on every boot/restart
sudo mkdir -p /etc/systemd/system/nginx.service.d
sudo tee /etc/systemd/system/nginx.service.d/port-clear.conf > /dev/null << DROPIN_EOF
[Service]
ExecStartPre=/bin/sh -c 'fuser -k ${KIOSK_PORT}/tcp 2>/dev/null; fuser -k ${HTTPS_PROXY_PORT}/tcp 2>/dev/null; true'
DROPIN_EOF
sudo systemctl daemon-reload

sudo systemctl enable nginx
sudo systemctl restart nginx

echo -e "${GREEN}  ✓ Web server ready on ${KIOSK_PORT}; HTTPS proxy ready on ${HTTPS_PROXY_PORT}${RESET}"

# ── WRITE SETTINGS ───────────────────────────────────────────
echo -e "${YELLOW}  ► Writing settings...${RESET}"

# jq writes valid JSON regardless of special characters in user input.
# On upgrades, merge defaults under the existing settings file so credentials,
# paired devices, OAuth clients, and user preferences survive reruns.
PI_IP=$(hostname -I | awk '{print $1}')
[ -n "$PI_IP" ] || PI_IP="localhost"
DEFAULT_SETTINGS_PATH=$(mktemp)
MERGED_SETTINGS_PATH=$(mktemp)
jq -n \
  --arg name         "$USER_NAME" \
  --arg tz           "${TIMEZONE:-America/New_York}" \
  --arg loc          "$LOCATION" \
  --arg zip          "$ZIP_CODE" \
  --arg model        "$AI_MODEL" \
  --arg provider     "$AI_PROVIDER" \
  --arg ollamaModel  "$OLLAMA_MODEL" \
  --arg nrUrl        "http://${PI_IP}:${NODE_RED_PORT}" \
  --argjson kiosk    "$([ "$KIOSK_MODE" = "y" ] || [ "$KIOSK_MODE" = "Y" ] && echo true || echo false)" \
  '{
    userName:        $name,
    aiName:          "Caroline",
    userMood:        7,
    aiMood:          7,
    timezone:        $tz,
    timeFormat:      "12",
    temperatureUnit: "fahrenheit",
    location:        $loc,
    zipcode:         $zip,
    zipCode:         $zip,
    nodeRedUrl:      $nrUrl,
    uiFont:          "Inter",
    uiScale:         "large",
    uiDensity:       "comfortable",
    highContrastText: true,
    reduceMonoLabels: true,
    aiModel:         $model,
    aiProvider:      $provider,
    ollamaUrl:       "http://localhost:11434",
    ollamaModel:     $ollamaModel,
    openrouterKey:   "",
    hueIp:           "",
    hueKey:          "",
    calendarId:      "primary",
    sheetId:         "",
    spotifyClientId: "",
    googleClientId:  "",
    googleClientSecret: "",
    googleRedirectUri: "http://127.0.0.1:1880/admin/google/callback",
    googleConnected: false,
    discordToken:    "",
    kioskMode:       $kiosk
  }' > "$DEFAULT_SETTINGS_PATH"

if [ -s "$SETTINGS_PATH" ] && jq empty "$SETTINGS_PATH" >/dev/null 2>&1; then
  SETTINGS_BACKUP="$SETTINGS_PATH.bak.$(date +%Y%m%d-%H%M%S)"
  cp -p "$SETTINGS_PATH" "$SETTINGS_BACKUP" 2>/dev/null || true
  jq -s '
    .[0] * .[1]
    | if (.zipCode and ((.zipcode // "") == "")) then .zipcode = .zipCode else . end
    | if (.zipcode and ((.zipCode // "") == "")) then .zipCode = .zipcode else . end
  ' "$DEFAULT_SETTINGS_PATH" "$SETTINGS_PATH" > "$MERGED_SETTINGS_PATH"
  mv "$MERGED_SETTINGS_PATH" "$SETTINGS_PATH"
  echo -e "${DIM}    Existing settings preserved; backup: ${SETTINGS_BACKUP}${RESET}"
else
  mv "$DEFAULT_SETTINGS_PATH" "$SETTINGS_PATH"
fi
rm -f "$DEFAULT_SETTINGS_PATH" "$MERGED_SETTINGS_PATH"
protect_secret_files

echo -e "${GREEN}  ✓ Settings saved${RESET}"

# ── SYSTEMD SERVICE ──────────────────────────────────────────
phase "PHASE 6 — WIRING AUTOSTART"

echo -e "${YELLOW}  ► Configuring Caroline as a system service...${RESET}"

if [ "$INSTALL_OLLAMA" = "y" ] || [ "$INSTALL_OLLAMA" = "Y" ]; then
  CAROLINE_AFTER="network-online.target ollama.service"
  CAROLINE_REQUIRES="Requires=ollama.service"
  CAROLINE_ENV="Environment=\"OLLAMA_MODEL=${OLLAMA_MODEL}\""
  CAROLINE_POST='ExecStartPost=/bin/bash -c '\''sleep 30 && ollama run "$OLLAMA_MODEL" "ready" > /dev/null 2>&1 &'\'''
else
  CAROLINE_AFTER="network-online.target"
  CAROLINE_REQUIRES=""
  CAROLINE_ENV=""
  CAROLINE_POST=""
fi

sudo tee /etc/systemd/system/caroline.service > /dev/null << EOF
[Unit]
Description=Project: Caroline — Node-RED
After=${CAROLINE_AFTER}
Wants=network-online.target
${CAROLINE_REQUIRES}

[Service]
Type=simple
User=${REAL_USER}
WorkingDirectory=${CAROLINE_DIR}
${CAROLINE_ENV}
ExecStartPre=/bin/sleep 5
ExecStart=${NODE_RED_BIN} --port ${NODE_RED_PORT} --userDir ${CAROLINE_DIR}
${CAROLINE_POST}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable caroline

# Delete Node-RED runtime cache so it adopts flows.json cleanly on first boot
# (stale .config files cause flows to load into a "Recovered Nodes" tab instead)
rm -f "$CAROLINE_DIR/.config.runtime.json" 2>/dev/null || true
rm -f "$CAROLINE_DIR/.config.nodes.json"   2>/dev/null || true

# Use restart rather than start so rerunning the installer actually reloads
# updated flows/settings on an existing Caroline install.
sudo systemctl restart caroline

echo -e "${GREEN}  ✓ Caroline service enabled${RESET}"

# ── VERIFY NODE-RED STARTED ──────────────────────────────────
# flows.json is pre-copied to $CAROLINE_DIR and flowFile is set in settings.js,
# so Node-RED loads it from disk on first boot — no HTTP API deploy needed.
echo -e "${YELLOW}  ► Waiting for Node-RED to start...${RESET}"

NR_READY=false
for i in $(seq 1 45); do
  if curl -sf "http://localhost:${NODE_RED_PORT}/nodes" > /dev/null 2>&1; then
    NR_READY=true
    break
  fi
  sleep 2
done

if [ "$NR_READY" = "true" ]; then
  echo -e "${GREEN}  ✓ Node-RED is live — flows loaded from disk${RESET}"
else
  echo -e "${YELLOW}  ⚠ Node-RED didn't respond in time — it will load flows on next boot${RESET}"
fi

# ── DESKTOP SHORTCUTS ────────────────────────────────────────
KIOSK_URL="http://localhost:${KIOSK_PORT}/"
FIREFOX_PROFILE_DIR="$REAL_HOME/.mozilla/firefox/caroline-kiosk"
WINDOWED_PROFILE_DIR="$REAL_HOME/.mozilla/firefox/caroline-window"

echo -e "${YELLOW}  ► Creating desktop launch shortcuts...${RESET}"
if command -v startx &> /dev/null || command -v labwc &> /dev/null || [ -d "$REAL_HOME/Desktop" ]; then
  if ensure_browser; then
    configure_firefox_profile "$FIREFOX_PROFILE_DIR"
    configure_firefox_profile "$WINDOWED_PROFILE_DIR"
    DESKTOP_DIR=$(desktop_dir_for_user)
    write_desktop_shortcuts "$DESKTOP_DIR"
    echo -e "${GREEN}  ✓ Desktop shortcuts created${RESET}"
    echo -e "${DIM}    Browser:  ${BROWSER_BIN}${RESET}"
    echo -e "${DIM}    Windowed: ${DESKTOP_DIR}/Project Caroline.desktop${RESET}"
    echo -e "${DIM}    Kiosk:    ${DESKTOP_DIR}/Project Caroline Kiosk.desktop${RESET}"
  else
    echo -e "${YELLOW}  ⚠ Desktop shortcuts skipped because no supported browser was installed.${RESET}"
  fi
else
  echo -e "${YELLOW}  ⚠ No desktop environment detected — skipping desktop shortcuts.${RESET}"
fi

# ── KIOSK MODE ───────────────────────────────────────────────
if [ "$KIOSK_MODE" = "y" ] || [ "$KIOSK_MODE" = "Y" ]; then
  echo -e "${YELLOW}  ► Configuring kiosk mode...${RESET}"

  if ! command -v startx &> /dev/null && ! command -v labwc &> /dev/null; then
    echo -e "${YELLOW}  ⚠ No desktop environment detected — skipping kiosk setup.${RESET}"
    echo -e "${DIM}  Kiosk mode requires Pi OS Desktop, not Pi OS Lite.${RESET}"
    echo -e "${DIM}  You can enable it later in Caroline's settings panel.${RESET}"
  else
    sudo apt-get install -y -q xdotool unclutter 2>/dev/null || true
    if ensure_browser; then
      KIOSK_BROWSER_READY=true
    else
      echo -e "${YELLOW}  ⚠ No supported browser found — skipping kiosk autostart.${RESET}"
      KIOSK_BROWSER_READY=false
    fi

    if [ "$KIOSK_BROWSER_READY" = "true" ]; then

      # ── FIREFOX PROFILE: suppress first-run and crash-recovery screens ──
      configure_firefox_profile
      echo -e "${GREEN}  ✓ Firefox kiosk profile configured${RESET}"

      # Remove any pre-existing Firefox autostart entries to prevent double-launch
      rm -f "$REAL_HOME/.config/autostart/firefox"*.desktop 2>/dev/null || true
      [ -f "$REAL_HOME/.config/labwc/autostart" ] && \
        sed -i '/firefox/Id' "$REAL_HOME/.config/labwc/autostart" 2>/dev/null || true
      [ -f "$REAL_HOME/.config/wayfire.ini" ] && \
        sed -i '/firefox/Id' "$REAL_HOME/.config/wayfire.ini" 2>/dev/null || true

      # XDG autostart — primary launch method across all Pi OS window managers
      mkdir -p "$REAL_HOME/.config/autostart"
      cat > "$REAL_HOME/.config/autostart/caroline-kiosk.desktop" << EOF
[Desktop Entry]
Type=Application
Name=Caroline Kiosk
Comment=Launch Project: Caroline UI
Exec=${BROWSER_BIN} --kiosk --profile ${FIREFOX_PROFILE_DIR} http://localhost:${KIOSK_PORT}/
Terminal=false
X-GNOME-Autostart-enabled=true
EOF

      # labwc autostart — default Wayland compositor on Pi OS Bookworm (Pi 5)
      # Written unconditionally: labwc may not be in PATH until first boot
      mkdir -p "$REAL_HOME/.config/labwc"
      if ! grep -q "caroline" "$REAL_HOME/.config/labwc/autostart" 2>/dev/null; then
        echo "sleep 3 && ${BROWSER_BIN} --kiosk --profile ${FIREFOX_PROFILE_DIR} ${KIOSK_URL} &" >> "$REAL_HOME/.config/labwc/autostart"
        chmod +x "$REAL_HOME/.config/labwc/autostart"
      fi
      echo -e "${DIM}    labwc autostart configured${RESET}"

      # wayfire autostart — older Bookworm installs / alternative compositor
      # Written unconditionally: harmless if wayfire is not the active session
      mkdir -p "$REAL_HOME/.config"
      if ! grep -q "caroline" "$REAL_HOME/.config/wayfire.ini" 2>/dev/null; then
        printf '\n[autostart]\ncaroline = /bin/bash -c "sleep 3 && %s --kiosk --profile %s %s"\n' "${BROWSER_BIN}" "${FIREFOX_PROFILE_DIR}" "${KIOSK_URL}" >> "$REAL_HOME/.config/wayfire.ini"
      fi
      echo -e "${DIM}    wayfire.ini autostart configured${RESET}"

      echo -e "${GREEN}  ✓ Kiosk mode configured${RESET}"
    fi
  fi
fi

# ── SERVICE VERIFICATION ─────────────────────────────────────
echo -e "${YELLOW}  ► Verifying services...${RESET}"
_svc_ok=true
for _svc in caroline nginx; do
  if systemctl is-active --quiet "$_svc" 2>/dev/null; then
    echo -e "${GREEN}  ✓ ${_svc} running${RESET}"
  else
    echo -e "${YELLOW}  ⚠ ${_svc} not running — check: sudo systemctl status ${_svc}${RESET}"
    _svc_ok=false
  fi
done
if [ "$INSTALL_OLLAMA" = "y" ] || [ "$INSTALL_OLLAMA" = "Y" ]; then
  if systemctl is-active --quiet ollama 2>/dev/null; then
    echo -e "${GREEN}  ✓ ollama running${RESET}"
  else
    echo -e "${YELLOW}  ⚠ ollama not running — check: sudo systemctl status ollama${RESET}"
    _svc_ok=false
  fi
fi
unset _svc _svc_ok

# ── DONE ─────────────────────────────────────────────────────
phase "SHE'S ONLINE"
PI_IP_FINAL=$(hostname -I | awk '{print $1}')
[ -n "$PI_IP_FINAL" ] || PI_IP_FINAL="localhost"
echo ""
echo -e "${CYAN}  ════════════════════════════════════════════════════════════${RESET}"
echo ""
echo -e "${BOLD}${GREEN}  She's online. Soft signal, steady co-pilot energy.${RESET}"
echo ""
echo -e "${CYAN}  ┌─────────────────────────────────────────────────────────┐${RESET}"
echo -e "${CYAN}  │  PROJECT: CAROLINE — ONLINE                             │${RESET}"
echo -e "${CYAN}  ├─────────────────────────────────────────────────────────┤${RESET}"
echo -e "${CYAN}  │${RESET}  Kiosk URL:   ${BOLD}http://${PI_IP_FINAL}:${KIOSK_PORT}/${RESET}"
echo -e "${CYAN}  │${RESET}  Node-RED:    http://${PI_IP_FINAL}:${NODE_RED_PORT}"
echo -e "${CYAN}  │${RESET}  HTTPS proxy: https://${PI_IP_FINAL}:${HTTPS_PROXY_PORT}"
if [ "$AI_PROVIDER" = "ollama" ]; then
echo -e "${CYAN}  │${RESET}  AI Core:     Local — Ollama (${OLLAMA_MODEL})"
else
echo -e "${CYAN}  │${RESET}  AI Core:     Cloud — OpenRouter (add key in settings)"
fi
echo -e "${CYAN}  └─────────────────────────────────────────────────────────┘${RESET}"
echo ""
echo -e "${DIM}  To check her status anytime:${RESET}"
echo -e "${BOLD}    sudo systemctl status caroline${RESET}"
echo ""
echo -e "${CYAN}  ┌─────────────────────────────────────────────────────────┐${RESET}"
echo -e "${CYAN}  │  CONFIGURE MANUALLY AFTER REBOOT                        │${RESET}"
echo -e "${CYAN}  ├─────────────────────────────────────────────────────────┤${RESET}"
if [ "$AI_PROVIDER" = "openrouter" ]; then
echo -e "${CYAN}  │${RESET}  ${YELLOW}⚡ OpenRouter API key${RESET} — add in Caroline Settings > AI"
fi
echo -e "${CYAN}  │${RESET}  ${DIM}Discord token${RESET}        — Settings > Integrations (optional)"
echo -e "${CYAN}  │${RESET}  ${DIM}Spotify client ID${RESET}    — Settings > Integrations (optional)"
echo -e "${CYAN}  │${RESET}  ${DIM}Google OAuth${RESET}         — Settings > Integrations > Connect Google"
echo -e "${CYAN}  │${RESET}  ${DIM}Hue Bridge IP/key${RESET}    — Settings > Integrations"
echo -e "${CYAN}  └─────────────────────────────────────────────────────────┘${RESET}"
echo ""
echo -e "${MAGENTA}  Reboot to bring her fully online; the signal is green.${RESET}"
echo ""
echo -e "${BOLD}  sudo reboot${RESET}"
echo ""
echo -e "${DIM}  If something's broken: sudo journalctl -u caroline -f${RESET}"
echo -e "${DIM}  Node-RED logs:         sudo journalctl -u caroline --since today${RESET}"
echo ""
echo -e "${CYAN}  ════════════════════════════════════════════════════════════${RESET}"
echo ""
