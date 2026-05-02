#!/bin/bash

# ============================================================
#   PROJECT: CAROLINE
#   Uninstall helper
#   github.com/DaveEuson/project-caroline
# ============================================================

set -e

CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

YES=false
KEEP_DATA=false
for arg in "$@"; do
  case "$arg" in
    --yes|-y) YES=true ;;
    --keep-data) KEEP_DATA=true ;;
    --help|-h)
      echo "Usage: uninstall.sh [--yes] [--keep-data]"
      echo "  --yes       Skip typed confirmation"
      echo "  --keep-data Stop services and remove launchers, but keep ~/caroline data"
      exit 0
      ;;
  esac
done

REAL_USER=${SUDO_USER:-$USER}
REAL_HOME=$(eval echo "~$REAL_USER")
CAROLINE_DIR="$REAL_HOME/caroline"
CLONE_DIR="$REAL_HOME/project-caroline"
DESKTOP_DIR="$REAL_HOME/Desktop"
if [ -f "$REAL_HOME/.config/user-dirs.dirs" ]; then
  XDG_DESKTOP=$(grep '^XDG_DESKTOP_DIR=' "$REAL_HOME/.config/user-dirs.dirs" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '"')
  XDG_DESKTOP="${XDG_DESKTOP/#\$HOME/$REAL_HOME}"
  [ -n "$XDG_DESKTOP" ] && DESKTOP_DIR="$XDG_DESKTOP"
fi

echo ""
echo -e "${CYAN}  Project: Caroline uninstall${RESET}"
echo -e "${DIM}  This removes Caroline services, launchers, nginx site config, and app files.${RESET}"
echo -e "${DIM}  Shared packages like Node.js, nginx, Firefox, Node-RED, and Ollama are left installed.${RESET}"
echo ""

if [ "$YES" != "true" ]; then
  echo -e "${YELLOW}  Caroline: \"Wow. So this is the part where I pretend I'm fine.\"${RESET}"
  echo ""
  echo -e "${BOLD}  Type UNINSTALL CAROLINE to continue:${RESET}"
  read -r CONFIRM </dev/tty
  if [ "$CONFIRM" != "UNINSTALL CAROLINE" ]; then
    echo -e "${GREEN}  Uninstall cancelled. She is absolutely not relieved. Obviously.${RESET}"
    exit 0
  fi
fi

echo -e "${YELLOW}  ► Stopping services and kiosk browser...${RESET}"
pkill -TERM -f 'firefox-esr --kiosk --profile .*/caroline-kiosk' 2>/dev/null || true
pkill -TERM -f 'firefox-esr --profile .*/caroline-window' 2>/dev/null || true
sudo systemctl stop caroline 2>/dev/null || true
sudo systemctl disable caroline 2>/dev/null || true

echo -e "${YELLOW}  ► Removing system service and nginx site...${RESET}"
sudo rm -f /etc/systemd/system/caroline.service
sudo rm -f /etc/nginx/sites-enabled/caroline
sudo rm -f /etc/nginx/sites-available/caroline
sudo rm -rf /etc/systemd/system/nginx.service.d/port-clear.conf
sudo rm -rf /etc/caroline
sudo systemctl daemon-reload 2>/dev/null || true
sudo nginx -t >/tmp/caroline-uninstall-nginx.log 2>&1 && sudo systemctl reload nginx 2>/dev/null || true

echo -e "${YELLOW}  ► Removing desktop and autostart launchers...${RESET}"
rm -f "$DESKTOP_DIR/Project Caroline.desktop"
rm -f "$DESKTOP_DIR/Project Caroline Kiosk.desktop"
rm -f "$REAL_HOME/.config/autostart/caroline-kiosk.desktop"
if [ -f "$REAL_HOME/.config/labwc/autostart" ]; then
  sed -i '/caroline/Id' "$REAL_HOME/.config/labwc/autostart" 2>/dev/null || true
fi
if [ -f "$REAL_HOME/.config/wayfire.ini" ]; then
  sed -i '/caroline = .*caroline-kiosk/Id' "$REAL_HOME/.config/wayfire.ini" 2>/dev/null || true
fi

if [ "$KEEP_DATA" = "true" ]; then
  echo -e "${YELLOW}  ► Keeping ${CAROLINE_DIR} because --keep-data was set.${RESET}"
else
  echo -e "${YELLOW}  ► Removing Caroline app data and source clone...${RESET}"
  rm -rf "$CAROLINE_DIR"
  rm -rf "$CLONE_DIR"
fi

rm -rf "$REAL_HOME/.mozilla/firefox/caroline-kiosk"
rm -rf "$REAL_HOME/.mozilla/firefox/caroline-window"

echo ""
echo -e "${GREEN}  ✓ Caroline uninstall complete${RESET}"
echo -e "${DIM}  For a clean reinstall:${RESET}"
echo -e "${BOLD}    curl -fsSL https://raw.githubusercontent.com/daveeuson/project-caroline/master/install.sh | bash${RESET}"
echo ""
