#!/usr/bin/env bash
# Installs XPanel as a systemd service from the files next to this script.
# Usage:  sudo ./install.sh            (install or upgrade)
#         sudo ./install.sh uninstall  (remove the service and binary, keeps /etc/xpanel)
set -euo pipefail

PREFIX=/usr/local/xpanel
DATA=/etc/xpanel
HERE="$(cd "$(dirname "$0")" && pwd)"

[ "$(id -u)" -eq 0 ] || { echo "Please run as root (sudo)."; exit 1; }
command -v systemctl >/dev/null || { echo "systemd is required."; exit 1; }

if [ "${1:-}" = "uninstall" ]; then
  systemctl disable --now xpanel 2>/dev/null || true
  rm -f /etc/systemd/system/xpanel.service /usr/local/bin/xpanel
  rm -rf "$PREFIX"
  systemctl daemon-reload
  echo "XPanel removed. Your data in $DATA was kept; delete it manually if you want."
  exit 0
fi

case "$(uname -m)" in
  x86_64|amd64)  ARCH=amd64 ;;
  aarch64|arm64) ARCH=arm64 ;;
  *) echo "Unsupported architecture: $(uname -m)"; exit 1 ;;
esac

BIN="$HERE/xpanel-linux-$ARCH"
[ -f "$BIN" ] || BIN="$HERE/xpanel"
[ -f "$BIN" ] || { echo "Binary not found next to install.sh (looked for xpanel-linux-$ARCH and xpanel)."; exit 1; }

UPGRADE=0; [ -f "$DATA/xpanel.db.json" ] && UPGRADE=1
systemctl stop xpanel 2>/dev/null || true

mkdir -p "$PREFIX" "$DATA"
chmod 700 "$DATA"
install -m 755 "$BIN" "$PREFIX/xpanel"
ln -sf "$PREFIX/xpanel" /usr/local/bin/xpanel
install -m 644 "$HERE/xpanel.service" /etc/systemd/system/xpanel.service
systemctl daemon-reload
systemctl enable --now xpanel

echo
if [ "$UPGRADE" -eq 1 ]; then
  echo "XPanel was upgraded; your data was kept."
  XPANEL_DATA="$DATA" xpanel setting -show
else
  # the first start generates the credentials; wait for them to be written
  for _ in $(seq 1 20); do [ -f "$DATA/xpanel.db.json" ] && break; sleep 0.5; done
  echo "XPanel is installed and running. The generated login is in the service log:"
  echo "    journalctl -u xpanel -n 20 --no-pager"
  sleep 1
  journalctl -u xpanel -n 20 --no-pager 2>/dev/null | sed -n '/First run/,/Change them/p' || true
fi
echo
echo "Then open the panel, go to Xray, and install a Xray version."
echo "Manage with: systemctl status|restart xpanel   and   XPANEL_DATA=$DATA xpanel setting -h"
