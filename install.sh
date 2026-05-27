#!/bin/bash

# ============================================================
#   PROJECT: CAROLINE
#   Personal AI Kiosk — install.sh
#   github.com/Project-Caroline/project-caroline
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

if [ ! -t 1 ] || [ -n "${NO_COLOR:-}" ]; then
  CYAN=''
  MAGENTA=''
  YELLOW=''
  GREEN=''
  RED=''
  DIM=''
  BOLD=''
  RESET=''
fi

CAROLINE_NONINTERACTIVE="${CAROLINE_NONINTERACTIVE:-false}"
CAROLINE_CHANNEL="${CAROLINE_CHANNEL:-release}"
_expect_channel_value="false"
for _arg in "$@"; do
  if [ "$_expect_channel_value" = "true" ]; then
    CAROLINE_CHANNEL="$_arg"
    _expect_channel_value="false"
    continue
  fi
  case "$_arg" in
    --noninteractive|--update)
      CAROLINE_NONINTERACTIVE="true"
      ;;
    --nightly)
      CAROLINE_CHANNEL="nightly"
      ;;
    --release)
      CAROLINE_CHANNEL="release"
      ;;
    --channel)
      _expect_channel_value="true"
      ;;
    --channel=*)
      CAROLINE_CHANNEL="${_arg#--channel=}"
      ;;
  esac
done
unset _expect_channel_value

case "$CAROLINE_CHANNEL" in
  ''|*[!A-Za-z0-9._/-]*)
    echo "Invalid CAROLINE_CHANNEL: $CAROLINE_CHANNEL" >&2
    exit 1
    ;;
esac

can_prompt() {
  [ "$CAROLINE_NONINTERACTIVE" != "true" ] && [ -r /dev/tty ] && [ -w /dev/tty ]
}

# ── SPINNER ───────────────────────────────────────────────────
spin() {
  local pid=$1 msg=$2
  local spin='⣾⣽⣻⢿⡿⣟⣯⣷'
  local i=0
  if [ "$CAROLINE_NONINTERACTIVE" = "true" ] || [ ! -t 1 ]; then
    printf "  %s\n" "$msg"
    while kill -0 "$pid" 2>/dev/null; do
      sleep 1
    done
    return 0
  fi
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
  case "$1" in
    *"SYSTEM DEPENDENCIES"*)
      echo -e "${DIM}      [SYS]---[APT]---[NODE]        checking the old lab bench${RESET}"
      ;;
    *"NODE-RED RUNTIME"*)
      echo -e "${DIM}      [FLOW BUS] ===> [EVENT CORE]  wiring the nervous system${RESET}"
      ;;
    *"LOCAL AI"*)
      echo -e "${DIM}      [MODEL BAY] >>> [WARM BOOT]   waking the local fallback${RESET}"
      ;;
    *"APPLICATION FILES"*)
      echo -e "${DIM}      [ARCHIVE] -> [KIOSK SHELL]    restoring Caroline payload${RESET}"
      ;;
    *"WEB INTERFACE"*)
      echo -e "${DIM}      [NGINX] <-> [UI] <-> [WS]     opening the console window${RESET}"
      ;;
    *"SYSTEM SERVICE"*)
      echo -e "${DIM}      [SYSTEMD] :: [AUTOSTART]      pinning Caroline to boot${RESET}"
      ;;
    *"COMPLETE"*)
      echo -e "${DIM}      [ONLINE]  <3  [OPERATOR]      assistant core is stable${RESET}"
      ;;
  esac
  echo ""
}

archive_panel() {
  echo -e "${CYAN}  /==========================================================\\${RESET}"
  echo -e "${CYAN}  |${RESET} ${MAGENTA}CAROLINE ARCHIVE TERMINAL${RESET} ${DIM}:: recovered assistant core${RESET}       ${CYAN}|${RESET}"
  echo -e "${CYAN}  |----------------------------------------------------------|${RESET}"
  echo -e "${CYAN}  |${RESET} ${DIM}[01] memory vault    [02] home signals    [03] kiosk UI${RESET} ${CYAN}|${RESET}"
  echo -e "${CYAN}  |${RESET} ${DIM}[04] AI relay        [05] widgets         [06] automation${RESET}${CYAN}|${RESET}"
  echo -e "${CYAN}  \\==========================================================/${RESET}"
}

ask_yes_no() {
  local prompt="$1"
  local default="${2:-n}"
  local answer
  local suffix="(y/N)"
  if [ "$default" = "y" ] || [ "$default" = "Y" ]; then
    suffix="(Y/n)"
  fi

  if can_prompt; then
    read -p "  ${prompt} ${suffix}: " answer </dev/tty
  else
    answer=""
  fi
  answer="${answer:-$default}"

  case "$answer" in
    y|Y|yes|YES|Yes) return 0 ;;
    *) return 1 ;;
  esac
}

bool_json() {
  case "${1:-false}" in
    true|TRUE|1|y|Y|yes|YES) printf 'true' ;;
    *) printf 'false' ;;
  esac
}

# ── CONFIG ───────────────────────────────────────────────────
CAROLINE_VERSION="0.3.0-beta.4"
CAROLINE_REPO_URL="https://github.com/Project-Caroline/project-caroline.git"
CAROLINE_RAW_BASE="https://raw.githubusercontent.com/Project-Caroline/project-caroline"
NODE_RED_PORT=1880
KIOSK_PORT=8080
HTTPS_PROXY_PORT=8443
HTTPS_UI_PORT=8444
AI_MODEL="anthropic/claude-haiku-4.5"
OLLAMA_URL_DEFAULT="http://localhost:11434"
CAROLINE_TELEMETRY_ENDPOINT="${CAROLINE_TELEMETRY_ENDPOINT:-}"

# Node-RED palette nodes required by Caroline
PALETTE_NODES=(
  "node-red-contrib-google-calendar"
  "node-red-contrib-google-sheets"
)

OLLAMA_MODEL_VALUES=("qwen3:1.7b" "mistral:7b" "gemma4:e4b" "qwen2.5:1.5b" "qwen2.5:0.5b" "gemma3:1b")
OLLAMA_MODEL_LABELS=(
  "Recommended Steam Deck / light GPU quality; best small-host balance"
  "Recommended NVIDIA 8GB quality; best RTX 2070-class balance"
  "Strong GPU quality mode; best on 12GB+ VRAM"
  "Conservative CPU/Pi/VM quality; best low-risk Linux balance"
  "Fast local fallback; quickest on small hardware"
  "Safe/legacy default; stable older-install choice"
)

ollama_model_index() {
  local model="${1:-qwen2.5:1.5b}"
  local i
  for i in "${!OLLAMA_MODEL_VALUES[@]}"; do
    if [ "${OLLAMA_MODEL_VALUES[$i]}" = "$model" ]; then
      printf '%s' "$i"
      return 0
    fi
  done
  printf '0'
}

choose_ollama_model() {
  local recommended="${1:-qwen2.5:1.5b}"
  local selected
  local key rest i
  selected="$(ollama_model_index "$recommended")"

  if [ ! -r /dev/tty ] || [ ! -w /dev/tty ]; then
    printf '%s' "$recommended"
    return 0
  fi

  echo -e "${DIM}  Use ↑/↓ then Enter. You can also press j/k.${RESET}" >/dev/tty
  tput civis >/dev/tty 2>&1 || true

  while true; do
    for i in "${!OLLAMA_MODEL_VALUES[@]}"; do
      if [ "$i" -eq "$selected" ]; then
        echo -e "\r\033[K  ${CYAN}› ${BOLD}${OLLAMA_MODEL_VALUES[$i]}${RESET} ${DIM}${OLLAMA_MODEL_LABELS[$i]}${RESET}" >/dev/tty
      else
        echo -e "\r\033[K    ${OLLAMA_MODEL_VALUES[$i]} ${DIM}${OLLAMA_MODEL_LABELS[$i]}${RESET}" >/dev/tty
      fi
    done

    IFS= read -rsn1 key </dev/tty || break
    case "$key" in
      "")
        break
        ;;
      $'\x1b')
        IFS= read -rsn2 -t 0.2 rest </dev/tty || rest=""
        case "$rest" in
          "[A") selected=$(( (selected - 1 + ${#OLLAMA_MODEL_VALUES[@]}) % ${#OLLAMA_MODEL_VALUES[@]} )) ;;
          "[B") selected=$(( (selected + 1) % ${#OLLAMA_MODEL_VALUES[@]} )) ;;
        esac
        ;;
      k|K)
        selected=$(( (selected - 1 + ${#OLLAMA_MODEL_VALUES[@]}) % ${#OLLAMA_MODEL_VALUES[@]} ))
        ;;
      j|J)
        selected=$(( (selected + 1) % ${#OLLAMA_MODEL_VALUES[@]} ))
        ;;
    esac
    printf "\033[%sA" "${#OLLAMA_MODEL_VALUES[@]}" >/dev/tty
  done

  tput cnorm >/dev/tty 2>&1 || true
  printf '%s' "${OLLAMA_MODEL_VALUES[$selected]}"
}

# ── RESOLVE REAL USER (safe even if run with sudo) ───────────
REAL_USER=${SUDO_USER:-$USER}
REAL_HOME=$(eval echo "~$REAL_USER")
CAROLINE_DIR="$REAL_HOME/caroline"
SETTINGS_PATH="$CAROLINE_DIR/caroline_settings.json"
TELEMETRY_LOG_PATH="$CAROLINE_DIR/caroline_telemetry.jsonl"
CAROLINE_TEMP_SWAP="/var/tmp/caroline-install.swap"
CAROLINE_TEMP_SWAP_CREATED="false"
CAROLINE_AUTH_DIR="/etc/caroline"
CAROLINE_HTPASSWD_PATH="$CAROLINE_AUTH_DIR/caroline.htpasswd"
CAROLINE_ADMIN_PASSWORD_PATH="$CAROLINE_DIR/caroline_admin_password.txt"
CAROLINE_LOCAL_AUTH="${CAROLINE_LOCAL_AUTH:-}"

cleanup_install_swap() {
  tput cnorm 2>/dev/null || true
  if [ "$CAROLINE_TEMP_SWAP_CREATED" = "true" ]; then
    sudo swapoff "$CAROLINE_TEMP_SWAP" >/dev/null 2>&1 || true
    sudo rm -f "$CAROLINE_TEMP_SWAP" >/dev/null 2>&1 || true
  fi
}
trap cleanup_install_swap EXIT

reset_install_logs() {
  if [ "${CAROLINE_PRESERVE_UPDATE_LOG:-false}" = "true" ]; then
    find /tmp -maxdepth 1 -type f -name 'caroline-*.log' ! -name 'caroline-update.log' -delete 2>/dev/null || true
    sudo find /tmp -maxdepth 1 -type f -name 'caroline-*.log' ! -name 'caroline-update.log' -delete 2>/dev/null || true
  else
    rm -f /tmp/caroline-*.log 2>/dev/null || true
    sudo rm -f /tmp/caroline-*.log 2>/dev/null || true
  fi
  rm -f /tmp/caroline-merged-flows.json /tmp/caroline-merged-flows.json.tmp 2>/dev/null || true
  sudo rm -f /tmp/caroline-merged-flows.json /tmp/caroline-merged-flows.json.tmp 2>/dev/null || true
}

ensure_install_swap() {
  local _required_mb="${1:-1800}"
  local _target_mb="${2:-1536}"
  local _min_swap_mb="${3:-0}"
  local _mem_mb _swap_mb _total_mb _free_mb
  _mem_mb=$(awk '/MemTotal:/ {printf "%d", $2/1024}' /proc/meminfo 2>/dev/null || echo 0)
  _swap_mb=$(awk '/SwapTotal:/ {printf "%d", $2/1024}' /proc/meminfo 2>/dev/null || echo 0)
  _total_mb=$((_mem_mb + _swap_mb))

  [ "$_total_mb" -ge "$_required_mb" ] && [ "$_swap_mb" -ge "$_min_swap_mb" ] && return 0

  _free_mb=$(df -Pm /var/tmp 2>/dev/null | awk 'NR==2 {print $4}' || echo 0)
  if [ "${_free_mb:-0}" -lt $((_target_mb + 256)) ]; then
    echo -e "${YELLOW}  ⚠ Install swap recommended (${_mem_mb}MB RAM, ${_swap_mb}MB swap), but /var/tmp lacks room for temporary swap.${RESET}"
    echo -e "${DIM}    If install fails, add swap or free disk space before retrying.${RESET}"
    return 0
  fi

  if [ "$_total_mb" -ge "$_required_mb" ]; then
    echo -e "${YELLOW}  ► No/low swap detected — adding temporary install swap...${RESET}"
  else
    echo -e "${YELLOW}  ► Low-memory server detected — adding temporary install swap...${RESET}"
  fi
  sudo swapoff "$CAROLINE_TEMP_SWAP" >/dev/null 2>&1 || true
  sudo rm -f "$CAROLINE_TEMP_SWAP" >/dev/null 2>&1 || true
  if ! sudo fallocate -l "${_target_mb}M" "$CAROLINE_TEMP_SWAP" >/dev/null 2>&1; then
    sudo dd if=/dev/zero of="$CAROLINE_TEMP_SWAP" bs=1M count="$_target_mb" status=none || {
      echo -e "${YELLOW}  ⚠ Could not create temporary swap. Continuing without it.${RESET}"
      return 0
    }
  fi
  sudo chmod 600 "$CAROLINE_TEMP_SWAP" >/dev/null 2>&1 || true
  sudo mkswap "$CAROLINE_TEMP_SWAP" >/dev/null 2>&1 && sudo swapon "$CAROLINE_TEMP_SWAP" >/dev/null 2>&1 || {
    sudo rm -f "$CAROLINE_TEMP_SWAP" >/dev/null 2>&1 || true
    echo -e "${YELLOW}  ⚠ Could not enable temporary swap. Continuing without it.${RESET}"
    return 0
  }
  CAROLINE_TEMP_SWAP_CREATED="true"
  echo -e "${GREEN}  ✓ Temporary install swap active (${_target_mb}MB)${RESET}"
}

protect_secret_files() {
  local _secret
  for _secret in \
    "$CAROLINE_DIR/caroline_settings.json" \
    "$CAROLINE_DIR/caroline_telemetry.jsonl" \
    "$CAROLINE_DIR/caroline_feedback.jsonl" \
    "$CAROLINE_DIR/google_oauth.json" \
    "$CAROLINE_DIR/caroline_tasks.json" \
    "$CAROLINE_DIR/caroline_mind.json" \
    "$CAROLINE_DIR/caroline_admin_password.txt" \
    "$CAROLINE_DIR/spotify_auth.json" \
    "$CAROLINE_DIR/caroline-calendar.json" \
    "$CAROLINE_DIR/service-account.json"; do
    [ -f "$_secret" ] || continue
    sudo chown "$REAL_USER":"$REAL_USER" "$_secret" 2>/dev/null || true
    chmod 600 "$_secret" 2>/dev/null || true
  done
}

configure_admin_auth() {
  local _password="${CAROLINE_ADMIN_PASSWORD:-}"
  local _hash

  sudo mkdir -p "$CAROLINE_AUTH_DIR"
  if [ -z "$_password" ] && [ -s "$CAROLINE_ADMIN_PASSWORD_PATH" ]; then
    _password="$(cat "$CAROLINE_ADMIN_PASSWORD_PATH" 2>/dev/null || true)"
  fi
  if [ -z "$_password" ]; then
    _password="$(openssl rand -base64 24 2>/dev/null || date +%s-%N-$RANDOM)"
  fi

  _hash="$(openssl passwd -apr1 "$_password")"
  printf 'caroline:%s\n' "$_hash" | sudo tee "$CAROLINE_HTPASSWD_PATH" >/dev/null
  sudo chown root:www-data "$CAROLINE_HTPASSWD_PATH" 2>/dev/null || sudo chown root:root "$CAROLINE_HTPASSWD_PATH"
  sudo chmod 640 "$CAROLINE_HTPASSWD_PATH" 2>/dev/null || sudo chmod 600 "$CAROLINE_HTPASSWD_PATH"

  printf '%s\n' "$_password" > "$CAROLINE_ADMIN_PASSWORD_PATH"
  sudo chown "$REAL_USER":"$REAL_USER" "$CAROLINE_ADMIN_PASSWORD_PATH" 2>/dev/null || true
  chmod 600 "$CAROLINE_ADMIN_PASSWORD_PATH" 2>/dev/null || true
}

normalize_auth_choice() {
  case "$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')" in
    y|yes|true|1|on|enabled) printf 'true' ;;
    n|no|false|0|off|disabled) printf 'false' ;;
    *) printf '' ;;
  esac
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

configure_chromium_profile() {
  local _profile_dir="$1"
  [ -n "$_profile_dir" ] || return 0
  mkdir -p "$_profile_dir"
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

has_desktop_environment() {
  is_wsl && return 1
  [ -n "${DISPLAY:-}" ] && return 0
  [ -n "${WAYLAND_DISPLAY:-}" ] && return 0
  [ -n "${XDG_CURRENT_DESKTOP:-}" ] && return 0
  [ -n "${DESKTOP_SESSION:-}" ] && return 0
  command -v gnome-session >/dev/null 2>&1 && return 0
  command -v startx >/dev/null 2>&1 && return 0
  command -v labwc >/dev/null 2>&1 && return 0
  [ -d /usr/share/xsessions ] && return 0
  [ -d /usr/share/wayland-sessions ] && return 0
  [ -d "$REAL_HOME/Desktop" ] && return 0
  return 1
}

write_desktop_shortcuts() {
  local _desktop_dir="$1"
  local _windowed_file="$_desktop_dir/Project: Caroline.desktop"
  local _kiosk_file="$_desktop_dir/Project: Caroline Kiosk.desktop"

  mkdir -p "$_desktop_dir"
  cat > "$_windowed_file" << EOF
[Desktop Entry]
Type=Application
Name=Project: Caroline
Comment=Launch Project: Caroline in a browser window
Exec=${WINDOWED_LAUNCHER}
Icon=web-browser
Terminal=false
Categories=Utility;
StartupNotify=true
EOF

  cat > "$_kiosk_file" << EOF
[Desktop Entry]
Type=Application
Name=Project: Caroline Kiosk
Comment=Launch Project: Caroline fullscreen kiosk
Exec=${KIOSK_LAUNCHER}
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

write_browser_launchers() {
  local _bin_dir="$REAL_HOME/.local/bin"
  mkdir -p "$_bin_dir"
  WINDOWED_LAUNCHER="$_bin_dir/caroline-window"
  KIOSK_LAUNCHER="$_bin_dir/caroline-kiosk"

  if [ "${BROWSER_FAMILY:-}" = "chromium" ]; then
    cat > "$WINDOWED_LAUNCHER" << EOF
#!/bin/bash
BROWSER="${BROWSER_BIN}"
if [ "\$(basename "\$BROWSER")" = "chromium" ] && [ -x /usr/lib/chromium/chromium ]; then
  BROWSER="/usr/lib/chromium/chromium"
fi
URL="${KIOSK_URL}"
PROFILE="${CHROMIUM_WINDOWED_PROFILE_DIR}"
mkdir -p "\$PROFILE"
exec "\$BROWSER" \\
  --user-data-dir="\$PROFILE" \\
  --no-first-run \\
  --no-default-browser-check \\
  --password-store=basic \\
  --disable-session-crashed-bubble \\
  --disable-infobars \\
  --enable-gpu-rasterization \\
  --use-angle=gles \\
  --autoplay-policy=no-user-gesture-required \\
  --new-window "\$URL"
EOF

    cat > "$KIOSK_LAUNCHER" << EOF
#!/bin/bash
BROWSER="${BROWSER_BIN}"
if [ "\$(basename "\$BROWSER")" = "chromium" ] && [ -x /usr/lib/chromium/chromium ]; then
  BROWSER="/usr/lib/chromium/chromium"
fi
PROFILE="${CHROMIUM_PROFILE_DIR}"
URL="${KIOSK_URL}"
LOCKDIR="/tmp/caroline-kiosk-\$(id -u).lock"
mkdir -p "\$PROFILE"

if [ -d "\$LOCKDIR" ]; then
  if pgrep -u "\$(id -u)" -f "caroline/chromium-kiosk" >/dev/null 2>&1; then
    exit 0
  fi
  rmdir "\$LOCKDIR" 2>/dev/null || true
fi

mkdir "\$LOCKDIR" 2>/dev/null || exit 0
"\$BROWSER" \\
  --user-data-dir="\$PROFILE" \\
  --no-first-run \\
  --no-default-browser-check \\
  --password-store=basic \\
  --disable-session-crashed-bubble \\
  --disable-infobars \\
  --enable-gpu-rasterization \\
  --use-angle=gles \\
  --autoplay-policy=no-user-gesture-required \\
  --kiosk "\$URL"
status=\$?
rmdir "\$LOCKDIR" 2>/dev/null || true
exit \$status
EOF
  else
    FIREFOX_SNAP_MODE="false"
    if command -v snap >/dev/null 2>&1 && snap list firefox >/dev/null 2>&1; then
      FIREFOX_SNAP_MODE="true"
    elif readlink -f "$BROWSER_BIN" 2>/dev/null | grep -q '/snap/'; then
      FIREFOX_SNAP_MODE="true"
    elif dpkg-query -W -f='${Version}' firefox 2>/dev/null | grep -qi 'snap'; then
      FIREFOX_SNAP_MODE="true"
    fi

    cat > "$WINDOWED_LAUNCHER" << EOF
#!/bin/bash
BROWSER="${BROWSER_BIN}"
URL="${KIOSK_URL}"
SNAP_MODE="${FIREFOX_SNAP_MODE}"

if [ "\$SNAP_MODE" = "true" ]; then
  exec "\$BROWSER" --new-window "\$URL"
fi

PROFILE="${WINDOWED_PROFILE_DIR}"
mkdir -p "\$PROFILE"
if ! pgrep -u "\$(id -u)" -f "\$PROFILE" >/dev/null 2>&1; then
  rm -f "\$PROFILE/parent.lock" "\$PROFILE/lock" "\$PROFILE/.parentlock" 2>/dev/null || true
fi
exec "\$BROWSER" --no-remote --new-instance --profile "\$PROFILE" --new-window "\$URL"
EOF

    cat > "$KIOSK_LAUNCHER" << EOF
#!/bin/bash
BROWSER="${BROWSER_BIN}"
PROFILE="${FIREFOX_PROFILE_DIR}"
URL="${KIOSK_URL}"
LOCKDIR="/tmp/caroline-kiosk-\$(id -u).lock"
SNAP_MODE="${FIREFOX_SNAP_MODE}"
mkdir -p "\$PROFILE"

if [ "\$SNAP_MODE" = "true" ]; then
  # Ubuntu ships Firefox as a snap. Custom external profiles can trigger the
  # "already running" dialog, so snap mode uses the user's normal Firefox
  # profile and avoids profile-lock handling entirely.
  exec "\$BROWSER" --kiosk "\$URL"
fi

if [ -d "\$LOCKDIR" ]; then
  if pgrep -u "\$(id -u)" -f "\$PROFILE" >/dev/null 2>&1; then
    exit 0
  fi
  rmdir "\$LOCKDIR" 2>/dev/null || true
fi

if ! pgrep -u "\$(id -u)" -f "\$PROFILE" >/dev/null 2>&1; then
  rm -f "\$PROFILE/parent.lock" "\$PROFILE/lock" "\$PROFILE/.parentlock" 2>/dev/null || true
fi

mkdir "\$LOCKDIR" 2>/dev/null || exit 0
"\$BROWSER" --no-remote --new-instance --profile "\$PROFILE" --kiosk "\$URL"
status=\$?
rmdir "\$LOCKDIR" 2>/dev/null || true
exit \$status
EOF
  fi

  chmod +x "$WINDOWED_LAUNCHER" "$KIOSK_LAUNCHER"
  chown "$REAL_USER:$REAL_USER" "$WINDOWED_LAUNCHER" "$KIOSK_LAUNCHER" 2>/dev/null || true
}

safe_cmd_version() {
  local _cmd="$1"
  shift || true
  if command -v "$_cmd" >/dev/null 2>&1; then
    "$_cmd" "$@" 2>/dev/null | head -1 | tr -d '\r'
  fi
}

caroline_device_model() {
  if [ -r /proc/device-tree/model ]; then
    tr -d '\0' < /proc/device-tree/model 2>/dev/null || true
    return 0
  fi
  local _path
  for _path in /sys/class/dmi/id/product_name /sys/class/dmi/id/board_name /sys/class/dmi/id/sys_vendor; do
    if [ -r "$_path" ]; then
      tr -d '\0' < "$_path" 2>/dev/null | head -1
      return 0
    fi
  done
}

total_ram_mb() {
  awk '/MemTotal/ {printf "%d", $2/1024}' /proc/meminfo 2>/dev/null || echo 0
}

cpu_model_summary() {
  awk -F: '/model name|Hardware|Processor/ {gsub(/^[ \t]+/, "", $2); print $2; exit}' /proc/cpuinfo 2>/dev/null
}

os_release_field() {
  local _key="$1"
  [ -r /etc/os-release ] || return 0
  awk -F= -v key="$_key" '
    $1 == key {
      value=$0
      sub(/^[^=]*=/, "", value)
      gsub(/^"/, "", value)
      gsub(/"$/, "", value)
      print value
      exit
    }
  ' /etc/os-release 2>/dev/null
}

os_label() {
  local _id="${1:-$(os_release_field ID)}"
  local _id_like="${2:-$(os_release_field ID_LIKE)}"
  case "$_id" in
    raspbian) printf 'Raspberry Pi OS' ;;
    ubuntu) printf 'Ubuntu' ;;
    debian) printf 'Debian' ;;
    pop) printf 'Pop!_OS' ;;
    linuxmint) printf 'Linux Mint' ;;
    zorin) printf 'Zorin OS' ;;
    elementary) printf 'elementary OS' ;;
    bazzite) printf 'Bazzite' ;;
    steamos) printf 'SteamOS' ;;
    *)
      if printf '%s' "$_id_like" | grep -qiE '(^| )(ubuntu)( |$)'; then
        printf 'Ubuntu-family Linux'
      elif printf '%s' "$_id_like" | grep -qiE '(^| )(debian)( |$)'; then
        printf 'Debian-family Linux'
      else
        printf 'Unrecognized Linux'
      fi
      ;;
  esac
}

is_supported_apt_os() {
  local _id="${1:-$(os_release_field ID)}"
  local _id_like="${2:-$(os_release_field ID_LIKE)}"
  case "$_id" in
    raspbian|debian|ubuntu|pop|linuxmint|zorin|elementary)
      return 0
      ;;
  esac
  printf '%s' "$_id_like" | grep -qiE '(^| )(ubuntu|debian)( |$)'
}

gpu_vram_mb() {
  if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null |
      awk 'NR==1 {gsub(/[^0-9]/, "", $1); found=1; print int($1)} END {if (!found) print 0}'
  else
    echo 0
  fi
}

gpu_summary() {
  local _line _name _mem _gpu
  if command -v nvidia-smi >/dev/null 2>&1; then
    _line="$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits 2>/dev/null | head -1 || true)"
    if [ -n "$_line" ]; then
      _name="${_line%%,*}"
      _mem="${_line#*,}"
      _name="$(printf '%s' "$_name" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
      _mem="$(printf '%s' "$_mem" | tr -dc '0-9')"
      case "$_name" in
        *NVIDIA*|*nvidia*) printf '%s' "$_name" ;;
        *) printf 'NVIDIA %s' "$_name" ;;
      esac
      [ -n "$_mem" ] && printf ' (%sMB VRAM)' "$_mem"
      return 0
    fi
  fi

  if command -v lspci >/dev/null 2>&1; then
    _gpu="$(lspci 2>/dev/null | awk -F': ' '/VGA compatible controller|3D controller|Display controller/ {print $2; exit}')"
    if [ -n "$_gpu" ]; then
      printf '%s' "$_gpu"
      return 0
    fi
  fi

  local _vendor
  for _vendor in /sys/class/drm/card*/device/vendor; do
    [ -r "$_vendor" ] || continue
    case "$(cat "$_vendor" 2>/dev/null)" in
      0x10de) printf 'NVIDIA GPU'; return 0 ;;
      0x1002|0x1022) printf 'AMD GPU'; return 0 ;;
      0x8086) printf 'Intel GPU'; return 0 ;;
    esac
  done
}

is_steam_deck() {
  local _facts
  _facts="$(
    cat /sys/class/dmi/id/product_name /sys/class/dmi/id/board_name /sys/class/dmi/id/sys_vendor 2>/dev/null || true
    if [ -r /etc/os-release ]; then cat /etc/os-release 2>/dev/null || true; fi
  )"
  printf '%s' "$_facts" | grep -qiE 'steam deck|jupiter|valve|steamos'
}

caroline_hardware_profile() {
  local _arch
  _arch="$(uname -m 2>/dev/null || echo unknown)"
  if is_wsl; then
    printf 'WSL on Windows'
  elif is_steam_deck; then
    printf 'Steam Deck / SteamOS-compatible PC'
  elif is_raspberry_pi; then
    printf 'Raspberry Pi'
  elif gpu_summary | grep -qiE 'nvidia|geforce|rtx|gtx|quadro'; then
    printf 'Linux x86_64 with NVIDIA GPU'
  elif printf '%s' "$_arch" | grep -qiE '^(x86_64|amd64)$'; then
    printf '%s x86_64' "$(os_label)"
  elif printf '%s' "$_arch" | grep -qiE '^(aarch64|arm64|armv)'; then
    printf 'Linux ARM'
  else
    printf 'Linux %s' "$_arch"
  fi
}

caroline_device_type() {
  if is_wsl; then
    printf 'Windows'
  elif is_steam_deck; then
    printf 'Steam'
  elif is_raspberry_pi; then
    printf 'Pi'
  elif [ -r /etc/os-release ] && grep -qiE '^ID=(ubuntu|pop|debian|linuxmint|zorin|elementary)' /etc/os-release; then
    printf 'Ubuntu'
  else
    printf 'Ubuntu'
  fi
}

recommended_ollama_model() {
  local _ram_mb="${1:-$(total_ram_mb)}"
  local _gpu_vram_mb="${2:-$(gpu_vram_mb)}"
  local _gpu_summary="${3:-$(gpu_summary)}"
  local _arch
  _arch="$(uname -m 2>/dev/null || echo unknown)"

  if [ "$_ram_mb" -gt 0 ] && [ "$_ram_mb" -lt 4096 ]; then
    printf 'qwen2.5:0.5b'
  elif is_wsl; then
    printf 'qwen2.5:1.5b'
  elif is_steam_deck; then
    printf 'qwen3:1.7b'
  elif is_raspberry_pi; then
    if [ "$_ram_mb" -ge 6000 ]; then
      printf 'qwen2.5:1.5b'
    else
      printf 'qwen2.5:0.5b'
    fi
  elif printf '%s' "$_gpu_summary" | grep -qiE 'nvidia|geforce|rtx|gtx|quadro' && [ "$_gpu_vram_mb" -ge 11000 ]; then
    printf 'gemma4:e4b'
  elif printf '%s' "$_gpu_summary" | grep -qiE 'nvidia|geforce|rtx|gtx|quadro' && [ "$_gpu_vram_mb" -ge 7000 ]; then
    printf 'mistral:7b'
  elif printf '%s' "$_gpu_summary" | grep -qiE 'nvidia|geforce|rtx|gtx|quadro' && [ "$_gpu_vram_mb" -ge 3500 ]; then
    printf 'qwen3:1.7b'
  elif printf '%s' "$_arch" | grep -qiE '^(x86_64|amd64)$'; then
    printf 'qwen2.5:1.5b'
  else
    printf 'qwen2.5:1.5b'
  fi
}

recommended_ollama_reason() {
  local _model="$1"
  local _ram_mb="${2:-0}"
  local _gpu_vram_mb="${3:-$(gpu_vram_mb)}"
  local _gpu_summary="${4:-$(gpu_summary)}"
  if is_wsl; then
    printf 'WSL detected; use OpenRouter or Windows Ollama, but this is the best remote/local target.'
  elif is_steam_deck; then
    printf 'Steam Deck-class hardware detected; qwen3:1.7b is the best tested local balance.'
  elif [ "$_ram_mb" -gt 0 ] && [ "$_ram_mb" -lt 4096 ]; then
    printf 'Under 4GB RAM detected, so the fastest small local model is safer.'
  elif is_raspberry_pi && [ "$_model" = "qwen2.5:0.5b" ]; then
    printf 'Raspberry Pi with limited RAM detected, so responsiveness wins over quality.'
  elif is_raspberry_pi; then
    printf 'Raspberry Pi with enough RAM detected; this was the best local Caroline balance in testing.'
  elif printf '%s' "$_gpu_summary" | grep -qiE 'nvidia|geforce|rtx|gtx|quadro' && [ "$_gpu_vram_mb" -ge 11000 ]; then
    printf 'NVIDIA GPU with 12GB-class VRAM detected; gemma4:e4b is the tested quality pick.'
  elif printf '%s' "$_gpu_summary" | grep -qiE 'nvidia|geforce|rtx|gtx|quadro' && [ "$_gpu_vram_mb" -ge 7000 ]; then
    printf 'NVIDIA GPU with 8GB-class VRAM detected; mistral:7b is the best tested balance.'
  elif printf '%s' "$_gpu_summary" | grep -qiE 'nvidia|geforce|rtx|gtx|quadro' && [ "$_gpu_vram_mb" -ge 3500 ]; then
    printf 'NVIDIA GPU detected, but VRAM is below 8GB; qwen3:1.7b keeps local chat responsive.'
  elif [ -n "$_gpu_summary" ]; then
    printf 'GPU detected but VRAM is unknown; using the conservative Linux local model.'
  else
    printf 'CPU-only or unknown-GPU Linux hardware detected; this is the conservative local model.'
  fi
}

is_raspberry_pi() {
  local _model
  _model="$(caroline_device_model)"
  if printf '%s' "$_model" | grep -qi 'Raspberry Pi'; then
    return 0
  fi
  if [ -r /etc/os-release ] && grep -qi '^ID=raspbian' /etc/os-release; then
    return 0
  fi
  return 1
}

is_wsl() {
  grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null && return 0
  grep -qiE 'microsoft|wsl' /proc/sys/kernel/osrelease 2>/dev/null && return 0
  return 1
}

wsl_windows_host_ip() {
  ip route 2>/dev/null | awk '/^default/ {print $3; exit}'
}

telemetry_emit() {
  local _event="$1"
  local _allow_remote="$2"
  local _troubleshooting="$3"
  local _install_id="$4"
  local _payload_path
  local _os_name
  local _arch
  local _device_model
  local _gpu_summary
  local _gpu_vram_mb
  local _node_version
  local _npm_version
  local _node_red_version
  local _ollama_version
  local _browser_version
  local _opt_out_event

  mkdir -p "$CAROLINE_DIR"
  _payload_path=$(mktemp)
  case "$_event" in
    *_opt_out) _opt_out_event="true" ;;
    *) _opt_out_event="false" ;;
  esac
  _os_name=$(. /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-$ID $VERSION_ID}" || echo "unknown")
  _arch=$(uname -m 2>/dev/null || echo "unknown")
  _device_model="$(caroline_device_model)"
  _gpu_summary="$(gpu_summary)"
  _gpu_vram_mb="$(gpu_vram_mb)"
  _node_version="$(safe_cmd_version node --version)"
  _npm_version="$(safe_cmd_version npm --version)"
  _node_red_version="$(safe_cmd_version node-red --version)"
  _ollama_version="$(safe_cmd_version ollama --version)"
  if [ -n "${BROWSER_BIN:-}" ] && [ -x "$BROWSER_BIN" ]; then
    _browser_version="$("$BROWSER_BIN" --version 2>/dev/null | head -1 | tr -d '\r' || true)"
  else
    _browser_version=""
  fi

  jq -n \
    --arg schema "1" \
    --arg event "$_event" \
    --arg installId "$_install_id" \
    --arg version "$CAROLINE_VERSION" \
    --arg commit "${BUILD_COMMIT:-unknown}" \
    --arg branch "${BUILD_BRANCH:-unknown}" \
    --arg installedAt "${BUILD_INSTALLED_AT:-}" \
    --arg os "$_os_name" \
    --arg arch "$_arch" \
    --arg deviceModel "$_device_model" \
    --arg gpu "$_gpu_summary" \
    --argjson gpuVramMb "${_gpu_vram_mb:-0}" \
    --arg aiProvider "${AI_PROVIDER:-}" \
    --arg ollamaModel "${OLLAMA_MODEL:-}" \
    --arg nodeVersion "$_node_version" \
    --arg npmVersion "$_npm_version" \
    --arg nodeRedVersion "$_node_red_version" \
    --arg ollamaVersion "$_ollama_version" \
    --arg browserVersion "$_browser_version" \
    --argjson optOutEvent "$_opt_out_event" \
    --argjson kiosk "$(bool_json "$([ "${KIOSK_MODE:-N}" = "y" ] || [ "${KIOSK_MODE:-N}" = "Y" ] && echo true || echo false)")" \
    --argjson troubleshooting "$(bool_json "$_troubleshooting")" \
    '{
      schema: $schema,
      event: $event,
      installId: $installId,
      version: $version,
      commit: $commit,
      branch: $branch,
      installedAt: $installedAt,
      troubleshootingOptIn: $troubleshooting
    }
    + if $optOutEvent then {} else {
      platform: {
        os: $os,
        arch: $arch,
        deviceModel: $deviceModel,
        gpu: $gpu,
        gpuVramMb: $gpuVramMb
      },
      kioskMode: $kiosk,
      aiProvider: $aiProvider,
      ollamaModel: $ollamaModel
    } end
    + if ($troubleshooting and ($optOutEvent | not)) then {
      diagnostics: {
        node: $nodeVersion,
        npm: $npmVersion,
        nodeRed: $nodeRedVersion,
        ollama: $ollamaVersion,
        browser: $browserVersion
      }
    } else {} end' > "$_payload_path"

  cat "$_payload_path" >> "$TELEMETRY_LOG_PATH" 2>/dev/null || true
  printf '\n' >> "$TELEMETRY_LOG_PATH" 2>/dev/null || true
  sudo chown "$REAL_USER":"$REAL_USER" "$TELEMETRY_LOG_PATH" 2>/dev/null || true
  chmod 600 "$TELEMETRY_LOG_PATH" 2>/dev/null || true

  if [ "$_allow_remote" = "true" ] && [ -n "$CAROLINE_TELEMETRY_ENDPOINT" ]; then
    curl -fsS --max-time 5 \
      -H "Content-Type: application/json" \
      -X POST \
      --data-binary @"$_payload_path" \
      "$CAROLINE_TELEMETRY_ENDPOINT" >/dev/null 2>&1 || true
  fi

  rm -f "$_payload_path"
}

detect_browser() {
  local _cmd
  for _cmd in google-chrome-stable google-chrome chrome chromium-browser chromium; do
    if command -v "$_cmd" >/dev/null 2>&1; then
      BROWSER_BIN=$(command -v "$_cmd")
      BROWSER_FAMILY="chromium"
      return 0
    fi
  done
  for _cmd in firefox-esr firefox; do
    if command -v "$_cmd" >/dev/null 2>&1; then
      BROWSER_BIN=$(command -v "$_cmd")
      BROWSER_FAMILY="firefox"
      return 0
    fi
  done
  return 1
}

ensure_browser() {
  if detect_browser; then
    return 0
  fi

  sudo apt-get install -y -q chromium-browser >/tmp/caroline-browser-apt.log 2>&1 || \
  sudo apt-get install -y -q chromium >/tmp/caroline-browser-apt.log 2>&1 || \
  sudo apt-get install -y -q firefox-esr >/tmp/caroline-browser-apt.log 2>&1 || \
  sudo apt-get install -y -q firefox >/tmp/caroline-browser-apt.log 2>&1 || {
    echo -e "${YELLOW}  ⚠ Browser install failed. Check: cat /tmp/caroline-browser-apt.log${RESET}"
    BROWSER_BIN=""
    BROWSER_FAMILY=""
    return 1
  }

  if ! detect_browser; then
    echo -e "${YELLOW}  ⚠ Browser package installed but no supported browser command was found.${RESET}"
    BROWSER_BIN=""
    BROWSER_FAMILY=""
    return 1
  fi
  return 0
}

clear 2>/dev/null || true

echo ""
echo -e "${CYAN}  ____            _           _        ____                 _ _            ${RESET}"
echo -e "${CYAN} |  _ \\ _ __ ___ (_) ___  ___| |_     / ___|__ _ _ __ ___ | (_)_ __   ___ ${RESET}"
echo -e "${MAGENTA} | |_) | '__/ _ \\| |/ _ \\/ __| __|   | |   / _\` | '__/ _ \\| | | '_ \\ / _ \\${RESET}"
echo -e "${MAGENTA} |  __/| | | (_) | |  __/ (__| |_    | |__| (_| | | | (_) | | | | | |  __/${RESET}"
echo -e "${CYAN} |_|   |_|  \\___// |\\___|\\___|\\__|    \\____\\__,_|_|  \\___/|_|_|_| |_|\\___|${RESET}"
echo -e "${CYAN}              |__/                                                        ${RESET}"
echo ""
echo -e "${BOLD}${CYAN}  Project: Caroline${RESET}  ${DIM}v${CAROLINE_VERSION}${RESET}"
echo -e "${DIM}  Recovered research terminal. Assistant interface and home automation host.${RESET}"
echo ""
archive_panel
echo ""
echo -e "${CYAN}  ════════════════════════════════════════════════════════════${RESET}"
echo ""

sleep 1

# ── OS VERSION CHECK ─────────────────────────────────────────
OS_ID="$(os_release_field ID)"
OS_ID="${OS_ID:-unknown}"
OS_LIKE="$(os_release_field ID_LIKE)"
OS_PRETTY="$(os_release_field PRETTY_NAME)"
OS_PRETTY="${OS_PRETTY:-$OS_ID}"
OS_VER="$(os_release_field VERSION_CODENAME)"
OS_VER="${OS_VER:-$(os_release_field VERSION_ID)}"
OS_VER="${OS_VER:-unknown}"
OS_SUPPORT_LABEL="$(os_label "$OS_ID" "$OS_LIKE")"

echo -e "${CYAN}  Detected OS:${RESET} ${BOLD}${OS_PRETTY}${RESET} ${DIM}(${OS_SUPPORT_LABEL})${RESET}"
if [[ "$OS_ID" == "steamos" || "$OS_ID" == "bazzite" ]]; then
  echo -e "${YELLOW}  ⚠ ${OS_SUPPORT_LABEL} uses the home-directory installer.${RESET}"
  echo -e "${DIM}    Run: ./install-steamos.sh${RESET}"
  echo -e "${DIM}    Or from GitHub: curl -fsSL ${CAROLINE_RAW_BASE}/${CAROLINE_CHANNEL}/install-steamos.sh | bash${RESET}"
  exit 1
elif ! is_supported_apt_os "$OS_ID" "$OS_LIKE"; then
  echo -e "${YELLOW}  ⚠ Unrecognized OS: ${OS_ID} ${OS_VER}${RESET}"
  echo -e "${DIM}  Acknowledged beta paths: Raspberry Pi OS, Ubuntu Server/Desktop, Debian, Pop!_OS, Linux Mint, Zorin OS, elementary OS.${RESET}"
  echo -e "${DIM}  Continuing anyway — package names or service setup may break.${RESET}"
  echo ""
else
  echo -e "${DIM}  Acknowledged beta path. Raspberry Pi OS and Ubuntu remain the most tested public installs.${RESET}"
  echo ""
fi

# ── INTRO ────────────────────────────────────────────────────
echo -e "${BOLD}  Archived Project: Caroline terminal found.${RESET}"
echo -e "${DIM}  Reactivation requires a few system choices before the assistant comes online.${RESET}"
echo -e "${DIM}  Location, widgets, API keys, integrations, and personality are configured in the Caroline GUI after install.${RESET}"
echo -e "${DIM}  Press Enter to skip any field.${RESET}"
echo ""
echo -e "${CYAN}  ════════════════════════════════════════════════════════════${RESET}"
echo ""

# ── USER INPUT ───────────────────────────────────────────────
echo -e "${MAGENTA}  // CAROLINE ARCHIVE — OPERATOR RECORD${RESET}"
echo ""
if can_prompt; then
  read -p "  Your name: " USER_NAME </dev/tty
else
  USER_NAME="${CAROLINE_USER_NAME:-}"
  echo -e "${DIM}  Your name: ${USER_NAME:-preserved from existing settings}${RESET}"
fi
TIMEZONE="$(timedatectl show -p Timezone --value 2>/dev/null || true)"
[ -n "$TIMEZONE" ] || TIMEZONE="America/Los_Angeles"
LOCATION=""
ZIP_CODE=""
echo -e "${DIM}  Location, timezone, and weather ZIP happen in Caroline's first-boot setup.${RESET}"
echo ""

echo -e "${MAGENTA}  // CAROLINE ARCHIVE — ASSISTANT CORE${RESET}"
echo ""
echo -e "${DIM}  Best experience: OpenRouter. Fast, coherent, and usually costs pennies per month.${RESET}"
echo -e "${DIM}  Local AI is selected from OS, CPU architecture, RAM, and GPU/VRAM when detectable.${RESET}"
TOTAL_RAM_MB="$(total_ram_mb)"
SYSTEM_ARCH="$(uname -m 2>/dev/null || echo unknown)"
DEVICE_MODEL="$(caroline_device_model)"
CPU_MODEL="$(cpu_model_summary)"
GPU_SUMMARY="$(gpu_summary)"
GPU_VRAM_MB="$(gpu_vram_mb)"
HARDWARE_PROFILE="$(caroline_hardware_profile)"
RECOMMENDED_OLLAMA_MODEL="$(recommended_ollama_model "$TOTAL_RAM_MB" "$GPU_VRAM_MB" "$GPU_SUMMARY")"
RECOMMENDED_OLLAMA_REASON="$(recommended_ollama_reason "$RECOMMENDED_OLLAMA_MODEL" "$TOTAL_RAM_MB" "$GPU_VRAM_MB" "$GPU_SUMMARY")"
if is_wsl; then
  WSL_WINDOWS_HOST_IP="$(wsl_windows_host_ip)"
  if [ -n "$WSL_WINDOWS_HOST_IP" ]; then
    OLLAMA_URL_DEFAULT="http://${WSL_WINDOWS_HOST_IP}:11434"
  fi
  echo ""
  echo -e "${YELLOW}  ⚠ WSL detected. Installing Linux Ollama inside WSL is not recommended for this beta.${RESET}"
  echo -e "${DIM}    Use OpenRouter, or install Ollama for Windows and set Caroline's Ollama URL to:${RESET}"
  echo -e "${DIM}    ${OLLAMA_URL_DEFAULT}${RESET}"
fi
echo ""
echo -e "${CYAN}  Detected hardware:${RESET} ${BOLD}${HARDWARE_PROFILE}${RESET} ${DIM}(${SYSTEM_ARCH}, ${TOTAL_RAM_MB:-0}MB RAM)${RESET}"
if [ -n "$DEVICE_MODEL" ]; then
  echo -e "${DIM}    ${DEVICE_MODEL}${RESET}"
fi
if [ -n "$CPU_MODEL" ]; then
  echo -e "${DIM}    CPU: ${CPU_MODEL}${RESET}"
fi
if [ -n "$GPU_SUMMARY" ]; then
  echo -e "${DIM}    GPU: ${GPU_SUMMARY}${RESET}"
else
  echo -e "${DIM}    GPU: not detected; using CPU-only/local fallback guidance${RESET}"
fi
echo -e "${CYAN}  Suggested local model:${RESET} ${BOLD}${RECOMMENDED_OLLAMA_MODEL}${RESET}"
echo -e "${DIM}    ${RECOMMENDED_OLLAMA_REASON}${RESET}"
echo ""
echo -e "${DIM}  Local model options you can type if you install Ollama:${RESET}"
echo -e "${DIM}    qwen3:1.7b    Steam Deck / light GPU quality; best small-host balance.${RESET}"
echo -e "${DIM}    mistral:7b    NVIDIA 8GB quality; best RTX 2070-class balance.${RESET}"
echo -e "${DIM}    gemma4:e4b    strong GPU quality mode; best on 12GB+ VRAM.${RESET}"
echo -e "${DIM}    qwen2.5:1.5b  conservative CPU/Pi/VM quality; low-risk Linux balance.${RESET}"
echo -e "${DIM}    qwen2.5:0.5b  fast local fallback; quickest on small hardware.${RESET}"
echo -e "${DIM}    gemma3:1b      safe/legacy default; stable older-install choice.${RESET}"
echo ""

# Warn if RAM is low
if [ "$TOTAL_RAM_MB" -gt 0 ] && [ "$TOTAL_RAM_MB" -lt 4096 ]; then
  echo -e "${YELLOW}  ⚠ ${TOTAL_RAM_MB}MB RAM detected. Ollama runs better with 4GB+.${RESET}"
  echo -e "${DIM}    Use OpenRouter for normal chat; local Ollama may feel slow or wander.${RESET}"
  echo -e "${DIM}    If Ollama cannot install here, Caroline will continue with OpenRouter.${RESET}"
  echo ""
fi

if is_wsl; then
  INSTALL_OLLAMA="N"
  echo -e "${DIM}  Install experimental local Ollama fallback on this device? (y/N): N  (WSL: use Windows Ollama or OpenRouter)${RESET}"
elif [ "$CAROLINE_NONINTERACTIVE" = "true" ]; then
  INSTALL_OLLAMA="N"
  echo -e "${DIM}  Install experimental local Ollama fallback on this device? (y/N): N  (noninteractive update)${RESET}"
else
  read -p "  Install experimental local Ollama fallback on this device? (y/N): " INSTALL_OLLAMA </dev/tty
  INSTALL_OLLAMA="${INSTALL_OLLAMA:-N}"
fi
echo ""

if [ "$INSTALL_OLLAMA" = "y" ] || [ "$INSTALL_OLLAMA" = "Y" ]; then
  AI_PROVIDER="ollama"
  echo -e "${DIM}  Choose a local model. ${RECOMMENDED_OLLAMA_MODEL} is selected for this hardware.${RESET}"
  echo -e "${DIM}  OpenRouter is still the best Caroline experience.${RESET}"
  OLLAMA_MODEL="$(choose_ollama_model "$RECOMMENDED_OLLAMA_MODEL")"
  echo ""
  echo -e "${DIM}  Selected ${OLLAMA_MODEL}. The installer will download it after the core services are ready.${RESET}"
else
  AI_PROVIDER="openrouter"
  OLLAMA_MODEL="$RECOMMENDED_OLLAMA_MODEL"
  echo -e "${DIM}  Skipping local Ollama. You can add an OpenRouter key or point Ollama at another computer later in Settings.${RESET}"
fi
echo ""

echo -e "${MAGENTA}  // CAROLINE ARCHIVE — DISPLAY CONSOLE${RESET}"
echo ""
echo -e "${DIM}  Kiosk mode opens Caroline fullscreen on boot — ideal for a dedicated display.${RESET}"
if is_wsl; then
  echo -e "${DIM}  WSL detected. Use server/client mode and open Caroline from Windows at http://localhost:${KIOSK_PORT}/.${RESET}"
  echo -e "${DIM}  Kiosk autostart is skipped in WSL because the display belongs to Windows.${RESET}"
elif has_desktop_environment; then
  echo -e "${DIM}  Skip this if you're testing server/client mode or plan to open Caroline from another browser.${RESET}"
else
  echo -e "${DIM}  No desktop environment detected. Choose No for Ubuntu Server / headless mode.${RESET}"
  echo -e "${DIM}  Caroline will still run as a server and print the client browser URL after install.${RESET}"
fi
echo ""
if is_wsl; then
  KIOSK_MODE="N"
  echo -e "${DIM}  Enable kiosk mode on boot? (y/N): N  (WSL server/client mode)${RESET}"
elif [ "$CAROLINE_NONINTERACTIVE" = "true" ]; then
  KIOSK_MODE="N"
  echo -e "${DIM}  Enable kiosk mode on boot? (y/N): N  (preserved from existing settings during update)${RESET}"
else
  read -p "  Enable kiosk mode on boot? (y/N): " KIOSK_MODE </dev/tty
fi
echo ""

echo -e "${CYAN}  ════════════════════════════════════════════════════════════${RESET}"
echo ""
echo -e "${BOLD}  Acknowledged. Restoring Project: Caroline files to ~/caroline/...${RESET}"
echo ""
sleep 1

# ── DEPENDENCIES ─────────────────────────────────────────────
phase "REACTIVATION 1/6 — SYSTEM DEPENDENCIES"

reset_install_logs
ensure_install_swap 1800 1536 1024

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
sudo apt-get install -y -q fontconfig fonts-noto-color-emoji >/tmp/caroline-fonts-apt.log 2>&1 || {
  echo -e "${YELLOW}  ⚠ Emoji font package unavailable; continuing with core install.${RESET}"
  echo -e "${DIM}    Some decorative emoji may render as boxes on kiosk displays.${RESET}"
  echo -e "${DIM}    Log: cat /tmp/caroline-fonts-apt.log${RESET}"
}
echo -e "${GREEN}  ✓ System dependencies online${RESET}"

# ── PRIVACY / TELEMETRY CHOICE ──────────────────────────────
TELEMETRY_INSTALL_COUNT="false"
TELEMETRY_TROUBLESHOOTING="false"
TELEMETRY_OPT_OUT_PING="false"
TELEMETRY_PREF_SOURCE="prompt"

if [ -s "$SETTINGS_PATH" ] && jq empty "$SETTINGS_PATH" >/dev/null 2>&1; then
  EXISTING_TELEMETRY_INSTALL=$(jq -r 'if (.telemetryInstallCount | type) == "boolean" then .telemetryInstallCount else empty end' "$SETTINGS_PATH" 2>/dev/null || true)
  EXISTING_TELEMETRY_TROUBLESHOOTING=$(jq -r 'if (.telemetryTroubleshooting | type) == "boolean" then .telemetryTroubleshooting else empty end' "$SETTINGS_PATH" 2>/dev/null || true)
  EXISTING_TELEMETRY_OPT_OUT=$(jq -r 'if (.telemetryOptOutPing | type) == "boolean" then .telemetryOptOutPing else empty end' "$SETTINGS_PATH" 2>/dev/null || true)
  if [ -n "$EXISTING_TELEMETRY_INSTALL" ] && [ -n "$EXISTING_TELEMETRY_TROUBLESHOOTING" ]; then
    TELEMETRY_INSTALL_COUNT="$EXISTING_TELEMETRY_INSTALL"
    TELEMETRY_TROUBLESHOOTING="$EXISTING_TELEMETRY_TROUBLESHOOTING"
    TELEMETRY_OPT_OUT_PING="${EXISTING_TELEMETRY_OPT_OUT:-false}"
    TELEMETRY_PREF_SOURCE="existing"
  fi
fi

if [ "$TELEMETRY_PREF_SOURCE" = "existing" ]; then
  echo -e "${DIM}  Privacy choices preserved from existing settings.${RESET}"
else
  echo ""
  echo -e "${MAGENTA}  // PRIVACY BEACON${RESET}"
  echo ""
  echo -e "${DIM}  Caroline can optionally send Dave anonymous project-health pings.${RESET}"
  echo -e "${DIM}  Never sent: chat prompts, memory, settings text, IP address, location, calendar data, OAuth tokens, or API keys.${RESET}"
  echo -e "${DIM}  Your choice does not change any Caroline features or functionality.${RESET}"
  echo -e "${DIM}  Remote sending is disabled unless a release telemetry endpoint is configured.${RESET}"
  echo ""
  if ask_yes_no "Send an anonymous install/update count to the maintainer?" "n"; then
    TELEMETRY_INSTALL_COUNT="true"
  else
    TELEMETRY_INSTALL_COUNT="false"
    if ask_yes_no "Send one anonymous opt-out count instead?" "n"; then
      TELEMETRY_OPT_OUT_PING="true"
    fi
  fi
  if ask_yes_no "Opt in to safe troubleshooting diagnostics for future bug reports?" "n"; then
    TELEMETRY_TROUBLESHOOTING="true"
  fi
  echo ""
fi

LOCAL_AUTH_ENABLED="$(normalize_auth_choice "$CAROLINE_LOCAL_AUTH")"
if [ -z "$LOCAL_AUTH_ENABLED" ] && [ -s "$SETTINGS_PATH" ] && jq empty "$SETTINGS_PATH" >/dev/null 2>&1; then
  LOCAL_AUTH_ENABLED="$(jq -r 'if (.localAuthEnabled | type) == "boolean" then .localAuthEnabled else empty end' "$SETTINGS_PATH" 2>/dev/null || true)"
fi
if [ -z "$LOCAL_AUTH_ENABLED" ]; then
  if [ "$CAROLINE_NONINTERACTIVE" = "true" ]; then
    LOCAL_AUTH_ENABLED="true"
  else
    echo ""
    echo -e "${MAGENTA}  // LOCAL ACCESS${RESET}"
    echo ""
    echo -e "${DIM}  Optional browser login protects Caroline's local admin controls from other devices on your LAN.${RESET}"
    echo -e "${DIM}  Recommended for public beta installs. Choose No only for a private test box or dedicated home kiosk.${RESET}"
    echo ""
    if ask_yes_no "Require a local browser login for Caroline?" "y"; then
      LOCAL_AUTH_ENABLED="true"
    else
      LOCAL_AUTH_ENABLED="false"
    fi
    echo ""
  fi
fi
if [ "$LOCAL_AUTH_ENABLED" = "true" ]; then
  echo -e "${DIM}  Local browser login: enabled${RESET}"
else
  echo -e "${DIM}  Local browser login: disabled${RESET}"
fi
echo ""

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

node_candidate_bundles_npm() {
  local _candidate="${1:-}"
  [[ "$_candidate" == *nodesource* ]]
}

install_node_from_apt() {
  local _candidate _candidate_major _log
  _log="${1:-/tmp/caroline-node-apt.log}"
  _candidate=$(node_apt_candidate)
  _candidate_major=$(node_major_from_version "$_candidate")
  if [ "$_candidate_major" -lt 18 ]; then
    echo -e "${RED}  ✗ The apt repositories offer Node.js ${_candidate:-unknown}, but Node-RED 4.x needs Node.js 18+.${RESET}"
    echo -e "${DIM}    Use a real Pi running Raspberry Pi OS 64-bit, or a 64-bit Ubuntu/Debian/Linux VM or desktop.${RESET}"
    echo -e "${DIM}    32-bit i386 VM images often only provide old Node.js packages and are not a reliable QA target.${RESET}"
    exit 1
  fi
  echo -e "${DIM}    Installing Node.js from apt package repositories...${RESET}"
  sudo dpkg --configure -a >/tmp/caroline-dpkg-configure.log 2>&1 || true
  sudo apt-get -f install -y >/tmp/caroline-apt-fix.log 2>&1 || true
  if node_candidate_bundles_npm "$_candidate"; then
    echo -e "${DIM}    NodeSource candidate detected; npm is bundled with nodejs.${RESET}"
    sudo apt-get install -y nodejs >"$_log" 2>&1 || {
      echo -e "${RED}  ✗ Node.js apt install failed. Check: cat $_log${RESET}"
      echo -e "${DIM}    If the log mentions out-of-memory, give the VM 2GB+ RAM or add swap, then rerun the installer.${RESET}"
      exit 1
    }
  else
    sudo apt-get install -y nodejs npm >"$_log" 2>&1 || {
      echo -e "${RED}  ✗ Node.js/npm apt install failed. Check: cat $_log${RESET}"
      echo -e "${DIM}    If the log mentions out-of-memory, give the VM 2GB+ RAM or add swap, then rerun the installer.${RESET}"
      exit 1
    }
  fi
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
      sudo apt-get install -y nodejs >/tmp/caroline-node-nodesource-apt.log 2>&1 || {
        echo -e "${YELLOW}  ⚠ NodeSource package install failed — retrying with apt candidate detection.${RESET}"
        echo -e "${DIM}    First log: cat /tmp/caroline-node-nodesource-apt.log${RESET}"
        install_node_from_apt
      }
    else
      echo -e "${YELLOW}  ⚠ NodeSource setup failed — falling back to apt repositories.${RESET}"
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
if ! command -v npm &> /dev/null; then
  echo -e "${RED}  ✗ npm was not found after Node.js install.${RESET}"
  echo -e "${DIM}    Check: cat /tmp/caroline-node-apt.log${RESET}"
  echo -e "${DIM}    NodeSource packages include npm; Ubuntu/Debian OS packages may install npm separately.${RESET}"
  exit 1
fi
echo -e "${GREEN}  ✓ Node.js $(node --version) ready${RESET}"

# ── NODE-RED ─────────────────────────────────────────────────
phase "REACTIVATION 2/6 — NODE-RED RUNTIME"

install_node_red_global() {
  sudo env \
    npm_config_audit=false \
    npm_config_fund=false \
    npm_config_update_notifier=false \
    npm_config_jobs=1 \
    npm install -g --unsafe-perm --no-audit --no-fund node-red >/tmp/caroline-npm.log 2>&1
}

ensure_install_swap 4096 2048
echo -e "${YELLOW}  ► Installing Node-RED (this takes 1-3 minutes)...${RESET}"
install_node_red_global &
NODERED_PID=$!
spin "$NODERED_PID" "Installing Node-RED..."
wait "$NODERED_PID" || {
  echo -e "${YELLOW}  ⚠ Node-RED install failed once. Adding more temporary swap and retrying...${RESET}"
  echo -e "${DIM}    First log: cat /tmp/caroline-npm.log${RESET}"
  ensure_install_swap 6144 3072
  sudo npm cache clean --force >/tmp/caroline-npm-cache.log 2>&1 || true
  install_node_red_global &
  NODERED_PID=$!
  spin "$NODERED_PID" "Retrying Node-RED install..."
  wait "$NODERED_PID" || {
    echo -e "${RED}  ✗ Node-RED install failed. Check: cat /tmp/caroline-npm.log${RESET}"
    echo -e "${DIM}    If the log or console says out-of-memory, increase the VM to 4GB+ RAM or add swap, then rerun.${RESET}"
    exit 1
  }
}

# Resolve binary path — npm global installs to /usr/local/bin, not /usr/bin
NODE_RED_BIN=$(which node-red)

echo -e "${GREEN}  ✓ Node-RED ready${RESET}"

# ── NODE-RED SETTINGS ────────────────────────────────────────
echo -e "${YELLOW}  ► Writing Node-RED settings...${RESET}"

mkdir -p "$CAROLINE_DIR"

# Write a minimal settings.js that enables imported modules in Function nodes.
# Single-quoted heredoc delimiter prevents shell expansion of the JS content.
cat > "$CAROLINE_DIR/settings.js" << 'SETTINGS_EOF'
module.exports = {
    uiPort: process.env.PORT || 1880,
    // Node-RED is a local backend for Caroline. Nginx exposes only the routes
    // the UI needs, so the full editor/admin surface is not open on the LAN.
    uiHost: "127.0.0.1",
    flowFile: 'flows.json',
    httpRequestTimeout: 120000,
    httpNodeCors: { origin: "*", methods: "GET,PUT,POST,DELETE,OPTIONS" },
    functionExternalModules: true,
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
  phase "REACTIVATION 3/6 — LOCAL AI"

  ensure_install_swap 4096 2048
  OLLAMA_AVAILABLE=true
  echo -e "${YELLOW}  ► Installing Ollama...${RESET}"
  if ! command -v ollama &> /dev/null; then
    if curl -fsSL https://ollama.ai/install.sh -o /tmp/caroline-ollama-install.sh; then
      sh /tmp/caroline-ollama-install.sh >/tmp/caroline-ollama.log 2>&1 || {
        OLLAMA_AVAILABLE=false
      }
    else
      OLLAMA_AVAILABLE=false
    fi
  fi
  if ! command -v ollama &> /dev/null; then
    OLLAMA_AVAILABLE=false
  fi
  if [ "$OLLAMA_AVAILABLE" != "true" ]; then
    echo -e "${YELLOW}  ⚠ Ollama install failed or was killed by the OS. Continuing with OpenRouter as the AI runtime.${RESET}"
    echo -e "${DIM}    Log: cat /tmp/caroline-ollama.log${RESET}"
    echo -e "${DIM}    You can install Ollama later from Caroline Settings or with: curl -fsSL https://ollama.ai/install.sh | sh${RESET}"
    INSTALL_OLLAMA="n"
    AI_PROVIDER="openrouter"
  else
    echo -e "${GREEN}  ✓ Ollama installed${RESET}"

    echo -e "${YELLOW}  ► Configuring Ollama network access...${RESET}"
    sudo mkdir -p /etc/systemd/system/ollama.service.d/
    sudo tee /etc/systemd/system/ollama.service.d/env.conf > /dev/null << 'OLLAMA_ENV_EOF'
[Service]
Environment="OLLAMA_HOST=127.0.0.1:11434"
Environment="OLLAMA_ORIGINS=http://localhost:8080,http://127.0.0.1:8080"
OLLAMA_ENV_EOF

    echo -e "${YELLOW}  ► Starting Ollama service...${RESET}"
    sudo systemctl enable ollama 2>/dev/null || true
    sudo systemctl daemon-reload
    sudo systemctl restart ollama 2>/dev/null || sudo systemctl start ollama 2>/dev/null || true
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

    echo -e "${YELLOW}  ► Pulling ${OLLAMA_MODEL}...${RESET}"
    echo -e "${DIM}    Large local models can take a while on first pull.${RESET}"
    ollama pull "$OLLAMA_MODEL" >/tmp/caroline-pull.log 2>&1 &
    PULL_PID=$!
    spin "$PULL_PID" "Downloading ${OLLAMA_MODEL}..."
    if wait "$PULL_PID"; then
      echo -e "${GREEN}  ✓ Model ${OLLAMA_MODEL} locked and loaded${RESET}"
      echo -e "${YELLOW}  ► Starting ${OLLAMA_MODEL} warm-up in the background...${RESET}"
      (timeout 45s ollama run "$OLLAMA_MODEL" "hello" >/tmp/caroline-ollama-warmup.log 2>&1 || true) &
      echo -e "${DIM}    Continuing install. First local AI reply may still be slow.${RESET}"
    else
      echo -e "${YELLOW}  ⚠ Model pull failed — run 'ollama pull ${OLLAMA_MODEL}' manually after install${RESET}"
      echo -e "${DIM}    Log: cat /tmp/caroline-pull.log${RESET}"
    fi
    echo -e "${GREEN}  ✓ Ollama setup complete${RESET}"
  fi
fi
true

# ── DATA DIRECTORY ───────────────────────────────────────────
echo -e "${YELLOW}  ► Initializing data directory at ${CAROLINE_DIR}...${RESET}"

mkdir -p "$CAROLINE_DIR"
sudo chown "$REAL_USER":"$REAL_USER" "$CAROLINE_DIR"

echo -e "${GREEN}  ✓ Data directory ready${RESET}"
echo -e "${DIM}    Local data directory is ready.${RESET}"

# ── CAROLINE FILES ───────────────────────────────────────────
phase "REACTIVATION 4/6 — APPLICATION FILES"

mkdir -p "$CAROLINE_DIR"

echo -e "${YELLOW}  ► Cloning Caroline from GitHub...${RESET}"
echo -e "${DIM}    Fetching Project: Caroline ${CAROLINE_CHANNEL}.${RESET}"

CLONE_DIR="$REAL_HOME/project-caroline"

if [ -d "$CLONE_DIR/.git" ]; then
  echo -e "${DIM}    Repo already present — syncing ${CAROLINE_CHANNEL}...${RESET}"
  git config --global --add safe.directory "$CLONE_DIR" >/dev/null 2>&1 || true
  git -C "$CLONE_DIR" remote set-url origin "$CAROLINE_REPO_URL" >/tmp/caroline-git.log 2>&1 || true
  git -C "$CLONE_DIR" fetch --tags --force origin >>/tmp/caroline-git.log 2>&1 || {
    echo -e "${YELLOW}    ⚠ git fetch failed — using existing clone${RESET}"
  }
else
  git clone --no-checkout "$CAROLINE_REPO_URL" "$CLONE_DIR" >/tmp/caroline-git.log 2>&1 || {
    echo -e "${RED}  ✗ Git clone failed. Check your internet connection.${RESET}"
    echo -e "${DIM}    Log: cat /tmp/caroline-git.log${RESET}"
    exit 1
  }
fi

if git -C "$CLONE_DIR" show-ref --verify --quiet "refs/remotes/origin/${CAROLINE_CHANNEL}"; then
  git -C "$CLONE_DIR" checkout -B "$CAROLINE_CHANNEL" "origin/${CAROLINE_CHANNEL}" >>/tmp/caroline-git.log 2>&1 || {
    echo -e "${RED}  ✗ Could not check out ${CAROLINE_CHANNEL}.${RESET}"
    echo -e "${DIM}    Log: cat /tmp/caroline-git.log${RESET}"
    exit 1
  }
elif git -C "$CLONE_DIR" show-ref --verify --quiet "refs/tags/${CAROLINE_CHANNEL}"; then
  git -C "$CLONE_DIR" checkout --detach "refs/tags/${CAROLINE_CHANNEL}" >>/tmp/caroline-git.log 2>&1 || {
    echo -e "${RED}  ✗ Could not check out tag ${CAROLINE_CHANNEL}.${RESET}"
    echo -e "${DIM}    Log: cat /tmp/caroline-git.log${RESET}"
    exit 1
  }
else
  echo -e "${RED}  ✗ Project: Caroline channel not found: ${CAROLINE_CHANNEL}${RESET}"
  echo -e "${DIM}    Use release, nightly, or a published tag such as v0.3.0-beta.3.${RESET}"
  echo -e "${DIM}    Log: cat /tmp/caroline-git.log${RESET}"
  exit 1
fi
sudo chown -R "$REAL_USER":"$REAL_USER" "$CLONE_DIR" 2>/dev/null || true

echo -e "${DIM}    Copying application files to ${CAROLINE_DIR}...${RESET}"

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

BUILD_COMMIT="$(git -C "$CLONE_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)"
BUILD_BRANCH="$(git -C "$CLONE_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
BUILD_REPO="$(git -C "$CLONE_DIR" config --get remote.origin.url 2>/dev/null || echo "$CAROLINE_REPO_URL")"
BUILD_INSTALLED_AT="$(date -Iseconds)"
BUILD_GPU_SUMMARY="${GPU_SUMMARY:-$(gpu_summary)}"
BUILD_GPU_VRAM_MB="${GPU_VRAM_MB:-$(gpu_vram_mb)}"
case "$BUILD_GPU_VRAM_MB" in
  ''|*[!0-9]*) BUILD_GPU_VRAM_MB=0 ;;
esac
jq -n \
  --arg version "$CAROLINE_VERSION" \
  --arg commit "$BUILD_COMMIT" \
  --arg branch "$BUILD_BRANCH" \
  --arg channel "$CAROLINE_CHANNEL" \
  --arg repo "$BUILD_REPO" \
  --arg installedAt "$BUILD_INSTALLED_AT" \
  --arg hostname "$(hostname)" \
  --arg deviceType "$(caroline_device_type)" \
  --arg hardwareProfile "$(caroline_hardware_profile)" \
  --arg gpu "$BUILD_GPU_SUMMARY" \
  --argjson gpuVramMb "$BUILD_GPU_VRAM_MB" \
  '{ version: $version, commit: $commit, branch: $branch, channel: $channel, repo: $repo, installedAt: $installedAt, hostname: $hostname, deviceType: $deviceType, hardwareProfile: $hardwareProfile, gpu: $gpu, gpuVramMb: $gpuVramMb }' \
  > "$CAROLINE_DIR/caroline_build.json"
sudo chown "$REAL_USER":"$REAL_USER" "$CAROLINE_DIR/caroline_build.json"
printf '%s\n' "$CAROLINE_CHANNEL" > "$CAROLINE_DIR/caroline_channel"
sudo chown "$REAL_USER":"$REAL_USER" "$CAROLINE_DIR/caroline_channel" 2>/dev/null || true
chmod 600 "$CAROLINE_DIR/caroline_channel" 2>/dev/null || true

# Flatten avatar GIFs to root — skip any placeholder stub (43 bytes); only copy files > 1 KB
for _gif in "$CAROLINE_DIR/assets/"*.gif; do
  [ -f "$_gif" ] || continue
  [ "$(stat -c%s "$_gif" 2>/dev/null || echo 0)" -gt 1024 ] && cp -f "$_gif" "$CAROLINE_DIR/" || \
    echo -e "${YELLOW}    ⚠ Skipped placeholder GIF: $(basename "$_gif")${RESET}"
done
unset _gif
# Ensure nginx can traverse the app directory and read public assets.
# Secret files are tightened immediately afterward by protect_secret_files.
sudo find "$CAROLINE_DIR" -type d -exec chmod 755 {} + 2>/dev/null || true
sudo find "$CAROLINE_DIR" -type f \
  ! -name 'caroline_settings.json' \
  ! -name 'caroline_telemetry.jsonl' \
  ! -name 'caroline_feedback.jsonl' \
  ! -name 'google_oauth.json' \
  ! -name 'caroline_tasks.json' \
  ! -name 'caroline_mind.json' \
  ! -name 'caroline_admin_password.txt' \
  ! -name 'spotify_auth.json' \
  ! -name 'caroline-calendar.json' \
  ! -name 'service-account.json' \
  -exec chmod 644 {} + 2>/dev/null || true
sudo chown -R www-data:www-data "$CAROLINE_DIR/assets" 2>/dev/null || true
protect_secret_files

if [ ! -f "$CAROLINE_DIR/index.html" ] || [ ! -f "$CAROLINE_DIR/flows.json" ]; then
  echo ""
  echo -e "${RED}  ✗ Core files missing after copy. Check clone at: ${CLONE_DIR}${RESET}"
  exit 1
fi

echo -e "${GREEN}  ✓ Caroline payload ready${RESET}"
echo -e "${DIM}    Inventory sorted; no mystery key items left behind.${RESET}"

# ── GOOGLE OAUTH TOKEN STORE ─────────────────────────────────
if [ ! -s "$CAROLINE_DIR/google_oauth.json" ] || ! jq empty "$CAROLINE_DIR/google_oauth.json" >/dev/null 2>&1; then
  printf '{}\n' > "$CAROLINE_DIR/google_oauth.json"
fi
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
ESCAPED_CAROLINE_DIR="$(printf '%s' "$CAROLINE_DIR" | sed 's/[\/&]/\\&/g')"
sed -i "s/\/home\/davee\/caroline/${ESCAPED_CAROLINE_DIR}/g" "$CAROLINE_DIR/flows.json"

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
phase "REACTIVATION 5/6 — WEB INTERFACE"

echo -e "${YELLOW}  ► Deploying kiosk interface on port ${KIOSK_PORT}...${RESET}"

# Clear the port before nginx tries to bind it
sudo fuser -k ${KIOSK_PORT}/tcp 2>/dev/null || true
sudo fuser -k ${HTTPS_PROXY_PORT}/tcp 2>/dev/null || true
sudo fuser -k ${HTTPS_UI_PORT}/tcp 2>/dev/null || true

# nginx runs as www-data — needs execute permission on the home directory
# to traverse into ~/caroline, and read access on the files themselves.
sudo chmod o+x "$REAL_HOME"
sudo find "$CAROLINE_DIR" -type d -exec chmod o+rx {} + 2>/dev/null || true
sudo find "$CAROLINE_DIR" -type f \
  ! -name 'caroline_settings.json' \
  ! -name 'caroline_telemetry.jsonl' \
  ! -name 'caroline_feedback.jsonl' \
  ! -name 'google_oauth.json' \
  ! -name 'caroline_tasks.json' \
  ! -name 'caroline_mind.json' \
  ! -name 'caroline_admin_password.txt' \
  ! -name 'spotify_auth.json' \
  ! -name 'caroline-calendar.json' \
  ! -name 'service-account.json' \
  -exec chmod o+r {} + 2>/dev/null || true
protect_secret_files

NGINX_AUTH_DIRECTIVES=""
if [ "$LOCAL_AUTH_ENABLED" = "true" ]; then
  configure_admin_auth
  NGINX_AUTH_DIRECTIVES="    auth_basic \"Caroline\";
    auth_basic_user_file ${CAROLINE_HTPASSWD_PATH};"
fi

sudo mkdir -p "$CAROLINE_AUTH_DIR"
if [ ! -f "$CAROLINE_AUTH_DIR/caroline-selfsigned.crt" ] || [ ! -f "$CAROLINE_AUTH_DIR/caroline-selfsigned.key" ]; then
  sudo openssl req -x509 -nodes -newkey rsa:2048 -days 3650 \
    -keyout "$CAROLINE_AUTH_DIR/caroline-selfsigned.key" \
    -out "$CAROLINE_AUTH_DIR/caroline-selfsigned.crt" \
    -subj "/CN=project-caroline.local" >/tmp/caroline-openssl.log 2>&1 || {
      echo -e "${YELLOW}  ⚠ HTTPS certificate generation failed${RESET}"
    }
  sudo chmod 600 "$CAROLINE_AUTH_DIR/caroline-selfsigned.key" 2>/dev/null || true
fi
if [ ! -f "$CAROLINE_AUTH_DIR/caroline-selfsigned.crt" ] || [ ! -f "$CAROLINE_AUTH_DIR/caroline-selfsigned.key" ]; then
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
${NGINX_AUTH_DIRECTIVES}

    location /ws/ {
        if (\$http_sec_fetch_site = "cross-site") { return 403; }
        proxy_pass http://127.0.0.1:${NODE_RED_PORT};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Proto http;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    location /admin/ {
        if (\$http_sec_fetch_site = "cross-site") { return 403; }
        proxy_pass http://127.0.0.1:${NODE_RED_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Proto http;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    location /spotify/ {
        if (\$http_sec_fetch_site = "cross-site") { return 403; }
        proxy_pass http://127.0.0.1:${NODE_RED_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Proto http;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    location ~ ^/(chat|health|system-resources|wifi-signal|restart)$ {
        if (\$http_sec_fetch_site = "cross-site") { return 403; }
        proxy_pass http://127.0.0.1:${NODE_RED_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Proto http;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    location / {
        try_files \$uri \$uri/ /index.html;
    }
}

server {
    listen ${HTTPS_PROXY_PORT} ssl;
    server_name _;

    ssl_certificate ${CAROLINE_AUTH_DIR}/caroline-selfsigned.crt;
    ssl_certificate_key ${CAROLINE_AUTH_DIR}/caroline-selfsigned.key;

    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

    location /spotify/ {
        proxy_pass http://127.0.0.1:${NODE_RED_PORT};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    location = / {
        default_type text/plain;
        return 200 "Caroline OAuth proxy is ready.\n";
    }

    location / {
        return 404;
    }
}

server {
    listen ${HTTPS_UI_PORT} ssl;
    server_name _;
    root ${CAROLINE_DIR};
    index index.html;
    autoindex off;

    ssl_certificate ${CAROLINE_AUTH_DIR}/caroline-selfsigned.crt;
    ssl_certificate_key ${CAROLINE_AUTH_DIR}/caroline-selfsigned.key;

    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer" always;
    add_header Content-Security-Policy "default-src 'self' 'unsafe-inline' 'unsafe-eval' ws: wss: data: blob: https: http:;" always;
${NGINX_AUTH_DIRECTIVES}

    location /ws/ {
        if (\$http_sec_fetch_site = "cross-site") { return 403; }
        proxy_pass http://127.0.0.1:${NODE_RED_PORT};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    location /admin/ {
        if (\$http_sec_fetch_site = "cross-site") { return 403; }
        proxy_pass http://127.0.0.1:${NODE_RED_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    location /spotify/ {
        if (\$http_sec_fetch_site = "cross-site") { return 403; }
        proxy_pass http://127.0.0.1:${NODE_RED_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    location ~ ^/(chat|health|system-resources|wifi-signal|restart)$ {
        if (\$http_sec_fetch_site = "cross-site") { return 403; }
        proxy_pass http://127.0.0.1:${NODE_RED_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Real-IP \$remote_addr;
    }

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
ExecStartPre=/bin/sh -c 'fuser -k ${KIOSK_PORT}/tcp 2>/dev/null; fuser -k ${HTTPS_PROXY_PORT}/tcp 2>/dev/null; fuser -k ${HTTPS_UI_PORT}/tcp 2>/dev/null; true'
DROPIN_EOF
sudo systemctl daemon-reload

sudo systemctl enable nginx
sudo systemctl restart nginx

echo -e "${GREEN}  ✓ Web server ready on ${KIOSK_PORT}; HTTPS proxy ready on ${HTTPS_PROXY_PORT}; secure voice UI ready on ${HTTPS_UI_PORT}${RESET}"

# ── WRITE SETTINGS ───────────────────────────────────────────
echo -e "${YELLOW}  ► Writing settings...${RESET}"

# jq writes valid JSON regardless of special characters in user input.
# On upgrades, merge defaults under the existing settings file so credentials,
# paired devices, OAuth clients, and user preferences survive reruns.
PI_IP=$(hostname -I | awk '{print $1}')
[ -n "$PI_IP" ] || PI_IP="localhost"
BROWSER_HOST_IP="$PI_IP"
if is_wsl; then
  BROWSER_HOST_IP="localhost"
fi
HOST_DEVICE_TYPE="$(caroline_device_type)"
INSTALL_ID="$(date +%s)-$(hostname)-$RANDOM"
INSTALL_EVENT_TYPE="install"
if [ -s "$SETTINGS_PATH" ] && jq empty "$SETTINGS_PATH" >/dev/null 2>&1; then
  INSTALL_EVENT_TYPE="upgrade"
fi
DEFAULT_SETTINGS_PATH=$(mktemp)
MERGED_SETTINGS_PATH=$(mktemp)
jq -n \
  --arg name         "$USER_NAME" \
  --arg tz           "${TIMEZONE:-}" \
  --arg loc          "$LOCATION" \
  --arg zip          "$ZIP_CODE" \
  --arg model        "$AI_MODEL" \
  --arg provider     "$AI_PROVIDER" \
  --arg ollamaModel  "$OLLAMA_MODEL" \
  --arg ollamaUrl    "$OLLAMA_URL_DEFAULT" \
  --arg piIp         "$PI_IP" \
  --arg nrUrl        "http://${BROWSER_HOST_IP}:${KIOSK_PORT}" \
  --arg hostDeviceType "$HOST_DEVICE_TYPE" \
  --arg installId    "$INSTALL_ID" \
  --argjson localAuth "$(bool_json "$LOCAL_AUTH_ENABLED")" \
  --argjson telemetryInstallCount "$(bool_json "$TELEMETRY_INSTALL_COUNT")" \
  --argjson telemetryTroubleshooting "$(bool_json "$TELEMETRY_TROUBLESHOOTING")" \
  --argjson telemetryOptOutPing "$(bool_json "$TELEMETRY_OPT_OUT_PING")" \
  --argjson telemetryEndpointConfigured "$([ -n "$CAROLINE_TELEMETRY_ENDPOINT" ] && echo true || echo false)" \
  --argjson kiosk    "$([ "$KIOSK_MODE" = "y" ] || [ "$KIOSK_MODE" = "Y" ] && echo true || echo false)" \
  '{
    installId:       $installId,
    telemetryInstallCount: $telemetryInstallCount,
    telemetryTroubleshooting: $telemetryTroubleshooting,
    telemetryOptOutPing: $telemetryOptOutPing,
    telemetryEndpointConfigured: $telemetryEndpointConfigured,
    localAuthEnabled: $localAuth,
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
    piIp:            $piIp,
    nodeRedUrl:      $nrUrl,
    hostDeviceType:  $hostDeviceType,
    uiFont:          "Inter",
    uiScale:         "large",
    uiDensity:       "comfortable",
    highContrastText: true,
    reduceMonoLabels: true,
    defaultChannel:  0,
    meetingReminderMinutes: 0,
    ttsEnabled:      false,
    voiceMuted:      true,
    wakeWordEnabled: false,
    wakePhrases:     "hey caroline, hey ai",
    aiModel:         $model,
    aiProvider:      $provider,
    ollamaUrl:       $ollamaUrl,
    ollamaModel:     $ollamaModel,
    openrouterKey:   "",
    hueIp:           "",
    hueKey:          "",
    hueGroup:        "",
    hueGroupName:    "",
    calendarId:      "primary",
    sheetId:         "",
    spotifyClientId: "",
    googleClientId:  "",
    googleClientSecret: "",
    googleRedirectUri: "http://127.0.0.1:1880/admin/google/callback",
    googleConnected: false,
    discordToken:    "",
    kioskMode:       $kiosk,
    setupComplete:   false
  }' > "$DEFAULT_SETTINGS_PATH"

if [ -s "$SETTINGS_PATH" ] && jq empty "$SETTINGS_PATH" >/dev/null 2>&1; then
  SETTINGS_BACKUP="$SETTINGS_PATH.bak.$(date +%Y%m%d-%H%M%S)"
  cp -p "$SETTINGS_PATH" "$SETTINGS_BACKUP" 2>/dev/null || true
  CURRENT_KIOSK_MODE="$([ "$KIOSK_MODE" = "y" ] || [ "$KIOSK_MODE" = "Y" ] && echo true || echo false)"
  jq -s '
    .[0] as $defaults | .[1] as $existing |
    ($defaults * $existing)
    | if ($existing.setupComplete == null) then .setupComplete = true else . end
    | if ((($existing.installId // "") == "") and (($existing.onboardingModules // null) == null) and ($existing.setupComplete == true))
      then .setupComplete = false else . end
    | if (($defaults.aiProvider == "ollama")
          and ((($existing.ollamaModel // "") == "")
               or ($existing.ollamaModel == "gemma2:2b")
               or ($existing.ollamaModel == "llama3.2")
               or ($existing.ollamaModel == "llama3.2:1b")
               or ($existing.ollamaModel == "qwen3:0.6b")
               or ($existing.ollamaModel == "smollm2:360m")
               or ($existing.ollamaModel == "tinyllama")))
      then .ollamaModel = $defaults.ollamaModel else . end
    | if (($defaults.aiProvider == "ollama")
          and (((.openrouterKey // "") == "")
               and ((($existing.aiProvider // "") == "") or ($existing.aiProvider == "openrouter"))))
      then .aiProvider = "ollama" else . end
    | if (.zipCode and ((.zipcode // "") == "")) then .zipcode = .zipCode else . end
    | if (.zipcode and ((.zipCode // "") == "")) then .zipCode = .zipcode else . end
    | if (((.piIp // "") == "") or (.piIp == "localhost") or (.piIp == "127.0.0.1")) then .piIp = $defaults.piIp else . end
    | if (((.nodeRedUrl // "") == "") or ((.nodeRedUrl // "") | test("^https?://(localhost|127[.]0[.]0[.]1)(:|/|$)")) or ((.nodeRedUrl // "") | test(":1880/?$")) or ((.nodeRedUrl // "") | contains("[PI_IP]"))) then .nodeRedUrl = $defaults.nodeRedUrl else . end
    | ($existing.piIp // "") as $oldPiIp
    | ($existing.nodeRedUrl // "") as $oldNodeRedUrl
    | if (($oldPiIp != "")
          and ($oldPiIp != $defaults.piIp)
          and (($oldNodeRedUrl == "")
               or ($oldNodeRedUrl | contains("://" + $oldPiIp + ":"))
               or ($oldNodeRedUrl | contains("://" + $oldPiIp + "/"))))
      then .piIp = $defaults.piIp | .nodeRedUrl = $defaults.nodeRedUrl else . end
    | .telemetryEndpointConfigured = $defaults.telemetryEndpointConfigured
    | .localAuthEnabled = $defaults.localAuthEnabled
    | if $preserveKiosk then . else .kioskMode = $currentKiosk end
  ' \
    --argjson preserveKiosk "$([ "$CAROLINE_NONINTERACTIVE" = "true" ] && echo true || echo false)" \
    --argjson currentKiosk "$CURRENT_KIOSK_MODE" \
    "$DEFAULT_SETTINGS_PATH" "$SETTINGS_PATH" > "$MERGED_SETTINGS_PATH"
  mv "$MERGED_SETTINGS_PATH" "$SETTINGS_PATH"
  echo -e "${DIM}    Existing settings preserved; backup: ${SETTINGS_BACKUP}${RESET}"
else
  mv "$DEFAULT_SETTINGS_PATH" "$SETTINGS_PATH"
fi
rm -f "$DEFAULT_SETTINGS_PATH" "$MERGED_SETTINGS_PATH"
protect_secret_files

echo -e "${GREEN}  ✓ Settings saved${RESET}"

FINAL_INSTALL_ID=$(jq -r ".installId // \"$INSTALL_ID\"" "$SETTINGS_PATH" 2>/dev/null || echo "$INSTALL_ID")
if [ "$TELEMETRY_INSTALL_COUNT" = "true" ]; then
  telemetry_emit "$INSTALL_EVENT_TYPE" "true" "$TELEMETRY_TROUBLESHOOTING" "$FINAL_INSTALL_ID"
  if [ -n "$CAROLINE_TELEMETRY_ENDPOINT" ]; then
    echo -e "${GREEN}  ✓ Anonymous ${INSTALL_EVENT_TYPE} ping sent when network allows${RESET}"
  else
    echo -e "${DIM}    Anonymous ${INSTALL_EVENT_TYPE} ping logged locally; no remote endpoint configured.${RESET}"
  fi
else
  telemetry_emit "${INSTALL_EVENT_TYPE}_opt_out" "$TELEMETRY_OPT_OUT_PING" "false" "$FINAL_INSTALL_ID"
  if [ "$TELEMETRY_OPT_OUT_PING" = "true" ] && [ -n "$CAROLINE_TELEMETRY_ENDPOINT" ]; then
    echo -e "${GREEN}  ✓ Anonymous opt-out ping sent when network allows${RESET}"
  else
    echo -e "${DIM}    Telemetry opt-out recorded locally on this device.${RESET}"
  fi
fi

# ── SYSTEMD SERVICE ──────────────────────────────────────────
phase "REACTIVATION 6/6 — SYSTEM SERVICE"

echo -e "${YELLOW}  ► Configuring Caroline as a system service...${RESET}"

if [ "$INSTALL_OLLAMA" = "y" ] || [ "$INSTALL_OLLAMA" = "Y" ]; then
  CAROLINE_AFTER="network-online.target ollama.service"
  CAROLINE_REQUIRES="Requires=ollama.service"
  CAROLINE_ENV="Environment=\"OLLAMA_MODEL=${OLLAMA_MODEL}\""
  CAROLINE_POST='ExecStartPost=/bin/bash -c '\''sleep 30 && timeout 45s ollama run "$OLLAMA_MODEL" "ready" > /dev/null 2>&1 &'\'''
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

echo -e "${YELLOW}  ► Allowing Caroline to reboot this host...${RESET}"
sudo tee /etc/sudoers.d/caroline-reboot > /dev/null << EOF
${REAL_USER} ALL=(root) NOPASSWD: /usr/sbin/reboot, /sbin/reboot, /usr/bin/systemctl reboot, /bin/systemctl reboot
EOF
sudo chmod 440 /etc/sudoers.d/caroline-reboot
if sudo visudo -cf /etc/sudoers.d/caroline-reboot >/tmp/caroline-sudoers-check.log 2>&1; then
  echo -e "${GREEN}  ✓ Reboot control ready${RESET}"
else
  sudo rm -f /etc/sudoers.d/caroline-reboot
  echo -e "${YELLOW}  ⚠ Reboot control was not installed; sudoers validation failed${RESET}"
  echo -e "${DIM}    Log: cat /tmp/caroline-sudoers-check.log${RESET}"
fi

echo -e "${YELLOW}  ► Allowing Caroline to update this host...${RESET}"
sudo tee /usr/local/sbin/caroline-update > /dev/null << 'EOF'
#!/bin/bash
set -Eeuo pipefail
LOG="/tmp/caroline-update.log"
LOCK="/tmp/caroline-update.lock"
INSTALLER="/tmp/caroline-install.sh"
REPO_OWNER="Project-Caroline"
REPO_NAME="project-caroline"
REPO_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}.git"
trap 'code=$?; echo "$(date -Is) Project: Caroline GUI update failed (exit $code)" >> "$LOG"; exit $code' ERR

exec 9>"$LOCK"
if ! flock -n 9; then
  echo "$(date -Is) update already running" >> "$LOG"
  exit 0
fi

TARGET_USER="$(awk -F= '/^User=/{print $2; exit}' /etc/systemd/system/caroline.service 2>/dev/null || true)"
if [ -z "$TARGET_USER" ] || [ "$TARGET_USER" = "root" ]; then
  TARGET_USER="${SUDO_USER:-${USER:-}}"
fi
if [ -z "$TARGET_USER" ] || [ "$TARGET_USER" = "root" ]; then
  TARGET_USER="$(stat -c '%U' /home/*/caroline 2>/dev/null | head -1 || true)"
fi
if [ -z "$TARGET_USER" ] || [ "$TARGET_USER" = "root" ]; then
  echo "$(date -Is) could not determine Caroline user" | tee -a "$LOG"
  exit 1
fi
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
if [ -z "$TARGET_HOME" ] || [ ! -d "$TARGET_HOME" ]; then
  echo "$(date -Is) could not determine home for $TARGET_USER" | tee -a "$LOG"
  exit 1
fi
REPO_CHANNEL="${CAROLINE_UPDATE_CHANNEL:-}"
if [ -z "$REPO_CHANNEL" ] && [ -s "$TARGET_HOME/caroline/caroline_channel" ]; then
  REPO_CHANNEL="$(head -n 1 "$TARGET_HOME/caroline/caroline_channel" | tr -d '[:space:]' || true)"
fi
if [ -z "$REPO_CHANNEL" ] && [ -f "$TARGET_HOME/caroline/caroline_build.json" ] && command -v jq >/dev/null 2>&1; then
  REPO_CHANNEL="$(jq -r '.channel // .branch // ""' "$TARGET_HOME/caroline/caroline_build.json" 2>/dev/null || true)"
fi
REPO_CHANNEL="${REPO_CHANNEL:-release}"
case "$REPO_CHANNEL" in
  ''|*[!A-Za-z0-9._/-]*)
    echo "$(date -Is) invalid Caroline update channel: $REPO_CHANNEL" | tee -a "$LOG"
    exit 1
    ;;
esac
REPO_INSTALL_URL="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${REPO_CHANNEL}/install.sh"

{
  echo "============================================================"
  echo "$(date -Is) Project: Caroline GUI update requested"
  echo "Target user: $TARGET_USER"
  echo "Target home: $TARGET_HOME"
  echo "Channel: $REPO_CHANNEL"
} > "$LOG"

curl -fsSL "$REPO_INSTALL_URL" -o "$INSTALLER" >> "$LOG" 2>&1
chmod 700 "$INSTALLER"
git config --global --add safe.directory "$TARGET_HOME/project-caroline" >/dev/null 2>&1 || true
LOCAL_COMMIT=""
REMOTE_COMMIT=""
if [ -f "$TARGET_HOME/caroline/caroline_build.json" ] && command -v jq >/dev/null 2>&1; then
  LOCAL_COMMIT="$(jq -r '.commit // ""' "$TARGET_HOME/caroline/caroline_build.json" 2>/dev/null || true)"
fi
if [ -z "$LOCAL_COMMIT" ] && [ -d "$TARGET_HOME/project-caroline/.git" ]; then
  LOCAL_COMMIT="$(git -C "$TARGET_HOME/project-caroline" rev-parse --short HEAD 2>/dev/null || true)"
fi
REMOTE_COMMIT="$(git ls-remote "$REPO_URL" "refs/heads/${REPO_CHANNEL}" 2>/dev/null | awk '{print $1}' | head -1 || true)"
if [ -z "$REMOTE_COMMIT" ]; then
  REMOTE_COMMIT="$(git ls-remote "$REPO_URL" "refs/tags/${REPO_CHANNEL}" 2>/dev/null | awk '{print $1}' | head -1 || true)"
fi
if [ -z "$REMOTE_COMMIT" ]; then
  echo "$(date -Is) Project: Caroline GUI update check unavailable (could not reach GitHub)" >> "$LOG"
  exit 0
fi
if [ -n "$LOCAL_COMMIT" ] && [ -n "$REMOTE_COMMIT" ] && [ "${REMOTE_COMMIT#${LOCAL_COMMIT}}" != "$REMOTE_COMMIT" ]; then
  echo "$(date -Is) Project: Caroline GUI update already current (${LOCAL_COMMIT})" >> "$LOG"
  exit 0
fi
echo "$(date -Is) Update available: ${LOCAL_COMMIT:-unknown} -> ${REMOTE_COMMIT:0:7}" >> "$LOG"
NO_COLOR=1 TERM=dumb SUDO_USER="$TARGET_USER" USER="$TARGET_USER" HOME="$TARGET_HOME" CAROLINE_NONINTERACTIVE=true CAROLINE_PRESERVE_UPDATE_LOG=true CAROLINE_DEFER_SERVICE_RESTART=true CAROLINE_CHANNEL="$REPO_CHANNEL" bash "$INSTALLER" --noninteractive >> "$LOG" 2>&1
echo "$(date -Is) Project: Caroline GUI update complete" >> "$LOG"
RESTART_CMD="$(command -v systemctl || true)"
RESTART_UNIT="caroline-restart-$(date +%s)"
if command -v systemd-run >/dev/null 2>&1 && [ -n "$RESTART_CMD" ]; then
  if ! systemd-run --unit="$RESTART_UNIT" --collect --on-active=1s "$RESTART_CMD" restart caroline.service >/tmp/caroline-restart.log 2>&1; then
    nohup bash -lc 'sleep 1; systemctl restart caroline.service' >/tmp/caroline-restart.log 2>&1 &
  fi
else
  nohup bash -lc 'sleep 1; systemctl restart caroline.service' >/tmp/caroline-restart.log 2>&1 &
fi
EOF
sudo chmod 755 /usr/local/sbin/caroline-update
sudo chown root:root /usr/local/sbin/caroline-update
sudo tee /etc/sudoers.d/caroline-update > /dev/null << EOF
${REAL_USER} ALL=(root) NOPASSWD: /usr/local/sbin/caroline-update
EOF
sudo chmod 440 /etc/sudoers.d/caroline-update
if sudo visudo -cf /etc/sudoers.d/caroline-update >/tmp/caroline-update-sudoers-check.log 2>&1; then
  echo -e "${GREEN}  ✓ Update control ready${RESET}"
else
  sudo rm -f /etc/sudoers.d/caroline-update
  echo -e "${YELLOW}  ⚠ Update control was not installed; sudoers validation failed${RESET}"
  echo -e "${DIM}    Log: cat /tmp/caroline-update-sudoers-check.log${RESET}"
fi

sudo systemctl daemon-reload
sudo systemctl enable caroline

# Delete Node-RED runtime cache so it adopts flows.json cleanly on first boot
# (stale .config files cause flows to load into a "Recovered Nodes" tab instead)
rm -f "$CAROLINE_DIR/.config.runtime.json" 2>/dev/null || true
rm -f "$CAROLINE_DIR/.config.nodes.json"   2>/dev/null || true

# Use restart rather than start so rerunning the installer actually reloads
# updated flows/settings on an existing Caroline install.
if [ "${CAROLINE_DEFER_SERVICE_RESTART:-false}" = "true" ]; then
  echo -e "${DIM}  Caroline service restart deferred to update helper.${RESET}"
else
  sudo systemctl restart caroline
fi

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
FIREFOX_WINDOWED_PROFILE_DIR="$REAL_HOME/.mozilla/firefox/caroline-window"
WINDOWED_PROFILE_DIR="$FIREFOX_WINDOWED_PROFILE_DIR"
CHROMIUM_PROFILE_DIR="$REAL_HOME/.config/caroline/chromium-kiosk"
CHROMIUM_WINDOWED_PROFILE_DIR="$REAL_HOME/.config/caroline/chromium-window"

echo -e "${YELLOW}  ► Creating desktop launch shortcuts...${RESET}"
if is_wsl; then
  echo -e "${DIM}  WSL server/client mode detected — use your Windows browser instead.${RESET}"
  echo -e "${DIM}  Open: http://localhost:${KIOSK_PORT}/${RESET}"
elif has_desktop_environment; then
  if ensure_browser; then
    if [ "${BROWSER_FAMILY:-}" = "chromium" ]; then
      configure_chromium_profile "$CHROMIUM_PROFILE_DIR"
      configure_chromium_profile "$CHROMIUM_WINDOWED_PROFILE_DIR"
    else
      configure_firefox_profile "$FIREFOX_PROFILE_DIR"
      configure_firefox_profile "$FIREFOX_WINDOWED_PROFILE_DIR"
    fi
    write_browser_launchers
    DESKTOP_DIR=$(desktop_dir_for_user)
    write_desktop_shortcuts "$DESKTOP_DIR"
    echo -e "${GREEN}  ✓ Desktop shortcuts created${RESET}"
    echo -e "${DIM}    Browser:  ${BROWSER_BIN}${RESET}"
    echo -e "${DIM}    Windowed: ${DESKTOP_DIR}/Project: Caroline.desktop${RESET}"
    echo -e "${DIM}    Kiosk:    ${DESKTOP_DIR}/Project: Caroline Kiosk.desktop${RESET}"
  else
    echo -e "${YELLOW}  ⚠ Desktop shortcuts skipped because no supported browser was installed.${RESET}"
  fi
else
  echo -e "${YELLOW}  ⚠ No desktop environment detected — skipping desktop shortcuts.${RESET}"
fi

# ── KIOSK MODE ───────────────────────────────────────────────
if [ "$KIOSK_MODE" = "y" ] || [ "$KIOSK_MODE" = "Y" ]; then
  echo -e "${YELLOW}  ► Configuring kiosk mode...${RESET}"

  if is_wsl; then
    echo -e "${DIM}  WSL server/client mode detected — skipping kiosk autostart.${RESET}"
  elif ! has_desktop_environment; then
    echo -e "${YELLOW}  ⚠ No desktop environment detected — skipping kiosk setup.${RESET}"
    echo -e "${DIM}  Kiosk mode requires a desktop session, not a server/Lite install.${RESET}"
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

      # ── BROWSER PROFILE: suppress first-run and crash-recovery screens ──
      if [ "${BROWSER_FAMILY:-}" = "chromium" ]; then
        configure_chromium_profile "$CHROMIUM_PROFILE_DIR"
        configure_chromium_profile "$CHROMIUM_WINDOWED_PROFILE_DIR"
      else
        configure_firefox_profile "$FIREFOX_PROFILE_DIR"
        configure_firefox_profile "$FIREFOX_WINDOWED_PROFILE_DIR"
      fi
      write_browser_launchers
      echo -e "${GREEN}  ✓ Browser kiosk profile configured (${BROWSER_FAMILY})${RESET}"

      # Remove pre-existing Caroline browser autostart entries to prevent double-launch.
      for _autostart_file in "$REAL_HOME/.config/autostart/"*.desktop; do
        [ -f "$_autostart_file" ] || continue
        if grep -qi 'caroline' "$_autostart_file" 2>/dev/null; then
          rm -f "$_autostart_file" 2>/dev/null || true
        fi
      done
      unset _autostart_file
      [ -f "$REAL_HOME/.config/labwc/autostart" ] && \
        sed -i '/caroline/Id' "$REAL_HOME/.config/labwc/autostart" 2>/dev/null || true
      [ -f "$REAL_HOME/.config/wayfire.ini" ] && \
        sed -i '/caroline/Id' "$REAL_HOME/.config/wayfire.ini" 2>/dev/null || true

      # XDG autostart — primary launch method across all Pi OS window managers
      mkdir -p "$REAL_HOME/.config/autostart"
      cat > "$REAL_HOME/.config/autostart/caroline-kiosk.desktop" << EOF
[Desktop Entry]
Type=Application
Name=Caroline Kiosk
Comment=Launch Project: Caroline UI
Exec=${KIOSK_LAUNCHER}
Terminal=false
X-GNOME-Autostart-enabled=true
EOF
      chown "$REAL_USER:$REAL_USER" "$REAL_HOME/.config/autostart/caroline-kiosk.desktop" 2>/dev/null || true

      # labwc autostart — default Wayland compositor on Pi OS Bookworm (Pi 5)
      # Written unconditionally: labwc may not be in PATH until first boot
      mkdir -p "$REAL_HOME/.config/labwc"
      if ! grep -q "caroline" "$REAL_HOME/.config/labwc/autostart" 2>/dev/null; then
        echo "sleep 3 && ${KIOSK_LAUNCHER} &" >> "$REAL_HOME/.config/labwc/autostart"
        chmod +x "$REAL_HOME/.config/labwc/autostart"
      fi
      echo -e "${DIM}    labwc autostart configured${RESET}"

      # wayfire autostart — older Bookworm installs / alternative compositor
      # Written unconditionally: harmless if wayfire is not the active session
      mkdir -p "$REAL_HOME/.config"
      if ! grep -q "caroline" "$REAL_HOME/.config/wayfire.ini" 2>/dev/null; then
        printf '\n[autostart]\ncaroline = /bin/bash -c "sleep 3 && %s"\n' "${KIOSK_LAUNCHER}" >> "$REAL_HOME/.config/wayfire.ini"
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
phase "REACTIVATION COMPLETE"
PI_IP_FINAL=$(hostname -I | awk '{print $1}')
[ -n "$PI_IP_FINAL" ] || PI_IP_FINAL="localhost"
BROWSER_HOST_FINAL="$PI_IP_FINAL"
if is_wsl; then
  BROWSER_HOST_FINAL="localhost"
fi
echo ""
echo -e "${CYAN}  ════════════════════════════════════════════════════════════${RESET}"
echo ""
echo -e "${MAGENTA}       .------------------.      .------------------.${RESET}"
echo -e "${MAGENTA}      /  SIGNALS ONLINE  /|     /  MEMORY WARM     /|${RESET}"
echo -e "${CYAN}     /------------------/ |    /------------------/ |${RESET}"
echo -e "${CYAN}     |  UI READY        | |    |  FLOWS LOADED    | |${RESET}"
echo -e "${CYAN}     |  HOME LINKED     | /    |  CORE AWAKE      | /${RESET}"
echo -e "${CYAN}     |------------------|/     |------------------|/${RESET}"
echo ""
echo -e "${BOLD}${GREEN}  Project: Caroline is online. Assistant core is running.${RESET}"
echo ""
echo -e "${CYAN}  ┌─────────────────────────────────────────────────────────┐${RESET}"
echo -e "${CYAN}  │  PROJECT: CAROLINE — ONLINE                             │${RESET}"
echo -e "${CYAN}  ├─────────────────────────────────────────────────────────┤${RESET}"
echo -e "${CYAN}  │${RESET}  Kiosk URL:   ${BOLD}http://${BROWSER_HOST_FINAL}:${KIOSK_PORT}/${RESET}"
echo -e "${CYAN}  │${RESET}  Voice URL:   ${BOLD}https://${BROWSER_HOST_FINAL}:${HTTPS_UI_PORT}/${RESET}"
echo -e "${CYAN}  │${RESET}  Backend:     Node-RED on localhost:${NODE_RED_PORT}"
echo -e "${CYAN}  │${RESET}  HTTPS proxy: https://${BROWSER_HOST_FINAL}:${HTTPS_PROXY_PORT}"
if [ "$LOCAL_AUTH_ENABLED" = "true" ]; then
echo -e "${CYAN}  │${RESET}  Login user:  ${BOLD}caroline${RESET}"
echo -e "${CYAN}  │${RESET}  Login pass:  ${BOLD}cat ${CAROLINE_ADMIN_PASSWORD_PATH}${RESET}"
else
echo -e "${CYAN}  │${RESET}  Login:       disabled for this local install"
fi
if [ "$AI_PROVIDER" = "ollama" ]; then
echo -e "${CYAN}  │${RESET}  AI Core:     Local — Ollama (${OLLAMA_MODEL})"
else
echo -e "${CYAN}  │${RESET}  AI Core:     Cloud — OpenRouter (add key in settings)"
fi
echo -e "${CYAN}  └─────────────────────────────────────────────────────────┘${RESET}"
echo ""
if is_raspberry_pi; then
  echo -e "${CYAN}  ┌─────────────────────────────────────────────────────────┐${RESET}"
  echo -e "${CYAN}  │  OPEN CAROLINE ON THE PI                                │${RESET}"
  echo -e "${CYAN}  ├─────────────────────────────────────────────────────────┤${RESET}"
  if [ "$KIOSK_MODE" = "y" ] || [ "$KIOSK_MODE" = "Y" ]; then
echo -e "${CYAN}  │${RESET}  Pi display:        reboot and kiosk opens automatically"
  else
echo -e "${CYAN}  │${RESET}  Pi display:        use the desktop shortcut or browser"
  fi
  echo -e "${CYAN}  │${RESET}  On this Pi:        ${BOLD}http://localhost:${KIOSK_PORT}/${RESET}"
  if [ "${BROWSER_FAMILY:-}" = "chromium" ]; then
    echo -e "${CYAN}  │${RESET}  Kiosk browser:    Chromium-compatible"
  elif [ "${BROWSER_FAMILY:-}" = "firefox" ]; then
    echo -e "${CYAN}  │${RESET}  Kiosk browser:    Firefox fallback (typing/chat)"
  fi
  echo -e "${CYAN}  │${RESET}  Remote voice:     ${BOLD}https://${PI_IP_FINAL}:${HTTPS_UI_PORT}/${RESET}"
  echo -e "${CYAN}  │${RESET}  From another device: ${BOLD}http://${PI_IP_FINAL}:${KIOSK_PORT}/${RESET}"
  echo -e "${CYAN}  │${RESET}  If the IP changes: run ${BOLD}hostname -I${RESET} on the Pi"
  echo -e "${CYAN}  └─────────────────────────────────────────────────────────┘${RESET}"
elif is_wsl; then
  echo -e "${CYAN}  ┌─────────────────────────────────────────────────────────┐${RESET}"
  echo -e "${CYAN}  │  OPEN CAROLINE FROM WINDOWS                             │${RESET}"
  echo -e "${CYAN}  ├─────────────────────────────────────────────────────────┤${RESET}"
  echo -e "${CYAN}  │${RESET}  Windows browser:   ${BOLD}http://localhost:${KIOSK_PORT}/${RESET}"
  echo -e "${CYAN}  │${RESET}  Inside WSL:        ${BOLD}http://localhost:${KIOSK_PORT}/${RESET}"
  echo -e "${CYAN}  │${RESET}  WSL network IP:    http://${PI_IP_FINAL}:${KIOSK_PORT}/"
  echo -e "${CYAN}  │${RESET}  If it fails:       restart WSL or Windows, then retry localhost"
  echo -e "${CYAN}  └─────────────────────────────────────────────────────────┘${RESET}"
else
  echo -e "${CYAN}  ┌─────────────────────────────────────────────────────────┐${RESET}"
  echo -e "${CYAN}  │  OPEN CAROLINE FROM A BROWSER                           │${RESET}"
  echo -e "${CYAN}  ├─────────────────────────────────────────────────────────┤${RESET}"
  echo -e "${CYAN}  │${RESET}  On this host:        ${BOLD}http://localhost:${KIOSK_PORT}/${RESET}"
  echo -e "${CYAN}  │${RESET}  From client browser: ${BOLD}http://${PI_IP_FINAL}:${KIOSK_PORT}/${RESET}"
  echo -e "${CYAN}  │${RESET}  Voice in Chrome:     ${BOLD}https://${PI_IP_FINAL}:${HTTPS_UI_PORT}/${RESET}"
  echo -e "${CYAN}  │${RESET}  If the IP changes:   run ${BOLD}hostname -I${RESET} on this host"
  echo -e "${CYAN}  └─────────────────────────────────────────────────────────┘${RESET}"
fi
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
if is_wsl; then
echo -e "${CYAN}  │${RESET}  ${DIM}Ollama on Windows${RESET}  — optional; set URL to ${OLLAMA_URL_DEFAULT}"
fi
echo -e "${CYAN}  │${RESET}  ${DIM}Discord token${RESET}        — Settings > Connect (optional)"
echo -e "${CYAN}  │${RESET}  ${DIM}Spotify client ID${RESET}    — Settings > Connect (optional)"
echo -e "${CYAN}  │${RESET}  ${DIM}Google OAuth${RESET}         — Settings > Connect > Connect Google"
echo -e "${CYAN}  │${RESET}  ${DIM}Hue Bridge IP/key${RESET}    — Settings > Connect"
echo -e "${CYAN}  └─────────────────────────────────────────────────────────┘${RESET}"
echo ""
echo -e "${DIM}  Caroline is free to use. If you enjoy it and want to support future builds:${RESET}"
echo -e "${BOLD}    https://buymeacoffee.com/daveeuson${RESET}"
echo -e "${DIM}  Totally optional — no pressure, no locked features.${RESET}"
echo ""
echo -e "${MAGENTA}  You may now reboot when ready to finish startup setup.${RESET}"
echo ""
echo -e "${BOLD}  sudo reboot${RESET}"
echo ""
echo -e "${DIM}  If something's broken: sudo journalctl -u caroline -f${RESET}"
echo -e "${DIM}  Node-RED logs:         sudo journalctl -u caroline --since today${RESET}"
echo ""
echo -e "${CYAN}  ════════════════════════════════════════════════════════════${RESET}"
echo ""
