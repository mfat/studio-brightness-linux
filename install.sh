#!/usr/bin/env bash
# Install Studio Brightness: the studio-brightness commands, its udev rule, and GNOME keyboard shortcuts.
#
#   ./install.sh                         install with default shortcuts (Super+F2 / Super+F1)
#   ./install.sh --up '<Super>F15' --down '<Super>F14'
#   ./install.sh --no-shortcuts
#   ./install.sh --uninstall
set -euo pipefail

cd "$(dirname "$0")"

BIN="$HOME/.local/bin/studio-brightness"
GUI="$HOME/.local/bin/studio-brightness-gui"
OSD="$HOME/.local/bin/studio-brightness-osd"
DESKTOP="$HOME/.local/share/applications/io.github.mfat.StudioBrightness.desktop"
ICONS="$HOME/.local/share/icons/hicolor"
ICON="$ICONS/scalable/apps/io.github.mfat.StudioBrightness.svg"
SYMBOLIC="$ICONS/symbolic/apps/io.github.mfat.StudioBrightness-symbolic.svg"
RULE=/etc/udev/rules.d/70-studio-brightness.rules
SCHEMA=org.gnome.settings-daemon.plugins.media-keys
KB_BASE=/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings

up_key='<Super>F2'
down_key='<Super>F1'
shortcuts=1
uninstall=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --up) up_key="$2"; shift 2 ;;
    --down) down_key="$2"; shift 2 ;;
    --no-shortcuts) shortcuts=0; shift ;;
    --uninstall) uninstall=1; shift ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

if [[ $EUID -eq 0 ]]; then
  echo "Run this as your normal user; it calls sudo where needed." >&2
  exit 1
fi

have_gsettings() {
  command -v gsettings >/dev/null && gsettings list-schemas | grep -x "$SCHEMA" >/dev/null
}

kb_list() { gsettings get "$SCHEMA" custom-keybindings; }

add_binding() { # id name command binding
  local path="$KB_BASE/$1/"
  local key="$SCHEMA.custom-keybinding:$path"
  gsettings set "$key" name "$2"
  gsettings set "$key" command "$3"
  gsettings set "$key" binding "$4"
  local list; list=$(kb_list)
  if [[ $list != *"'$path'"* ]]; then
    if [[ $list == "@as []" || $list == "[]" ]]; then
      list="['$path']"
    else
      list="${list%]}, '$path']"
    fi
    gsettings set "$SCHEMA" custom-keybindings "$list"
  fi
}

remove_binding() { # id
  local path="$KB_BASE/$1/"
  local list; list=$(kb_list)
  list=${list//", '$path'"/}
  list=${list//"'$path', "/}
  list=${list//"'$path'"/}
  [[ $list == "[]" ]] && list="@as []"
  gsettings set "$SCHEMA" custom-keybindings "$list"
  gsettings reset-recursively "$SCHEMA.custom-keybinding:$path" 2>/dev/null || true
}

# Remove an install from before the rename to studio-brightness.
remove_legacy() {
  rm -f "$HOME/.local/bin/apple-brightness" "$HOME/.local/bin/apple-brightness-gui" \
        "$HOME/.local/share/applications/apple-brightness.desktop" \
        "$HOME/.local/share/applications/studio-brightness.desktop"
  [[ -e /etc/udev/rules.d/70-apple-brightness.rules ]] && sudo rm -f /etc/udev/rules.d/70-apple-brightness.rules
  if have_gsettings && [[ $(kb_list) == *apple-brightness* ]]; then
    remove_binding apple-brightness-up
    remove_binding apple-brightness-down
  fi
}

remove_legacy

if [[ $uninstall -eq 1 ]]; then
  rm -f "$BIN" "$GUI" "$OSD" "$DESKTOP" "$ICON" "$SYMBOLIC"
  sudo rm -f "$RULE"
  sudo udevadm control --reload-rules
  if have_gsettings; then
    remove_binding studio-brightness-up
    remove_binding studio-brightness-down
  fi
  echo "Uninstalled."
  exit 0
fi

install -Dm755 studio-brightness "$BIN"
echo "Installed $BIN"

install -Dm755 studio-brightness-osd "$OSD"
install -Dm755 studio-brightness-gui "$GUI"
install -Dm644 data/icons/io.github.mfat.StudioBrightness.svg "$ICON"
install -Dm644 data/icons/io.github.mfat.StudioBrightness-symbolic.svg "$SYMBOLIC"
sed "s|^Exec=.*|Exec=$GUI|" data/io.github.mfat.StudioBrightness.desktop > "$DESKTOP"
echo "Installed $GUI (\"Studio Brightness\" in the app menu; needs GTK4 + libadwaita)"

sudo install -Dm644 data/70-studio-brightness.rules "$RULE"
sudo udevadm control --reload-rules
sudo udevadm trigger --action=add --subsystem-match=hidraw --subsystem-match=backlight
# Re-run the usbhid -> appledisplay handover for displays already plugged in.
sudo udevadm trigger --action=add --subsystem-match=usb --property-match=DRIVER=usbhid
sudo udevadm settle
echo "Installed $RULE"

relogin=0
if ls /sys/class/backlight/appledisplay* >/dev/null 2>&1 && ! id -nG | grep -qw video; then
  sudo usermod -aG video "$USER"
  relogin=1
  echo "Added $USER to the 'video' group."
fi

if [[ $shortcuts -eq 1 ]]; then
  if have_gsettings; then
    add_binding studio-brightness-up "Studio Brightness up" "$BIN up --osd" "$up_key"
    add_binding studio-brightness-down "Studio Brightness down" "$BIN down --osd" "$down_key"
    echo "GNOME shortcuts: $up_key = brighter, $down_key = dimmer"
  else
    echo "GNOME not detected, skipping keyboard shortcuts."
  fi
fi

echo
"$BIN" list || true
if [[ $relogin -eq 1 ]]; then
  echo
  echo "Log out and back in so the new 'video' group membership applies."
fi
