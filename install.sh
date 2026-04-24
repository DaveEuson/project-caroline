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

# ── GITHUB SOURCE ─────────────────────────────────────────────
GITHUB_RAW="https://raw.githubusercontent.com/daveeuson/project-caroline/main"

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
CAROLINE_VERSION="1.0.0"
NODE_RED_PORT=1880
KIOSK_PORT=8080
AI_MODEL="anthropic/claude-haiku-4.5"
SETTINGS_PATH="/data/caroline_settings.json"

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

clear

echo ""
echo -e "${CYAN}  ██████╗ █████╗ ██████╗  ██████╗ ██╗     ██╗███╗   ██╗███████╗${RESET}"
echo -e "${CYAN} ██╔════╝██╔══██╗██╔══██╗██╔═══██╗██║     ██║████╗  ██║██╔════╝${RESET}"
echo -e "${MAGENTA} ██║     ███████║██████╔╝██║   ██║██║     ██║██╔██╗ ██║█████╗  ${RESET}"
echo -e "${MAGENTA} ██║     ██╔══██║██╔══██╗██║   ██║██║     ██║██║╚██╗██║██╔══╝  ${RESET}"
echo -e "${CYAN} ╚██████╗██║  ██║██║  ██║╚██████╔╝███████╗██║██║ ╚████║███████╗${RESET}"
echo -e "${CYAN}  ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝╚═╝  ╚═══╝╚══════╝${RESET}"
echo ""
echo -e "${DIM}  Your personal AI Chief of Staff — v${CAROLINE_VERSION}${RESET}"
echo -e "${DIM}  Half toy. Half tool. Fully yours.${RESET}"
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
read -p "  Your name: " USER_NAME
read -p "  Your timezone (e.g. America/Los_Angeles): " TIMEZONE
read -p "  Your location (e.g. Portland, OR): " LOCATION
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
  echo -e "${DIM}    llama3.2 will work but may be slow on this machine.${RESET}"
  echo ""
fi

read -p "  Install Ollama for free local AI? (y/N): " INSTALL_OLLAMA
INSTALL_OLLAMA="${INSTALL_OLLAMA:-N}"
echo ""

if [ "$INSTALL_OLLAMA" = "y" ] || [ "$INSTALL_OLLAMA" = "Y" ]; then
  AI_PROVIDER="ollama"
  OLLAMA_MODEL="llama3.2"
  echo -e "${DIM}  Pulling llama3.2 by default. Choose a different model if you want:${RESET}"
  echo -e "${DIM}  (Options: llama3.2, phi3:mini, gemma2:2b — Enter to keep llama3.2)${RESET}"
  read -p "  Model [llama3.2]: " OLLAMA_MODEL_INPUT
  OLLAMA_MODEL="${OLLAMA_MODEL_INPUT:-llama3.2}"
  echo ""
  echo -e "${DIM}  Good. ${OLLAMA_MODEL} is her brain. Worth the wait.${RESET}"
else
  AI_PROVIDER="openrouter"
  OLLAMA_MODEL="llama3.2"
  echo -e "${DIM}  Cloud mode selected. Add your OpenRouter key in Caroline's settings after install.${RESET}"
fi
echo ""

echo -e "${MAGENTA}  // DISPLAY MODE${RESET}"
echo ""
echo -e "${DIM}  Kiosk mode locks Firefox ESR fullscreen on boot — ideal for a dedicated Pi display.${RESET}"
echo -e "${DIM}  Skip this if you're just testing, or if you don't have a desktop environment.${RESET}"
echo ""
read -p "  Enable kiosk mode on boot? (y/N): " KIOSK_MODE
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

mkdir -p "$REAL_HOME/.node-red"

# Write a minimal settings.js that enables require() in function nodes.
# Single-quoted heredoc delimiter prevents shell expansion of the JS content.
cat > "$REAL_HOME/.node-red/settings.js" << 'SETTINGS_EOF'
module.exports = {
    uiPort: process.env.PORT || 1880,
    functionGlobalContext: {
        fs:     require('fs'),
        crypto: require('crypto'),
    },
    contextStorage: {
        default: { module: 'localfilesystem' }
    },
}
SETTINGS_EOF

sudo chown "$REAL_USER":"$REAL_USER" "$REAL_HOME/.node-red/settings.js"

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

  echo -e "${YELLOW}  ► Pulling ${OLLAMA_MODEL} — this is her brain. Worth the wait.${RESET}"
  ollama serve >/dev/null 2>&1 &
  OLLAMA_PID=$!
  sleep 3

  ollama pull "$OLLAMA_MODEL" >/tmp/caroline-pull.log 2>&1 &
  PULL_PID=$!
  spin "$PULL_PID" "Downloading ${OLLAMA_MODEL}..."
  wait "$PULL_PID"
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}  ✓ Model ${OLLAMA_MODEL} locked and loaded${RESET}"
  else
    echo -e "${YELLOW}  ⚠ Model pull failed — run 'ollama pull ${OLLAMA_MODEL}' manually after install${RESET}"
    echo -e "${DIM}    Log: cat /tmp/caroline-pull.log${RESET}"
  fi

  kill "$OLLAMA_PID" 2>/dev/null || true
  wait "$OLLAMA_PID" 2>/dev/null || true
fi

# ── DATA DIRECTORY ───────────────────────────────────────────
echo -e "${YELLOW}  ► Initializing memory banks at /data/...${RESET}"

sudo mkdir -p /data
sudo chown "$REAL_USER":"$REAL_USER" /data

echo -e "${GREEN}  ✓ Memory banks online${RESET}"

# ── CAROLINE FILES ───────────────────────────────────────────
phase "PHASE 4 — DEPLOYING CAROLINE'S PAYLOAD"

mkdir -p "$CAROLINE_DIR"

echo -e "${YELLOW}  ► Syncing Caroline files from GitHub...${RESET}"

download_file() {
  local src="$1" dest="$2" label="$3"
  if [ -f "$dest" ]; then
    echo -e "${DIM}    $label already present — skipping download${RESET}"
    return 0
  fi
  curl -fsSL "$src" -o "$dest" 2>/tmp/caroline-dl.log && \
    echo -e "${GREEN}    ✓ Downloaded $label${RESET}" || {
    echo -e "${YELLOW}    ⚠ Could not download $label — check internet connection${RESET}"
    echo -e "${DIM}      Manual: curl -fsSL $src -o $dest${RESET}"
    return 1
  }
}

download_file "$GITHUB_RAW/caroline-kiosk.html"      "$CAROLINE_DIR/caroline-kiosk.html"      "caroline-kiosk.html"
download_file "$GITHUB_RAW/flows.json"               "$CAROLINE_DIR/flows.json"               "flows.json"
download_file "$GITHUB_RAW/caroline-agent-loop.json" "$CAROLINE_DIR/caroline-agent-loop.json" "caroline-agent-loop.json (optional)"
download_file "$GITHUB_RAW/caroline-auto-tasks.json" "$CAROLINE_DIR/caroline-auto-tasks.json" "caroline-auto-tasks.json (optional)"
download_file "$GITHUB_RAW/assets/caroline.gif"      "$CAROLINE_DIR/caroline.gif"             "caroline.gif (avatar)"
download_file "$GITHUB_RAW/assets/cat.gif"           "$CAROLINE_DIR/cat.gif"                  "cat.gif (avatar, optional)"
download_file "$GITHUB_RAW/assets/robot.gif"         "$CAROLINE_DIR/robot.gif"                "robot.gif (avatar, optional)"
download_file "$GITHUB_RAW/assets/ghost.gif"         "$CAROLINE_DIR/ghost.gif"                "ghost.gif (avatar, optional)"

if [ ! -f "$CAROLINE_DIR/caroline-kiosk.html" ] || [ ! -f "$CAROLINE_DIR/flows.json" ]; then
  echo ""
  echo -e "${RED}  ✗ Core files are missing and could not be downloaded.${RESET}"
  echo -e "${DIM}    Options:${RESET}"
  echo -e "${DIM}    1. Check your internet connection and rerun the installer${RESET}"
  echo -e "${DIM}    2. Copy files manually: scp caroline-kiosk.html ${REAL_USER}@$(hostname -I | awk '{print $1}'):~/caroline/${RESET}"
  exit 1
fi

echo -e "${GREEN}  ✓ Caroline payload ready${RESET}"

# ── IMPORT NODE-RED FLOWS ────────────────────────────────────
echo -e "${YELLOW}  ► Importing Node-RED flows...${RESET}"

# Merge optional flow modules into main flows
FLOWS_FILE="$CAROLINE_DIR/flows.json"

if [ -f "$CAROLINE_DIR/caroline-agent-loop.json" ]; then
  jq -s '.[0] + .[1]' "$FLOWS_FILE" "$CAROLINE_DIR/caroline-agent-loop.json" > /tmp/caroline-merged-flows.json
  FLOWS_FILE=/tmp/caroline-merged-flows.json
  echo -e "${DIM}    Merged agent loop into flows${RESET}"
fi

if [ -f "$CAROLINE_DIR/caroline-auto-tasks.json" ]; then
  jq -s '.[0] + .[1]' "$FLOWS_FILE" "$CAROLINE_DIR/caroline-auto-tasks.json" > /tmp/caroline-merged-flows.json
  FLOWS_FILE=/tmp/caroline-merged-flows.json
  echo -e "${DIM}    Merged auto-tasks into flows${RESET}"
fi

cp "$FLOWS_FILE" "$REAL_HOME/.node-red/flows.json"

echo -e "${GREEN}  ✓ Flows imported${RESET}"

# ── NODE-RED PALETTE NODES ───────────────────────────────────
echo -e "${YELLOW}  ► Installing Node-RED palette nodes...${RESET}"

cd "$REAL_HOME/.node-red"
for NODE in "${PALETTE_NODES[@]}"; do
  npm install "$NODE" --save >/dev/null 2>&1 &
  NPM_PID=$!
  spin "$NPM_PID" "Installing $NODE..."
  wait "$NPM_PID" || echo -e "${YELLOW}    ⚠ $NODE install failed — can be added later via Node-RED palette manager${RESET}"
done

echo -e "${GREEN}  ✓ Palette nodes installed${RESET}"

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
    index caroline-kiosk.html;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer" always;
    add_header Content-Security-Policy "default-src 'self' 'unsafe-inline' 'unsafe-eval' ws: wss: data: blob: https: http:;" always;

    location / {
        try_files \$uri \$uri/ =404;
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
jq -n \
  --arg name         "$USER_NAME" \
  --arg tz           "${TIMEZONE:-America/New_York}" \
  --arg loc          "$LOCATION" \
  --arg model        "$AI_MODEL" \
  --arg provider     "$AI_PROVIDER" \
  --arg ollamaModel  "$OLLAMA_MODEL" \
  --argjson kiosk    "$([ "$KIOSK_MODE" = "y" ] || [ "$KIOSK_MODE" = "Y" ] && echo true || echo false)" \
  '{
    userName:        $name,
    timezone:        $tz,
    location:        $loc,
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
After=network.target

[Service]
Type=simple
User=${REAL_USER}
WorkingDirectory=${CAROLINE_DIR}
ExecStart=${NODE_RED_BIN} --port ${NODE_RED_PORT}
Restart=on-failure
RestartSec=5
Environment=NODE_RED_HOME=${REAL_HOME}/.node-red

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable caroline
sudo systemctl start caroline

echo -e "${GREEN}  ✓ Caroline service enabled${RESET}"

# ── DEPLOY FLOWS VIA ADMIN API ───────────────────────────────
echo -e "${YELLOW}  ► Deploying Node-RED flows (no login required)...${RESET}"

NR_READY=false
for i in $(seq 1 30); do
  if curl -sf "http://localhost:${NODE_RED_PORT}/" > /dev/null 2>&1; then
    NR_READY=true
    break
  fi
  sleep 2
done

if [ "$NR_READY" = "true" ]; then
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "http://localhost:${NODE_RED_PORT}/flows" \
    -H 'Content-Type: application/json' \
    -H 'Node-RED-API-Version: v2' \
    -d @"$FLOWS_FILE")
  if [ "$HTTP_STATUS" = "204" ] || [ "$HTTP_STATUS" = "200" ]; then
    echo -e "${GREEN}  ✓ Flows deployed — Node-RED is live${RESET}"
  else
    echo -e "${YELLOW}  ⚠ Flow deploy returned HTTP ${HTTP_STATUS} — Node-RED may need a manual restart${RESET}"
  fi
else
  echo -e "${YELLOW}  ⚠ Node-RED didn't respond in time — flows will load from disk on next boot${RESET}"
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

    KIOSK_URL="http://localhost:${KIOSK_PORT}/caroline-kiosk.html"

    # XDG autostart — works on LXDE, GNOME, and Wayfire (Pi OS Desktop default)
    mkdir -p "$REAL_HOME/.config/autostart"
    cat > "$REAL_HOME/.config/autostart/caroline-kiosk.desktop" << EOF
[Desktop Entry]
Type=Application
Name=Project: Caroline
Exec=firefox-esr --kiosk --no-first-run ${KIOSK_URL}
Hidden=false
X-GNOME-Autostart-enabled=true
EOF

    # labwc autostart — Pi OS Bookworm uses labwc as the Wayland compositor
    if command -v labwc &> /dev/null || [ -d "$REAL_HOME/.config/labwc" ]; then
      mkdir -p "$REAL_HOME/.config/labwc"
      # Append only if not already present
      if ! grep -q "caroline-kiosk" "$REAL_HOME/.config/labwc/autostart" 2>/dev/null; then
        echo "sleep 3 && firefox-esr --kiosk --no-first-run ${KIOSK_URL} &" >> "$REAL_HOME/.config/labwc/autostart"
        chmod +x "$REAL_HOME/.config/labwc/autostart"
      fi
      echo -e "${DIM}    labwc autostart configured${RESET}"
    fi

    echo -e "${GREEN}  ✓ Kiosk mode configured${RESET}"
  fi
fi

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
echo -e "${CYAN}  │${RESET}  Kiosk URL:   ${BOLD}http://${PI_IP_FINAL}:${KIOSK_PORT}/caroline-kiosk.html${RESET}"
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
if [ "$AI_PROVIDER" = "openrouter" ]; then
echo -e "${YELLOW}  ⚡ Add your OpenRouter API key in Caroline's settings panel to enable AI.${RESET}"
echo ""
fi
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
