#!/usr/bin/env bash
set -Eeuo pipefail

# Project: Caroline experimental SteamOS installer.
# This intentionally avoids pacman/system package installs and does not disable
# SteamOS read-only mode. Everything lives under the deck user's home directory.

CAROLINE_VERSION="0.3.0-beta.5"
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

if [ ! -t 1 ] || [ -n "${NO_COLOR:-}" ]; then
  CYAN=""
  MAGENTA=""
  GREEN=""
  YELLOW=""
  RED=""
  BOLD=""
  DIM=""
  RESET=""
fi

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME="$(eval echo "~$REAL_USER")"
CAROLINE_DIR="$REAL_HOME/caroline"
CAROLINE_PUBLIC_DIR="$CAROLINE_DIR/public"
CLONE_DIR="$REAL_HOME/project-caroline"
NODE_ROOT="$REAL_HOME/.local/caroline-node"
NODE_CURRENT="$NODE_ROOT/current"
OLLAMA_ROOT="$REAL_HOME/.local/ollama"
OLLAMA_BIN="$OLLAMA_ROOT/bin/ollama"
OLLAMA_MODELS_DIR="$REAL_HOME/.local/share/ollama/models"
NODERED_RUNTIME="$CAROLINE_DIR/node-red-runtime"
export CAROLINE_DIR CAROLINE_PUBLIC_DIR

say() { echo -e "$*"; }
need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    say "${RED}  x Missing required command: $1${RESET}"
    exit 1
  fi
}
can_prompt() {
  [ "${CAROLINE_NONINTERACTIVE:-false}" != "true" ] && [ -r /dev/tty ] && [ -w /dev/tty ]
}
ask_yes_no() {
  local prompt="$1"
  local default="${2:-n}"
  local hint answer
  if [ "$default" = "y" ] || [ "$default" = "Y" ]; then
    hint="Y/n"
  else
    hint="y/N"
  fi
  if ! can_prompt; then
    [ "$default" = "y" ] || [ "$default" = "Y" ]
    return $?
  fi
  read -r -p "  ${prompt} (${hint}): " answer </dev/tty
  answer="${answer:-$default}"
  case "$answer" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}
prompt_value() {
  local prompt="$1"
  local default="${2:-}"
  local answer
  if ! can_prompt; then
    printf '%s' "$default"
    return 0
  fi
  if [ -n "$default" ]; then
    read -r -p "  ${prompt} [${default}]: " answer </dev/tty
    printf '%s' "${answer:-$default}"
  else
    read -r -p "  ${prompt}: " answer </dev/tty
    printf '%s' "$answer"
  fi
}
bool_json() {
  case "${1:-false}" in
    true|TRUE|1|y|Y|yes|YES) printf 'true' ;;
    *) printf 'false' ;;
  esac
}
total_ram_mb() {
  awk '/MemTotal/ {printf "%d", $2/1024}' /proc/meminfo 2>/dev/null || echo 0
}
cpu_model_summary() {
  awk -F: '/model name|Hardware|Processor/ {gsub(/^[ \t]+/, "", $2); print $2; exit}' /proc/cpuinfo 2>/dev/null
}

OLLAMA_MODEL_VALUES=("qwen3:1.7b" "mistral:7b" "gemma4:e4b" "qwen3:0.6b" "qwen2.5:1.5b" "qwen2.5:0.5b" "gemma3:1b")
OLLAMA_MODEL_LABELS=(
  "Recommended Steam Deck quality; best Deck balance in Caroline tests"
  "Recommended Bazzite/NVIDIA quality; best RTX 2070 balance in Caroline tests"
  "Bazzite/NVIDIA quality mode; excellent replies, may spill to CPU on 8GB VRAM"
  "Fast Steam Deck fallback; very quick, weaker calendar parsing"
  "Recommended Raspberry Pi quality; balanced local fallback"
  "Tiny fallback for constrained hardware"
  "Safe legacy fallback when Qwen is unavailable"
)
gpu_vram_mb() {
  if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null |
      awk 'NR==1 {gsub(/[^0-9]/, "", $1); found=1; print int($1)} END {if (!found) print 0}'
  else
    echo 0
  fi
}
gpu_summary() {
  local line name mem gpu vendor
  if command -v nvidia-smi >/dev/null 2>&1; then
    line="$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits 2>/dev/null | head -1 || true)"
    if [ -n "$line" ]; then
      name="${line%%,*}"
      mem="${line#*,}"
      name="$(printf '%s' "$name" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
      mem="$(printf '%s' "$mem" | tr -dc '0-9')"
      case "$name" in
        *NVIDIA*|*nvidia*) printf '%s' "$name" ;;
        *) printf 'NVIDIA %s' "$name" ;;
      esac
      [ -n "$mem" ] && printf ' (%sMB VRAM)' "$mem"
      return 0
    fi
  fi
  if command -v lspci >/dev/null 2>&1; then
    gpu="$(lspci 2>/dev/null | awk -F': ' '/VGA compatible controller|3D controller|Display controller/ {print $2; exit}')"
    if [ -n "$gpu" ]; then
      printf '%s' "$gpu"
      return 0
    fi
  fi
  for vendor in /sys/class/drm/card*/device/vendor; do
    [ -r "$vendor" ] || continue
    case "$(cat "$vendor" 2>/dev/null)" in
      0x10de) printf 'NVIDIA GPU'; return 0 ;;
      0x1002|0x1022) printf 'AMD GPU'; return 0 ;;
      0x8086) printf 'Intel GPU'; return 0 ;;
    esac
  done
}
recommended_ollama_model() {
  local ram_mb="${1:-$(total_ram_mb)}"
  if [ "$ram_mb" -gt 0 ] && [ "$ram_mb" -lt 4096 ]; then
    printf 'qwen2.5:0.5b'
  elif [ "${HOME_LINUX_PROFILE:-}" = "bazzite" ] && [ "$(gpu_vram_mb)" -ge 7000 ]; then
    printf 'mistral:7b'
  else
    printf 'qwen3:1.7b'
  fi
}
choose_ollama_model() {
  local recommended="${1:-qwen3:1.7b}"
  local i choice
  if ! can_prompt; then
    printf '%s' "$recommended"
    return 0
  fi
  say "${DIM}  Choose a tested Ollama model:${RESET}" >/dev/tty
  for i in "${!OLLAMA_MODEL_VALUES[@]}"; do
    if [ "${OLLAMA_MODEL_VALUES[$i]}" = "$recommended" ]; then
      say "  $((i+1))) ${BOLD}${OLLAMA_MODEL_VALUES[$i]}${RESET} ${DIM}${OLLAMA_MODEL_LABELS[$i]}${RESET}" >/dev/tty
    else
      say "  $((i+1))) ${OLLAMA_MODEL_VALUES[$i]} ${DIM}${OLLAMA_MODEL_LABELS[$i]}${RESET}" >/dev/tty
    fi
  done
  read -r -p "  Model number or exact Ollama name [${recommended}]: " choice </dev/tty
  choice="${choice:-$recommended}"
  case "$choice" in
    1) printf '%s' "${OLLAMA_MODEL_VALUES[0]}" ;;
    2) printf '%s' "${OLLAMA_MODEL_VALUES[1]}" ;;
    3) printf '%s' "${OLLAMA_MODEL_VALUES[2]}" ;;
    4) printf '%s' "${OLLAMA_MODEL_VALUES[3]}" ;;
    5) printf '%s' "${OLLAMA_MODEL_VALUES[4]}" ;;
    6) printf '%s' "${OLLAMA_MODEL_VALUES[5]}" ;;
    7) printf '%s' "${OLLAMA_MODEL_VALUES[6]}" ;;
    *) printf '%s' "$choice" ;;
  esac
}
ollama_cli() {
  if [ -x "$OLLAMA_BIN" ]; then
    printf '%s' "$OLLAMA_BIN"
  elif command -v ollama >/dev/null 2>&1; then
    command -v ollama
  fi
}
wait_for_ollama() {
  local i
  for i in $(seq 1 30); do
    if curl -fsS "http://127.0.0.1:11434/api/tags" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}
install_portable_ollama() {
  local model="$1"
  local tmp_dir tmp_tar cli_path
  if curl -fsS "http://127.0.0.1:11434/api/tags" >/dev/null 2>&1; then
    say "${GREEN}  ✓ Existing Ollama service is already responding at localhost:11434${RESET}"
  else
    mkdir -p "$OLLAMA_ROOT" "$OLLAMA_MODELS_DIR" "$REAL_HOME/.local/bin" "$REAL_HOME/.config/systemd/user"
    if [ ! -x "$OLLAMA_BIN" ]; then
      say "${YELLOW}  > Downloading portable Ollama for SteamOS...${RESET}"
      say "${DIM}    This is a large download because Ollama bundles local runtime libraries.${RESET}"
      tmp_dir="$(mktemp -d)"
      tmp_tar="$tmp_dir/ollama-linux-amd64.tar.zst"
      if ! curl -fL "https://ollama.com/download/ollama-linux-amd64.tar.zst" -o "$tmp_tar"; then
        rm -rf "$tmp_dir"
        say "${YELLOW}  ! Ollama download failed. Caroline will stay on OpenRouter for now.${RESET}"
        return 1
      fi
      if ! tar -C "$tmp_dir" -xf "$tmp_tar"; then
        rm -rf "$tmp_dir"
        say "${YELLOW}  ! Ollama archive extraction failed. SteamOS may be missing zstd tar support.${RESET}"
        return 1
      fi
      rm -rf "$OLLAMA_ROOT/bin" "$OLLAMA_ROOT/lib"
      mv "$tmp_dir/bin" "$tmp_dir/lib" "$OLLAMA_ROOT/"
      rm -rf "$tmp_dir"
    fi
    ln -sfn "$OLLAMA_BIN" "$REAL_HOME/.local/bin/ollama"

    cat > "$REAL_HOME/.config/systemd/user/ollama.service" <<OLLAMA_SERVICE_EOF
[Unit]
Description=Ollama SteamOS portable service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${REAL_HOME}
Environment=OLLAMA_HOST=127.0.0.1:11434
Environment=OLLAMA_ORIGINS=http://localhost:${CAROLINE_PORT},http://127.0.0.1:${CAROLINE_PORT}
Environment=OLLAMA_MODELS=${OLLAMA_MODELS_DIR}
Environment=PATH=${OLLAMA_ROOT}/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=${OLLAMA_BIN} serve
UMask=0077
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
OLLAMA_SERVICE_EOF

    systemctl --user daemon-reload
    systemctl --user enable ollama.service >/dev/null 2>&1 || true
    systemctl --user restart ollama.service >/dev/null 2>&1 || true
    OLLAMA_USER_SERVICE_ENABLED="true"

    if wait_for_ollama; then
      say "${GREEN}  ✓ Ollama is responding at localhost:11434${RESET}"
    else
      say "${YELLOW}  ! Ollama did not respond yet. Check: journalctl --user -u ollama -n 80 --no-pager${RESET}"
      return 1
    fi
  fi

  cli_path="$(ollama_cli)"
  if [ -z "$cli_path" ]; then
    say "${YELLOW}  ! Ollama is running, but no ollama CLI was found for pulling ${model}.${RESET}"
    return 0
  fi
  say "${YELLOW}  > Pulling ${model} for local AI...${RESET}"
  if OLLAMA_HOST="http://127.0.0.1:11434" "$cli_path" pull "$model"; then
    say "${GREEN}  ✓ Model ${model} ready${RESET}"
    (timeout 45s env OLLAMA_HOST="http://127.0.0.1:11434" "$cli_path" run "$model" "hello" >/tmp/caroline-steamos-ollama-warmup.log 2>&1 || true) &
  else
    say "${YELLOW}  ! Model pull failed. You can retry later with: ollama pull ${model}${RESET}"
  fi
  return 0
}

supported_home_linux_profile() {
  [ -r /etc/os-release ] || return 1
  . /etc/os-release
  case "${ID:-}" in
    steamos|bazzite) printf '%s' "$ID"; return 0 ;;
    *) return 1 ;;
  esac
}

HOME_LINUX_PROFILE="$(supported_home_linux_profile || true)"
if [ -z "$HOME_LINUX_PROFILE" ]; then
  say "${RED}This experimental installer is only for SteamOS-compatible home-directory installs.${RESET}"
  say "${DIM}Supported here: SteamOS and Bazzite. Use install.sh for Raspberry Pi OS, Ubuntu, Debian, or Ubuntu-family desktops.${RESET}"
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
case "$HOME_LINUX_PROFILE" in
  bazzite)
    CAROLINE_PLATFORM="bazzite"
    CAROLINE_HOST_DEVICE_TYPE="Bazzite"
    CAROLINE_HARDWARE_PROFILE="Bazzite / SteamOS-compatible PC"
    CAROLINE_HOME_LABEL="Bazzite"
    ;;
  *)
    CAROLINE_PLATFORM="steamos"
    CAROLINE_HOST_DEVICE_TYPE="Steam"
    CAROLINE_HARDWARE_PROFILE="Steam Deck / SteamOS"
    CAROLINE_HOME_LABEL="SteamOS"
    ;;
esac
export CAROLINE_PLATFORM CAROLINE_HOST_DEVICE_TYPE CAROLINE_HARDWARE_PROFILE CAROLINE_HOME_LABEL
existing_bind_host() {
  if [ -f "$CAROLINE_DIR/settings.js" ]; then
    sed -n 's/.*uiHost: process\.env\.CAROLINE_BIND_HOST || "\([^"]*\)".*/\1/p' "$CAROLINE_DIR/settings.js" | head -1
  fi
}
EXISTING_BIND_HOST="$(existing_bind_host)"
CAROLINE_BIND_HOST="${CAROLINE_BIND_HOST:-${EXISTING_BIND_HOST:-127.0.0.1}}"
export CAROLINE_BIND_HOST

say "${BOLD}${CYAN}  Project: Caroline${RESET} ${DIM}${CAROLINE_HOME_LABEL} experimental installer v${CAROLINE_VERSION}${RESET}"
say "${DIM}  Home-directory install. No system package manager changes.${RESET}"
say ""

say "${MAGENTA}  // ${CAROLINE_HOME_LABEL^^} PREFLIGHT${RESET}"
. /etc/os-release
say "${DIM}  OS: ${PRETTY_NAME:-$CAROLINE_HOME_LABEL} ${VERSION_ID:-unknown}${RESET}"
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
export PATH="$NODE_CURRENT/bin:$OLLAMA_ROOT/bin:$REAL_HOME/.local/bin:$PATH"
say "${GREEN}  ✓ Node $(node --version) ready at ${NODE_CURRENT}${RESET}"
say "${GREEN}  ✓ npm $(npm --version) ready${RESET}"
say ""

existing_setting() {
  local key="$1"
  node - "$CAROLINE_DIR/caroline_settings.json" "$key" <<'NODE_EXISTING'
const fs = require('fs');
const [file, key] = process.argv.slice(2);
try {
  const data = JSON.parse(fs.readFileSync(file, 'utf8'));
  const value = data && data[key];
  if (value !== undefined && value !== null) process.stdout.write(String(value));
} catch (_) {}
NODE_EXISTING
}

say "${MAGENTA}  // CAROLINE ARCHIVE - OPERATOR RECORD${RESET}"
say "${DIM}  Press Enter to keep the suggested value.${RESET}"
EXISTING_USER_NAME="$(existing_setting userName)"
EXISTING_AI_NAME="$(existing_setting aiName)"
USER_NAME="${CAROLINE_USER_NAME:-$(prompt_value "Your name" "$EXISTING_USER_NAME")}"
AI_NAME="${CAROLINE_AI_NAME:-$(prompt_value "Assistant name" "${EXISTING_AI_NAME:-Caroline}")}"
[ -n "$AI_NAME" ] || AI_NAME="Caroline"
say ""

say "${MAGENTA}  // CAROLINE ARCHIVE - ASSISTANT CORE${RESET}"
TOTAL_RAM_MB="$(total_ram_mb)"
CPU_MODEL="$(cpu_model_summary)"
GPU_VRAM_MB="$(gpu_vram_mb)"
GPU_SUMMARY="$(gpu_summary)"
RECOMMENDED_OLLAMA_MODEL="$(recommended_ollama_model "$TOTAL_RAM_MB")"
say "${DIM}  Best experience: OpenRouter. Use your API key in Settings -> AI.${RESET}"
if [ "$CAROLINE_PLATFORM" = "bazzite" ] && [ "$GPU_VRAM_MB" -ge 7000 ]; then
  say "${DIM}  Recommended local model: mistral:7b for RTX 2070-class Bazzite hosts.${RESET}"
  say "${DIM}  Fast fallback: qwen3:1.7b.${RESET}"
  say "${DIM}  Quality mode: gemma4:e4b, but it may spill CPU/GPU on 8GB VRAM.${RESET}"
else
  say "${DIM}  Recommended local model: qwen3:1.7b.${RESET}"
  say "${DIM}  Fast fallback: qwen3:0.6b.${RESET}"
fi
say "${DIM}  Safe/legacy fallback: gemma3:1b.${RESET}"
say "${CYAN}  Detected hardware:${RESET} ${BOLD}${CAROLINE_HARDWARE_PROFILE}${RESET} ${DIM}(${ARCH}, ${TOTAL_RAM_MB:-0}MB RAM)${RESET}"
if [ -n "$CPU_MODEL" ]; then
  say "${DIM}    CPU: ${CPU_MODEL}${RESET}"
fi
if [ -n "$GPU_SUMMARY" ]; then
  say "${DIM}    GPU: ${GPU_SUMMARY}${RESET}"
elif [ "$GPU_VRAM_MB" -gt 0 ]; then
  say "${DIM}    NVIDIA VRAM: ${GPU_VRAM_MB}MB${RESET}"
else
  say "${DIM}    GPU: not detected; using SteamOS/local fallback guidance${RESET}"
fi
say "${CYAN}  Suggested local model:${RESET} ${BOLD}${RECOMMENDED_OLLAMA_MODEL}${RESET}"
    say "${DIM}    Local model support is experimental; Ollama can be installed as a user service without changing system packages.${RESET}"
say ""
INSTALL_OLLAMA="n"
OLLAMA_USER_SERVICE_ENABLED="false"
EXISTING_AI_PROVIDER="$(existing_setting aiProvider)"
EXISTING_OLLAMA_MODEL="$(existing_setting ollamaModel)"
if [ -n "${CAROLINE_AI_PROVIDER:-}" ]; then
  AI_PROVIDER="$CAROLINE_AI_PROVIDER"
  OLLAMA_MODEL="${CAROLINE_OLLAMA_MODEL:-${EXISTING_OLLAMA_MODEL:-$RECOMMENDED_OLLAMA_MODEL}}"
  if [ "$AI_PROVIDER" = "ollama" ] && [ "${CAROLINE_INSTALL_OLLAMA:-false}" = "true" ]; then
    INSTALL_OLLAMA="y"
    say "${MAGENTA}  // LOCAL AI - OLLAMA${RESET}"
    if install_portable_ollama "$OLLAMA_MODEL"; then
      say "${GREEN}  ✓ Ollama setup complete${RESET}"
    else
      AI_PROVIDER="openrouter"
      INSTALL_OLLAMA="n"
      say "${YELLOW}  ! Falling back to OpenRouter mode. Local Ollama remains available later in Settings.${RESET}"
    fi
    say ""
  fi
elif ! can_prompt && [ -n "$EXISTING_AI_PROVIDER" ]; then
  AI_PROVIDER="$EXISTING_AI_PROVIDER"
  OLLAMA_MODEL="${EXISTING_OLLAMA_MODEL:-$RECOMMENDED_OLLAMA_MODEL}"
  say "${DIM}  Existing AI provider preserved: ${AI_PROVIDER}${RESET}"
elif ask_yes_no "Configure Caroline to try local Ollama mode on this device?" "n"; then
  AI_PROVIDER="ollama"
  OLLAMA_MODEL="$(choose_ollama_model "$RECOMMENDED_OLLAMA_MODEL")"
  if ask_yes_no "Install/start portable Ollama now and pull ${OLLAMA_MODEL}?" "y"; then
    INSTALL_OLLAMA="y"
    say "${MAGENTA}  // LOCAL AI - OLLAMA${RESET}"
    if install_portable_ollama "$OLLAMA_MODEL"; then
      say "${GREEN}  ✓ Ollama setup complete${RESET}"
    else
      AI_PROVIDER="openrouter"
      INSTALL_OLLAMA="n"
      say "${YELLOW}  ! Falling back to OpenRouter mode. Local Ollama remains available later in Settings.${RESET}"
    fi
    say ""
  else
    say "${DIM}  Selected ${OLLAMA_MODEL}. Start Ollama separately, then use Settings -> AI -> Pull new model.${RESET}"
  fi
else
  AI_PROVIDER="openrouter"
  OLLAMA_MODEL="$RECOMMENDED_OLLAMA_MODEL"
  say "${DIM}  Using OpenRouter mode. Local Ollama remains available later in Settings.${RESET}"
fi
AI_MODEL="anthropic/claude-haiku-4.5"
OLLAMA_URL_DEFAULT="http://localhost:11434"
TIMEZONE="$(timedatectl show -p Timezone --value 2>/dev/null || true)"
[ -n "$TIMEZONE" ] || TIMEZONE="America/Los_Angeles"
say ""

TELEMETRY_INSTALL_COUNT="$(existing_setting telemetryInstallCount)"
TELEMETRY_TROUBLESHOOTING="$(existing_setting telemetryTroubleshooting)"
TELEMETRY_OPT_OUT_PING="$(existing_setting telemetryOptOutPing)"
if [ "$TELEMETRY_INSTALL_COUNT" != "true" ] && [ "$TELEMETRY_INSTALL_COUNT" != "false" ]; then
  say "${MAGENTA}  // PRIVACY BEACON${RESET}"
  say "${DIM}  Caroline can optionally send Dave anonymous project-health pings.${RESET}"
  say "${DIM}  Never sent: chat prompts, memory, settings text, IP address, location, calendar data, OAuth tokens, or API keys.${RESET}"
  say "${DIM}  Remote sending is disabled unless a release telemetry endpoint is configured.${RESET}"
  if ask_yes_no "Send an anonymous SteamOS install/update count to the maintainer?" "n"; then
    TELEMETRY_INSTALL_COUNT="true"
  else
    TELEMETRY_INSTALL_COUNT="false"
    if ask_yes_no "Send one anonymous opt-out count instead?" "n"; then
      TELEMETRY_OPT_OUT_PING="true"
    else
      TELEMETRY_OPT_OUT_PING="false"
    fi
  fi
  if ask_yes_no "Opt in to safe troubleshooting diagnostics for future bug reports?" "n"; then
    TELEMETRY_TROUBLESHOOTING="true"
  else
    TELEMETRY_TROUBLESHOOTING="false"
  fi
else
  say "${DIM}  Privacy choices preserved from existing settings.${RESET}"
  [ "$TELEMETRY_TROUBLESHOOTING" = "true" ] || TELEMETRY_TROUBLESHOOTING="false"
  [ "$TELEMETRY_OPT_OUT_PING" = "true" ] || TELEMETRY_OPT_OUT_PING="false"
fi
say ""

LOCAL_AUTH_ENABLED="$(existing_setting localAuthEnabled)"
if [ "$LOCAL_AUTH_ENABLED" != "true" ] && [ "$LOCAL_AUTH_ENABLED" != "false" ]; then
  say "${MAGENTA}  // LOCAL ACCESS${RESET}"
  if [ "$CAROLINE_BIND_HOST" = "127.0.0.1" ] || [ "$CAROLINE_BIND_HOST" = "localhost" ]; then
    say "${DIM}  This home-directory install currently binds Caroline to localhost only; use an SSH tunnel from another computer.${RESET}"
  else
    say "${DIM}  This home-directory install binds Caroline to ${CAROLINE_BIND_HOST}; keep port ${CAROLINE_PORT} on a trusted LAN.${RESET}"
  fi
  say "${DIM}  Local browser login is recorded for future remote-access support.${RESET}"
  LOCAL_AUTH_ENABLED="true"
else
  say "${DIM}  Local access choice preserved from existing settings.${RESET}"
fi
say ""

say "${MAGENTA}  // PROJECT FILES${RESET}"
if [ -d "$CLONE_DIR/.git" ]; then
  if [ -n "$(git -C "$CLONE_DIR" status --porcelain 2>/dev/null || true)" ]; then
    CLONE_BACKUP_DIR="${CLONE_DIR}.dirty.$(date +%Y%m%d-%H%M%S)"
    if [ -e "$CLONE_BACKUP_DIR" ]; then
      CLONE_BACKUP_DIR="${CLONE_BACKUP_DIR}.$$"
    fi
    say "${YELLOW}  ! Existing repo cache has local changes; preserving it at ${CLONE_BACKUP_DIR}.${RESET}"
    mv "$CLONE_DIR" "$CLONE_BACKUP_DIR"
    git clone --no-checkout "$CAROLINE_REPO_URL" "$CLONE_DIR"
  else
    say "${DIM}  Existing repo found; syncing ${CAROLINE_CHANNEL}.${RESET}"
    git -C "$CLONE_DIR" remote set-url origin "$CAROLINE_REPO_URL" >/dev/null 2>&1 || true
    git -C "$CLONE_DIR" fetch --tags --force origin
  fi
elif [ -e "$CLONE_DIR" ]; then
  CLONE_BACKUP_DIR="${CLONE_DIR}.old.$(date +%Y%m%d-%H%M%S)"
  if [ -e "$CLONE_BACKUP_DIR" ]; then
    CLONE_BACKUP_DIR="${CLONE_BACKUP_DIR}.$$"
  fi
  say "${YELLOW}  ! Existing project cache is not a git repo; preserving it at ${CLONE_BACKUP_DIR}.${RESET}"
  mv "$CLONE_DIR" "$CLONE_BACKUP_DIR"
  git clone --no-checkout "$CAROLINE_REPO_URL" "$CLONE_DIR"
else
  git clone --no-checkout "$CAROLINE_REPO_URL" "$CLONE_DIR"
fi

checkout_channel() {
  if git -C "$CLONE_DIR" show-ref --verify --quiet "refs/remotes/origin/${CAROLINE_CHANNEL}"; then
    if git -C "$CLONE_DIR" checkout -B "$CAROLINE_CHANNEL" "origin/${CAROLINE_CHANNEL}"; then
      return 0
    fi
    return 1
  fi
  if git -C "$CLONE_DIR" show-ref --verify --quiet "refs/tags/${CAROLINE_CHANNEL}"; then
    if git -C "$CLONE_DIR" checkout --detach "refs/tags/${CAROLINE_CHANNEL}"; then
      return 0
    fi
    return 1
  fi
  return 2
}

CHECKOUT_STATUS=0
checkout_channel || CHECKOUT_STATUS=$?
if [ "$CHECKOUT_STATUS" -eq 2 ]; then
  say "${RED}  x Channel not found: ${CAROLINE_CHANNEL}${RESET}"
  exit 1
fi
if [ "$CHECKOUT_STATUS" -ne 0 ]; then
  CLONE_BACKUP_DIR="${CLONE_DIR}.checkout-conflict.$(date +%Y%m%d-%H%M%S)"
  if [ -e "$CLONE_BACKUP_DIR" ]; then
    CLONE_BACKUP_DIR="${CLONE_BACKUP_DIR}.$$"
  fi
  say "${YELLOW}  ! Repo cache checkout failed; preserving it at ${CLONE_BACKUP_DIR} and recloning.${RESET}"
  mv "$CLONE_DIR" "$CLONE_BACKUP_DIR"
  git clone --no-checkout "$CAROLINE_REPO_URL" "$CLONE_DIR"
  if ! checkout_channel; then
    say "${RED}  x Unable to check out channel: ${CAROLINE_CHANNEL}${RESET}"
    exit 1
  fi
fi

mkdir -p "$CAROLINE_DIR"
rm -rf "$CAROLINE_DIR/.git"
tar --exclude='./.git' -C "$CLONE_DIR" -cf - . | tar -C "$CAROLINE_DIR" -xf -

BUILD_COMMIT="$(git -C "$CLONE_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)"
BUILD_BRANCH="$(git -C "$CLONE_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "$CAROLINE_CHANNEL")"
BUILD_INSTALLED_AT="$(date -Is)"
BUILD_HOSTNAME="$(hostname -s 2>/dev/null || hostname 2>/dev/null || echo steamdeck)"
BUILD_GPU_SUMMARY="${GPU_SUMMARY:-$(gpu_summary)}"
BUILD_GPU_VRAM_MB="${GPU_VRAM_MB:-$(gpu_vram_mb)}"
export BUILD_COMMIT BUILD_BRANCH BUILD_INSTALLED_AT BUILD_HOSTNAME BUILD_GPU_SUMMARY BUILD_GPU_VRAM_MB CAROLINE_VERSION CAROLINE_REPO_URL CAROLINE_CHANNEL
node <<'NODE_BUILD'
const fs = require('fs');
const path = process.env.CAROLINE_DIR;
const build = {
  version: process.env.CAROLINE_VERSION || '',
  commit: process.env.BUILD_COMMIT || 'unknown',
  branch: process.env.BUILD_BRANCH || process.env.CAROLINE_CHANNEL || 'unknown',
  channel: process.env.CAROLINE_CHANNEL || '',
  repo: process.env.CAROLINE_REPO_URL || '',
  installedAt: process.env.BUILD_INSTALLED_AT || new Date().toISOString(),
  hostname: process.env.BUILD_HOSTNAME || '',
  platform: process.env.CAROLINE_PLATFORM || 'steamos',
  deviceType: process.env.CAROLINE_HOST_DEVICE_TYPE || 'Steam',
  hardwareProfile: process.env.CAROLINE_HARDWARE_PROFILE || 'Steam Deck / SteamOS',
  gpu: process.env.BUILD_GPU_SUMMARY || '',
  gpuVramMb: Number(process.env.BUILD_GPU_VRAM_MB || 0) || 0
};
fs.writeFileSync(`${path}/caroline_build.json`, JSON.stringify(build, null, 2) + '\n');
NODE_BUILD

rm -rf "$CAROLINE_PUBLIC_DIR"
mkdir -p "$CAROLINE_PUBLIC_DIR"
cp -f "$CAROLINE_DIR/index.html" "$CAROLINE_PUBLIC_DIR/index.html"
cp -f "$CAROLINE_DIR/caroline_build.json" "$CAROLINE_PUBLIC_DIR/caroline_build.json"
if [ -d "$CAROLINE_DIR/assets" ]; then cp -R "$CAROLINE_DIR/assets" "$CAROLINE_PUBLIC_DIR/assets"; fi

CAROLINE_DIR_SED="$(printf '%s' "$CAROLINE_DIR" | sed 's/[&#]/\\&/g')"
for json in "$CAROLINE_DIR/flows.json" "$CAROLINE_DIR/caroline-agent-loop.json" "$CAROLINE_DIR/caroline-auto-tasks.json" "$CAROLINE_DIR/caroline-wonder-loop.json"; do
  [ -f "$json" ] || continue
  sed -i "s#/home/davee/caroline#${CAROLINE_DIR_SED}#g" "$json"
  sed -i "s#127\\.0\\.0\\.1:1880#127.0.0.1:${CAROLINE_PORT}#g; s#localhost:1880#localhost:${CAROLINE_PORT}#g" "$json"
done

node <<'NODE_MERGE'
const fs = require('fs');
const path = process.env.CAROLINE_DIR;
const files = ['flows.json', 'caroline-agent-loop.json', 'caroline-auto-tasks.json', 'caroline-wonder-loop.json'];
const unsupportedSteamOsTypes = new Set(['gauth', 'google-credentials']);
const merged = [];
for (const file of files) {
  const full = `${path}/${file}`;
  if (!fs.existsSync(full)) continue;
  const data = JSON.parse(fs.readFileSync(full, 'utf8'));
  if (!Array.isArray(data)) throw new Error(`${file} is not a flow array`);
  for (const node of data) {
    if (!node || unsupportedSteamOsTypes.has(node.type)) continue;
    if (node.type === 'global-config' && node.modules) {
      delete node.modules['node-red-contrib-google-calendar'];
      delete node.modules['node-red-contrib-google-sheets'];
      if (Object.keys(node.modules).length === 0) delete node.modules;
    }
    merged.push(node);
  }
}
fs.writeFileSync(`${path}/flows.json`, JSON.stringify(merged, null, 2) + '\n');
NODE_MERGE
rm -f "$CAROLINE_DIR/.config.nodes.json" "$CAROLINE_DIR/.config.nodes.json.backup"

if [ ! -s "$CAROLINE_DIR/google_oauth.json" ]; then printf '{}\n' > "$CAROLINE_DIR/google_oauth.json"; fi
if [ ! -s "$CAROLINE_DIR/spotify_auth.json" ]; then printf '{}\n' > "$CAROLINE_DIR/spotify_auth.json"; fi
if [ ! -s "$CAROLINE_DIR/caroline_settings.json" ]; then printf '{}\n' > "$CAROLINE_DIR/caroline_settings.json"; fi
SETTINGS_PATH="$CAROLINE_DIR/caroline_settings.json"
SETTINGS_BACKUP="$SETTINGS_PATH.bak.$(date +%Y%m%d-%H%M%S)"
cp -p "$SETTINGS_PATH" "$SETTINGS_BACKUP" 2>/dev/null || true
export SETTINGS_PATH USER_NAME AI_NAME TIMEZONE AI_MODEL AI_PROVIDER OLLAMA_MODEL OLLAMA_URL_DEFAULT
export TELEMETRY_INSTALL_COUNT TELEMETRY_TROUBLESHOOTING TELEMETRY_OPT_OUT_PING LOCAL_AUTH_ENABLED CAROLINE_PORT
node <<'NODE_SETTINGS'
const fs = require('fs');
const crypto = require('crypto');
const file = process.env.SETTINGS_PATH;
let existing = {};
try {
  existing = JSON.parse(fs.readFileSync(file, 'utf8'));
  if (!existing || typeof existing !== 'object' || Array.isArray(existing)) existing = {};
} catch (_) {}
const bool = (value) => String(value).toLowerCase() === 'true';
const defaults = {
  installId: existing.installId || crypto.randomBytes(16).toString('hex'),
  telemetryInstallCount: bool(process.env.TELEMETRY_INSTALL_COUNT),
  telemetryTroubleshooting: bool(process.env.TELEMETRY_TROUBLESHOOTING),
  telemetryOptOutPing: bool(process.env.TELEMETRY_OPT_OUT_PING),
  telemetryEndpointConfigured: false,
  localAuthEnabled: bool(process.env.LOCAL_AUTH_ENABLED),
  userName: process.env.USER_NAME || existing.userName || '',
  aiName: process.env.AI_NAME || existing.aiName || 'Caroline',
  userMood: existing.userMood ?? 7,
  aiMood: existing.aiMood ?? 7,
  timezone: process.env.TIMEZONE || existing.timezone || 'America/Los_Angeles',
  timeFormat: existing.timeFormat || '12',
  temperatureUnit: existing.temperatureUnit || 'fahrenheit',
  piIp: '127.0.0.1',
  nodeRedUrl: `http://localhost:${process.env.CAROLINE_PORT || 8080}`,
  hostDeviceType: process.env.CAROLINE_HOST_DEVICE_TYPE || 'Steam',
  uiFont: existing.uiFont || 'Noto Sans',
  uiScale: existing.uiScale || 'xlarge',
  uiDensity: existing.uiDensity || 'comfortable',
  highContrastText: existing.highContrastText ?? true,
  reduceMonoLabels: existing.reduceMonoLabels ?? true,
  defaultChannel: existing.defaultChannel ?? 0,
  meetingReminderMinutes: existing.meetingReminderMinutes ?? 0,
  ttsEnabled: existing.ttsEnabled ?? false,
  voiceMuted: existing.voiceMuted ?? true,
  wakeWordEnabled: existing.wakeWordEnabled ?? false,
  wakePhrases: existing.wakePhrases || 'hey caroline, hey ai',
  aiModel: process.env.AI_MODEL || existing.aiModel || 'anthropic/claude-haiku-4.5',
  aiProvider: process.env.AI_PROVIDER || existing.aiProvider || 'openrouter',
  ollamaUrl: process.env.OLLAMA_URL_DEFAULT || existing.ollamaUrl || 'http://localhost:11434',
  ollamaModel: process.env.OLLAMA_MODEL || existing.ollamaModel || 'qwen3:1.7b',
  calendarId: existing.calendarId || 'primary',
  googleRedirectUri: existing.googleRedirectUri || 'http://127.0.0.1:8080/admin/google/callback',
  googleConnected: existing.googleConnected ?? false,
  kioskMode: existing.kioskMode ?? true,
  setupComplete: existing.setupComplete ?? false
};
const merged = { ...existing, ...defaults };
fs.writeFileSync(file, JSON.stringify(merged, null, 2) + '\n');
NODE_SETTINGS
if [ ! -s "$CAROLINE_DIR/.credential_secret" ]; then node -e "process.stdout.write(require('crypto').randomBytes(32).toString('hex') + '\n')" > "$CAROLINE_DIR/.credential_secret"; fi
if [ ! -e "$CAROLINE_DIR/caroline_history.json" ]; then printf '[]\n' > "$CAROLINE_DIR/caroline_history.json"; fi
if [ ! -s "$CAROLINE_DIR/caroline_tasks.json" ]; then printf '{\n  "tasks": [],\n  "updatedAt": null\n}\n' > "$CAROLINE_DIR/caroline_tasks.json"; fi
if [ ! -s "$CAROLINE_DIR/caroline_mind.json" ]; then printf '{\n  "version": 1,\n  "mood": { "curiosity": 0.62, "energy": 0.55, "socialPull": 0.35, "frustration": 0.1, "trust": 0.5 },\n  "wonderQueue": [],\n  "findings": [],\n  "lastOutboundAt": 0,\n  "lastCouncil": null,\n  "updatedAt": null\n}\n' > "$CAROLINE_DIR/caroline_mind.json"; fi
touch "$CAROLINE_DIR/caroline_feedback.jsonl" "$CAROLINE_DIR/caroline_telemetry.jsonl"
chmod 700 "$CAROLINE_DIR" 2>/dev/null || true
chmod 600 \
  "$CAROLINE_DIR/google_oauth.json" \
  "$CAROLINE_DIR/spotify_auth.json" \
  "$CAROLINE_DIR/caroline_settings.json" \
  "$CAROLINE_DIR/.credential_secret" \
  "$CAROLINE_DIR/caroline_history.json" \
  "$CAROLINE_DIR/caroline_tasks.json" \
  "$CAROLINE_DIR/caroline_mind.json" \
  "$CAROLINE_DIR/caroline_feedback.jsonl" \
  "$CAROLINE_DIR/caroline_telemetry.jsonl" 2>/dev/null || true
printf '%s\n' "$CAROLINE_CHANNEL" > "$CAROLINE_DIR/caroline_channel"
chmod 600 "$CAROLINE_DIR/caroline_channel" 2>/dev/null || true
say "${GREEN}  ✓ Caroline files ready at ${CAROLINE_DIR}${RESET}"
say ""

say "${MAGENTA}  // NODE-RED RUNTIME${RESET}"
mkdir -p "$NODERED_RUNTIME"
if [ -f "$NODERED_RUNTIME/package.json" ]; then
  npm --prefix "$NODERED_RUNTIME" uninstall --no-audit --no-fund node-red-contrib-google-calendar node-red-contrib-google-sheets >/dev/null 2>&1 || true
fi
npm --prefix "$NODERED_RUNTIME" install --no-audit --no-fund node-red

cat > "$CAROLINE_DIR/settings.js" <<SETTINGS_EOF
const path = require('path');
const fs = require('fs');
const carolineDir = process.env.CAROLINE_DIR || __dirname;
const publicDir = process.env.CAROLINE_PUBLIC_DIR || path.join(carolineDir, "public");
const credentialSecretPath = path.join(carolineDir, ".credential_secret");
const allowedBrowserOrigin = /^https?:\\/\\/(localhost|127\\.0\\.0\\.1|10(?:\\.\\d{1,3}){3}|192\\.168(?:\\.\\d{1,3}){2}|172\\.(?:1[6-9]|2\\d|3[0-1])(?:\\.\\d{1,3}){2})(:\\d+)?$/i;

function localhostOriginGuard(req, res, next) {
  const origin = req.headers && req.headers.origin;
  if (origin && !allowedBrowserOrigin.test(origin)) {
    res.statusCode = 403;
    res.end("Forbidden");
    return;
  }
  next();
}

module.exports = {
  uiPort: process.env.PORT || ${CAROLINE_PORT},
  uiHost: process.env.CAROLINE_BIND_HOST || "${CAROLINE_BIND_HOST}",
  httpAdminRoot: false,
  httpNodeRoot: "/",
  httpStatic: publicDir,
  flowFile: "flows.json",
  httpRequestTimeout: 120000,
  httpNodeCors: {
    origin: true,
    methods: "GET,PUT,POST,DELETE,OPTIONS"
  },
  credentialSecret: fs.readFileSync(credentialSecretPath, "utf8").trim(),
  httpNodeMiddleware: localhostOriginGuard,
  httpAdminMiddleware: localhostOriginGuard,
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
CAROLINE_SERVICE_AFTER="network-online.target"
CAROLINE_SERVICE_WANTS="network-online.target"
if [ "$AI_PROVIDER" = "ollama" ] && [ "$OLLAMA_USER_SERVICE_ENABLED" = "true" ]; then
  CAROLINE_SERVICE_AFTER="network-online.target ollama.service"
  CAROLINE_SERVICE_WANTS="network-online.target ollama.service"
fi
cat > "$REAL_HOME/.config/systemd/user/caroline.service" <<SERVICE_EOF
[Unit]
Description=Project: Caroline SteamOS experimental service
After=${CAROLINE_SERVICE_AFTER}
Wants=${CAROLINE_SERVICE_WANTS}

[Service]
Type=simple
WorkingDirectory=${CAROLINE_DIR}
Environment=PATH=${NODE_CURRENT}/bin:/usr/local/bin:/usr/bin:/bin
Environment=CAROLINE_DIR=${CAROLINE_DIR}
Environment=PORT=${CAROLINE_PORT}
Environment=CAROLINE_BIND_HOST=${CAROLINE_BIND_HOST}
ExecStart=${NODERED_RUNTIME}/node_modules/.bin/node-red --userDir ${CAROLINE_DIR} --port ${CAROLINE_PORT}
UMask=0077
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
CHROMIUM_PROFILE="\$HOME/.local/share/caroline/chromium-kiosk"
mkdir -p "\$PROFILE" "\$CHROMIUM_PROFILE"
if command -v flatpak >/dev/null 2>&1 && flatpak info org.mozilla.firefox >/dev/null 2>&1; then
  exec flatpak run org.mozilla.firefox --kiosk --new-window "\$URL"
fi
if command -v firefox >/dev/null 2>&1; then
  exec firefox --no-remote --new-instance --profile "\$PROFILE" --kiosk "\$URL"
fi
if command -v chromium >/dev/null 2>&1; then
  exec chromium \\
    --user-data-dir="\$CHROMIUM_PROFILE" \\
    --no-first-run \\
    --no-default-browser-check \\
    --password-store=basic \\
    --disable-session-crashed-bubble \\
    --disable-infobars \\
    --autoplay-policy=no-user-gesture-required \\
    --kiosk "\$URL"
fi
exec xdg-open "\$URL"
KIOSK_EOF
chmod +x "$REAL_HOME/.local/bin/caroline-steamos-kiosk"

cat > "$REAL_HOME/.local/share/applications/caroline-steamos.desktop" <<DESKTOP_EOF
[Desktop Entry]
Type=Application
Name=Project: Caroline
Comment=Open Project: Caroline
Exec=${REAL_HOME}/.local/bin/caroline-steamos-open
Terminal=false
Categories=Utility;
DESKTOP_EOF

cat > "$REAL_HOME/.local/share/applications/caroline-steamos-kiosk.desktop" <<DESKTOP_EOF
[Desktop Entry]
Type=Application
Name=Project: Caroline Kiosk
Comment=Open Project: Caroline fullscreen
Exec=${REAL_HOME}/.local/bin/caroline-steamos-kiosk
Terminal=false
Categories=Utility;
DESKTOP_EOF

cp -f "$REAL_HOME/.local/share/applications/caroline-steamos.desktop" "$REAL_HOME/Desktop/Project: Caroline.desktop" 2>/dev/null || true
cp -f "$REAL_HOME/.local/share/applications/caroline-steamos-kiosk.desktop" "$REAL_HOME/Desktop/Project: Caroline Kiosk.desktop" 2>/dev/null || true
chmod +x "$REAL_HOME/Desktop/Project: Caroline.desktop" "$REAL_HOME/Desktop/Project: Caroline Kiosk.desktop" 2>/dev/null || true

cat > "$REAL_HOME/.local/bin/caroline-update" <<UPDATE_EOF
#!/usr/bin/env bash
set -Eeuo pipefail
LOG="/tmp/caroline-update.log"
LOCK="/tmp/caroline-update.lock"
INSTALLER="/tmp/caroline-install-steamos.sh"
REPO_OWNER="Project-Caroline"
REPO_NAME="project-caroline"
REPO_URL="\${CAROLINE_REPO_URL:-https://github.com/\${REPO_OWNER}/\${REPO_NAME}.git}"
CAROLINE_DIR="${CAROLINE_DIR}"
CLONE_DIR="${CLONE_DIR}"
export PATH="${NODE_CURRENT}/bin:\$HOME/.local/bin:\$PATH"
trap 'code=\$?; echo "\$(date -Is) Project: Caroline GUI update failed (exit \$code)" >> "\$LOG"; exit \$code' ERR

exec 9>"\$LOCK"
if ! flock -n 9; then
  echo "\$(date -Is) update already running" >> "\$LOG"
  exit 0
fi

REPO_CHANNEL="\${CAROLINE_UPDATE_CHANNEL:-}"
if [ -z "\$REPO_CHANNEL" ] && [ -s "\$CAROLINE_DIR/caroline_channel" ]; then
  REPO_CHANNEL="\$(head -n 1 "\$CAROLINE_DIR/caroline_channel" | tr -d '[:space:]' || true)"
fi
if [ -z "\$REPO_CHANNEL" ] && [ -f "\$CAROLINE_DIR/caroline_build.json" ] && command -v node >/dev/null 2>&1; then
  REPO_CHANNEL="\$(node -e 'const fs=require("fs"); const p=process.argv[1]; try{const b=JSON.parse(fs.readFileSync(p,"utf8")); process.stdout.write(b.channel||b.branch||"");}catch(e){}' "\$CAROLINE_DIR/caroline_build.json")"
fi
REPO_CHANNEL="\${REPO_CHANNEL:-nightly}"
case "\$REPO_CHANNEL" in
  ''|*[!A-Za-z0-9._/-]*)
    echo "\$(date -Is) invalid Caroline update channel: \$REPO_CHANNEL" | tee -a "\$LOG"
    exit 1
    ;;
esac

{
  echo "============================================================"
  echo "\$(date -Is) Project: Caroline GUI update requested"
  echo "Target user: \$(id -un)"
  echo "Target home: \$HOME"
  echo "Channel: \$REPO_CHANNEL"
} > "\$LOG"

LOCAL_COMMIT=""
if [ -f "\$CAROLINE_DIR/caroline_build.json" ] && command -v node >/dev/null 2>&1; then
  LOCAL_COMMIT="\$(node -e 'const fs=require("fs"); const p=process.argv[1]; try{const b=JSON.parse(fs.readFileSync(p,"utf8")); process.stdout.write(b.commit||"");}catch(e){}' "\$CAROLINE_DIR/caroline_build.json")"
fi
if [ -z "\$LOCAL_COMMIT" ] && [ -d "\$CLONE_DIR/.git" ]; then
  LOCAL_COMMIT="\$(git -C "\$CLONE_DIR" rev-parse --short HEAD 2>/dev/null || true)"
fi
REMOTE_COMMIT="\$(git ls-remote "\$REPO_URL" "refs/heads/\${REPO_CHANNEL}" 2>/dev/null | awk '{print \$1}' | head -1 || true)"
if [ -z "\$REMOTE_COMMIT" ]; then
  REMOTE_COMMIT="\$(git ls-remote "\$REPO_URL" "refs/tags/\${REPO_CHANNEL}" 2>/dev/null | awk '{print \$1}' | head -1 || true)"
fi
if [ -z "\$REMOTE_COMMIT" ]; then
  echo "\$(date -Is) Project: Caroline GUI update check unavailable (could not reach GitHub)" >> "\$LOG"
  exit 0
fi
if [ -n "\$LOCAL_COMMIT" ] && [ "\${REMOTE_COMMIT#\${LOCAL_COMMIT}}" != "\$REMOTE_COMMIT" ]; then
  echo "\$(date -Is) Project: Caroline GUI update already current (\${LOCAL_COMMIT})" >> "\$LOG"
  exit 0
fi

echo "\$(date -Is) Update available: \${LOCAL_COMMIT:-unknown} -> \${REMOTE_COMMIT:0:7}" >> "\$LOG"
curl -fsSL "https://raw.githubusercontent.com/\${REPO_OWNER}/\${REPO_NAME}/\${REPO_CHANNEL}/install-steamos.sh" -o "\$INSTALLER" >> "\$LOG" 2>&1
chmod 700 "\$INSTALLER"
NO_COLOR=1 TERM=dumb CAROLINE_NONINTERACTIVE=true CAROLINE_DEFER_SERVICE_RESTART=true CAROLINE_CHANNEL="\$REPO_CHANNEL" CAROLINE_REPO_URL="\$REPO_URL" bash "\$INSTALLER" >> "\$LOG" 2>&1
echo "\$(date -Is) Project: Caroline GUI update complete" >> "\$LOG"
nohup bash -lc 'sleep 1; systemctl --user restart caroline.service' >/tmp/caroline-restart.log 2>&1 & || true
UPDATE_EOF
chmod +x "$REAL_HOME/.local/bin/caroline-update"
say "${GREEN}  ✓ SteamOS update helper ready${RESET}"

systemctl --user daemon-reload
systemctl --user enable caroline.service
if [ "${CAROLINE_DEFER_SERVICE_RESTART:-false}" = "true" ]; then
  say "${DIM}  Caroline service restart deferred to update helper.${RESET}"
else
  systemctl --user restart caroline.service
fi

if command -v sudo >/dev/null 2>&1; then
  if sudo -n true >/dev/null 2>&1; then
    sudo loginctl enable-linger "$REAL_USER" >/dev/null 2>&1 || true
  else
    say "${DIM}  Linger not enabled automatically because sudo needs a password.${RESET}"
    say "${DIM}  For auto-start before login, run: sudo loginctl enable-linger ${REAL_USER}${RESET}"
  fi
fi

if [ "${CAROLINE_DEFER_SERVICE_RESTART:-false}" = "true" ]; then
  say "${GREEN}  ✓ Caroline user service files updated${RESET}"
else
  say "${GREEN}  ✓ Caroline user service started${RESET}"
fi
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
if [ "$AI_PROVIDER" = "ollama" ]; then
  if curl -fsS "http://127.0.0.1:11434/api/tags" >/dev/null 2>&1; then
    say "${GREEN}  ✓ Ollama is responding for local AI${RESET}"
  else
    say "${YELLOW}  ! Ollama is selected but not responding yet. Check:${RESET}"
    say "${DIM}    journalctl --user -u ollama -n 80 --no-pager${RESET}"
  fi
fi

say ""
say "${BOLD}${GREEN}  Project: Caroline SteamOS experimental install complete.${RESET}"
say "${CYAN}  URL on Steam Deck:${RESET} ${BOLD}http://localhost:${CAROLINE_PORT}/${RESET}"
if [ "$CAROLINE_BIND_HOST" != "127.0.0.1" ] && [ "$CAROLINE_BIND_HOST" != "localhost" ]; then
  say "${CYAN}  LAN URL:${RESET} ${BOLD}http://$(hostname -I 2>/dev/null | awk '{print $1}'):${CAROLINE_PORT}/${RESET}"
fi
say "${CYAN}  Open command:${RESET} ${BOLD}caroline-steamos-open${RESET}"
say "${CYAN}  Kiosk command:${RESET} ${BOLD}caroline-steamos-kiosk${RESET}"
say "${CYAN}  Desktop launchers:${RESET} ${BOLD}Project: Caroline${RESET} and ${BOLD}Project: Caroline Kiosk${RESET}"
say "${CYAN}  Gaming Mode:${RESET} add ${BOLD}Project: Caroline Kiosk${RESET} as a non-Steam game from Steam Desktop Mode"
say "${CYAN}  Logs:${RESET} ${BOLD}journalctl --user -u caroline -f${RESET}"
if [ "$AI_PROVIDER" = "ollama" ]; then
  say "${CYAN}  Ollama logs:${RESET} ${BOLD}journalctl --user -u ollama -f${RESET}"
fi
if [ "$CAROLINE_BIND_HOST" = "127.0.0.1" ] || [ "$CAROLINE_BIND_HOST" = "localhost" ]; then
  say "${CYAN}  Remote view:${RESET} ${BOLD}ssh -L 8088:127.0.0.1:${CAROLINE_PORT} ${REAL_USER}@STEAM_DECK_IP${RESET}"
fi
say ""
