#!/bin/bash

# ============================================================
#   PROJECT: CAROLINE
#   Personal AI Kiosk — install.sh
#   github.com/daveeuson/project-caroline
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
CAROLINE_VERSION="0.2.0-dev"
NODE_RED_PORT=1880
KIOSK_PORT=8080
AI_MODEL="anthropic/claude-haiku-4.5"

# Node-RED palette nodes required by Caroline
PALETTE_NODES=(
  "node-red-contrib-discord-advanced"
  "node-red-contrib-google-calendar"
  "node-red-contrib-google-sheets"
  "node-red-contrib-huemagic"
)

# ── RESOLVE REAL USER (safe even if run with sudo) ───────────
REAL_USER=${SUDO_USER:-$USER}
REAL_HOME=$(eval echo "~$REAL_USER")
CAROLINE_DIR="$REAL_HOME/caroline"
SETTINGS_PATH="$CAROLINE_DIR/caroline_settings.json"

clear

echo ""
echo -e "${CYAN}  ██████╗ █████╗ ██████╗  ██████╗ ██╗     ██╗███╗   ██╗███████╗${RESET}"
echo -e "${CYAN} ██╔════╝██╔══██╗██╔══██╗██╔═══██╗██║     ██║████╗  ██║██╔════╝${RESET}"
echo -e "${MAGENTA} ██║     ███████║██████╔╝██║   ██║██║     ██║██╔██╗ ██║█████╗  ${RESET}"
echo -e "${MAGENTA} ██║     ██╔══██║██╔══██╗██║   ██║██║     ██║██║╚██╗██║██╔══╝  ${RESET}"
echo -e "${CYAN} ╚██████╗██║  ██║██║  ██║╚██████╔╝███████╗██║██║ ╚████║███████╗${RESET}"
echo -e "${CYAN}  ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝╚═╝  ╚═══╝╚══════╝${RESET}"
echo ""
echo -e "${BOLD}${CYAN}  PROJECT: CAROLINE${RESET}  ${DIM}v${CAROLINE_VERSION}${RESET}"
echo -e "${DIM}  Your personal AI Chief of Staff.${RESET}"
echo ""
echo -e "${CYAN}  ════════════════════════════════════════════════════════════${RESET}"
echo ""

sleep 1

# ── OS VERSION CHECK ─────────────────────────────────────────
OS_ID=$(. /etc/os-release 2>/dev/null && echo "$ID" || echo "unknown")
OS_VER=$(. /etc/os-release 2>/dev/null && echo "$VERSION_CODENAME" || echo "unknown")
if [[ "$OS_ID" != "raspbian" && "$OS_ID" != "debian" && "$OS_ID" != "ubuntu" ]]; then
  echo -e "${YELLOW}  ⚠ Unrecognized OS: ${OS_ID} ${OS_VER}${RESET}"
  echo -e "${DIM}  Caroline is tested on Raspberry Pi OS and Ubuntu 22.04+.${RESET}"
  echo -e "${DIM}  Continuing anyway — things may break.${RESET}"
  echo ""
fi

# ── INTRO ────────────────────────────────────────────────────
echo -e "${BOLD}  Booting Project: Caroline for the first time.${RESET}"
echo -e "${DIM}  A few questions before she comes online.${RESET}"
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

echo -e "${MAGENTA}  // GOOGLE CALENDAR (optional)${RESET}"
echo ""
echo -e "${DIM}  Google Calendar needs a Service Account JSON file.${RESET}"
echo -e "${DIM}  See README.md for how to create one. Press Enter to skip — you can add it later.${RESET}"
echo ""
read -p "  Path to Google service account JSON (or Enter to skip): " GOOG_SA_PATH </dev/tty
GOOG_SA_PATH="${GOOG_SA_PATH/#\~/$HOME}"
echo ""

echo -e "${MAGENTA}  // DISPLAY MODE${RESET}"
echo ""
echo -e "${DIM}  Kiosk mode locks Firefox ESR fullscreen on boot — ideal for a dedicated Pi display.${RESET}"
echo -e "${DIM}  Skip this if you're just testing, or if you don't have a desktop environment.${RESET}"
echo ""
read -p "  Enable kiosk mode on boot? (y/N): " KIOSK_MODE </dev/tty
echo ""

echo -e "${CYAN}  ════════════════════════════════════════════════════════════${RESET}"
echo ""
echo -e "${BOLD}  Acknowledged. Deploying consciousness to ~/caroline/...${RESET}"
echo ""
sleep 1

# ── DEPENDENCIES ─────────────────────────────────────────────
phase "PHASE 1 — ESTABLISHING UPLINK"

echo -e "${YELLOW}  ► Installing system dependencies...${RESET}"
sudo apt-get update -q 2>/dev/null
sudo apt-get install -y -q curl git ca-certificates gnupg jq nginx 2>/dev/null || {
  echo -e "${RED}  ✗ apt-get failed. Is the network up?${RESET}"
  echo -e "${DIM}    Try: sudo apt-get update && sudo apt-get install -y curl git jq nginx${RESET}"
  exit 1
}
echo -e "${GREEN}  ✓ System dependencies online${RESET}"

# ── NODE.JS ──────────────────────────────────────────────────
echo -e "${YELLOW}  ► Checking Node.js runtime...${RESET}"

if ! command -v node &> /dev/null; then
  echo -e "${DIM}    Node.js not found — installing via NodeSource...${RESET}"
  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - 2>/dev/null
  sudo apt-get install -y nodejs 2>/dev/null || {
    echo -e "${RED}  ✗ Node.js install failed. Try manually: sudo apt-get install -y nodejs${RESET}"
    exit 1
  }
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
  wait "$PULL_PID"
  if [ $? -eq 0 ]; then
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

# ── CAROLINE FILES ───────────────────────────────────────────
phase "PHASE 4 — DEPLOYING CAROLINE'S PAYLOAD"

mkdir -p "$CAROLINE_DIR"

echo -e "${YELLOW}  ► Cloning Caroline from GitHub...${RESET}"

CLONE_DIR="$REAL_HOME/project-caroline"

if [ -d "$CLONE_DIR/.git" ]; then
  echo -e "${DIM}    Repo already present — pulling latest...${RESET}"
  git -C "$CLONE_DIR" pull --ff-only 2>/tmp/caroline-git.log || \
    echo -e "${YELLOW}    ⚠ git pull failed — using existing clone${RESET}"
else
  git clone "https://github.com/daveeuson/project-caroline.git" "$CLONE_DIR" >/tmp/caroline-git.log 2>&1 || {
    echo -e "${RED}  ✗ Git clone failed. Check your internet connection.${RESET}"
    echo -e "${DIM}    Log: cat /tmp/caroline-git.log${RESET}"
    exit 1
  }
fi

echo -e "${DIM}    Copying payload to ${CAROLINE_DIR}...${RESET}"
cp -r "$CLONE_DIR/." "$CAROLINE_DIR/"
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

if [ ! -f "$CAROLINE_DIR/index.html" ] || [ ! -f "$CAROLINE_DIR/flows.json" ]; then
  echo ""
  echo -e "${RED}  ✗ Core files missing after copy. Check clone at: ${CLONE_DIR}${RESET}"
  exit 1
fi

echo -e "${GREEN}  ✓ Caroline payload ready${RESET}"

# ── GOOGLE SERVICE ACCOUNT ───────────────────────────────────
if [ -n "$GOOG_SA_PATH" ] && [ -f "$GOOG_SA_PATH" ]; then
  cp -f "$GOOG_SA_PATH" "$CAROLINE_DIR/caroline-calendar.json"
  cp -f "$GOOG_SA_PATH" "$CAROLINE_DIR/service-account.json"
  sudo chown "$REAL_USER":"$REAL_USER" "$CAROLINE_DIR/caroline-calendar.json"
  sudo chown "$REAL_USER":"$REAL_USER" "$CAROLINE_DIR/service-account.json"
  echo -e "${GREEN}  ✓ Google service account installed${RESET}"
else
  cat > "$CAROLINE_DIR/caroline-calendar.json" << 'GOOGLE_PLACEHOLDER_EOF'
{
  "type": "placeholder",
  "private_key": "",
  "client_email": ""
}
GOOGLE_PLACEHOLDER_EOF
  sudo chown "$REAL_USER":"$REAL_USER" "$CAROLINE_DIR/caroline-calendar.json"
  chmod 600 "$CAROLINE_DIR/caroline-calendar.json"
  echo -e "${DIM}  ℹ Google Calendar: no service account configured — enable in Caroline settings later${RESET}"
fi

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

cp "$FLOWS_FILE" "$CAROLINE_DIR/flows.json"

echo -e "${GREEN}  ✓ Flows imported${RESET}"

# ── GOOGLE SERVICE ACCOUNT PLACEHOLDER ───────────────────────
SERVICE_ACCOUNT_FILE="$CAROLINE_DIR/service-account.json"
if [ ! -f "$SERVICE_ACCOUNT_FILE" ]; then
  cat > "$SERVICE_ACCOUNT_FILE" << 'GOOGLE_PLACEHOLDER_EOF'
{
  "type": "placeholder",
  "private_key": "",
  "client_email": ""
}
GOOGLE_PLACEHOLDER_EOF
  chown "$REAL_USER:$REAL_USER" "$SERVICE_ACCOUNT_FILE"
  chmod 600 "$SERVICE_ACCOUNT_FILE"
  echo -e "${YELLOW}  ⚠ Created placeholder: $SERVICE_ACCOUNT_FILE${RESET}"
  echo -e "${DIM}    Replace with your Google service account JSON to enable calendar/sheets${RESET}"
fi

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

# nginx runs as www-data — needs execute permission on the home directory
# to traverse into ~/caroline, and read access on the files themselves.
sudo chmod o+x "$REAL_HOME"
sudo chmod -R o+rX "$CAROLINE_DIR"

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
EOF

sudo ln -sf /etc/nginx/sites-available/caroline /etc/nginx/sites-enabled/caroline
sudo rm -f /etc/nginx/sites-enabled/default

# Systemd drop-in: clear the port before nginx binds on every boot/restart
sudo mkdir -p /etc/systemd/system/nginx.service.d
sudo tee /etc/systemd/system/nginx.service.d/port-clear.conf > /dev/null << DROPIN_EOF
[Service]
ExecStartPre=/bin/sh -c 'fuser -k ${KIOSK_PORT}/tcp 2>/dev/null; true'
DROPIN_EOF
sudo systemctl daemon-reload

sudo systemctl enable nginx
sudo systemctl restart nginx

echo -e "${GREEN}  ✓ Web server ready on port ${KIOSK_PORT}${RESET}"

# ── WRITE SETTINGS ───────────────────────────────────────────
echo -e "${YELLOW}  ► Writing settings...${RESET}"

# jq writes valid JSON regardless of special characters in user input.
# API key fields are written empty — configure them in Caroline's GUI.
PI_IP=$(hostname -I | awk '{print $1}')
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
    timezone:        $tz,
    location:        $loc,
    zipcode:         $zip,
    zipCode:         $zip,
    nodeRedUrl:      $nrUrl,
    aiModel:         $model,
    aiProvider:      $provider,
    ollamaUrl:       "http://localhost:11434",
    ollamaModel:     $ollamaModel,
    openrouterKey:   "",
    hueIp:           "",
    hueKey:          "",
    calendarId:      "",
    spotifyClientId: "",
    discordToken:    "",
    kioskMode:       $kiosk
  }' > "$SETTINGS_PATH"

echo -e "${GREEN}  ✓ Settings saved${RESET}"

# ── SYSTEMD SERVICE ──────────────────────────────────────────
phase "PHASE 6 — WIRING AUTOSTART"

echo -e "${YELLOW}  ► Configuring Caroline as a system service...${RESET}"

sudo tee /etc/systemd/system/caroline.service > /dev/null << EOF
[Unit]
Description=Project: Caroline — Node-RED
After=network-online.target ollama.service
Wants=network-online.target
Requires=ollama.service

[Service]
Type=simple
User=${REAL_USER}
WorkingDirectory=${CAROLINE_DIR}
ExecStartPre=/bin/sleep 5
ExecStart=${NODE_RED_BIN} --port ${NODE_RED_PORT} --userDir ${CAROLINE_DIR}
ExecStartPost=/bin/bash -c 'sleep 30 && ollama run "$OLLAMA_MODEL" "ready" > /dev/null 2>&1 &'
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

sudo systemctl start caroline

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

# ── KIOSK MODE ───────────────────────────────────────────────
if [ "$KIOSK_MODE" = "y" ] || [ "$KIOSK_MODE" = "Y" ]; then
  echo -e "${YELLOW}  ► Configuring kiosk mode...${RESET}"

  if ! command -v startx &> /dev/null && ! command -v labwc &> /dev/null; then
    echo -e "${YELLOW}  ⚠ No desktop environment detected — skipping kiosk setup.${RESET}"
    echo -e "${DIM}  Kiosk mode requires Pi OS Desktop, not Pi OS Lite.${RESET}"
    echo -e "${DIM}  You can enable it later in Caroline's settings panel.${RESET}"
  else
    sudo apt-get install -y -q xdotool unclutter 2>/dev/null || true
    sudo apt-get install -y -q firefox-esr

    KIOSK_URL="http://localhost:${KIOSK_PORT}/"

    # ── FIREFOX PROFILE: suppress first-run and crash-recovery screens ──
    FIREFOX_PROFILE_DIR="$REAL_HOME/.mozilla/firefox/caroline-kiosk"
    mkdir -p "$FIREFOX_PROFILE_DIR"
    cat > "$FIREFOX_PROFILE_DIR/user.js" << 'USERJS'
user_pref("browser.sessionstore.resume_from_crash", false);
user_pref("browser.aboutwelcome.enabled", false);
user_pref("browser.startup.homepage_override.mstone", "ignore");
user_pref("profile.default_content_setting_values.notifications", 2);
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.tabs.warnOnClose", false);
user_pref("toolkit.telemetry.enabled", false);
user_pref("datareporting.healthreport.uploadEnabled", false);
USERJS
    chown -R "$REAL_USER:$REAL_USER" "$FIREFOX_PROFILE_DIR" 2>/dev/null || true
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
Exec=firefox-esr --kiosk --profile ${FIREFOX_PROFILE_DIR} http://localhost:${KIOSK_PORT}/
Terminal=false
X-GNOME-Autostart-enabled=true
EOF

    # labwc autostart — default Wayland compositor on Pi OS Bookworm (Pi 5)
    # Written unconditionally: labwc may not be in PATH until first boot
    mkdir -p "$REAL_HOME/.config/labwc"
    if ! grep -q "caroline" "$REAL_HOME/.config/labwc/autostart" 2>/dev/null; then
      echo "sleep 3 && /usr/bin/firefox-esr --kiosk --profile ${FIREFOX_PROFILE_DIR} ${KIOSK_URL} &" >> "$REAL_HOME/.config/labwc/autostart"
      chmod +x "$REAL_HOME/.config/labwc/autostart"
    fi
    echo -e "${DIM}    labwc autostart configured${RESET}"

    # wayfire autostart — older Bookworm installs / alternative compositor
    # Written unconditionally: harmless if wayfire is not the active session
    mkdir -p "$REAL_HOME/.config"
    if ! grep -q "caroline" "$REAL_HOME/.config/wayfire.ini" 2>/dev/null; then
      printf '\n[autostart]\ncaroline = /bin/bash -c "sleep 3 && /usr/bin/firefox-esr --kiosk --profile %s %s"\n' "${FIREFOX_PROFILE_DIR}" "${KIOSK_URL}" >> "$REAL_HOME/.config/wayfire.ini"
    fi
    echo -e "${DIM}    wayfire.ini autostart configured${RESET}"

    echo -e "${GREEN}  ✓ Kiosk mode configured${RESET}"
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
echo ""
echo -e "${CYAN}  ════════════════════════════════════════════════════════════${RESET}"
echo ""
echo -e "${BOLD}${GREEN}  She's alive. Try not to annoy her.${RESET}"
echo ""
echo -e "${CYAN}  ┌─────────────────────────────────────────────────────────┐${RESET}"
echo -e "${CYAN}  │  PROJECT: CAROLINE — ONLINE                             │${RESET}"
echo -e "${CYAN}  ├─────────────────────────────────────────────────────────┤${RESET}"
echo -e "${CYAN}  │${RESET}  Kiosk URL:   ${BOLD}http://${PI_IP_FINAL}:${KIOSK_PORT}/${RESET}"
echo -e "${CYAN}  │${RESET}  Node-RED:    http://${PI_IP_FINAL}:${NODE_RED_PORT}"
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
echo -e "${CYAN}  │${RESET}  ${DIM}Hue Bridge IP/key${RESET}    — Settings > API & Network (v0.3)"
if [ -z "$GOOG_SA_PATH" ] || [ ! -f "$GOOG_SA_PATH" ]; then
echo -e "${CYAN}  │${RESET}  ${DIM}Google Calendar JSON${RESET} — see README.md (optional)"
fi
echo -e "${CYAN}  └─────────────────────────────────────────────────────────┘${RESET}"
echo ""
echo -e "${MAGENTA}  Reboot to bring her fully online.${RESET}"
echo ""
echo -e "${BOLD}  sudo reboot${RESET}"
echo ""
echo -e "${DIM}  If something's broken: sudo journalctl -u caroline -f${RESET}"
echo -e "${DIM}  Node-RED logs:         sudo journalctl -u caroline --since today${RESET}"
echo ""
echo -e "${CYAN}  ════════════════════════════════════════════════════════════${RESET}"
echo ""
