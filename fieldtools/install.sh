#!/bin/bash
# DSSI Field Tools installer for the PocketTerm (Raspberry Pi OS).
#   curl -fsSL https://ognightrider555-cell.github.io/job-display-installer/fieldtools/install.sh | bash
# Asks for the setup key (read-only access to the private repo), downloads the app into
# ~/dssi-field-tools and adds the desktop icon, menu entry and taskbar button.
# Run it again to update; cameras.toml is kept. The key is not saved anywhere.
set -euo pipefail

OWNER=ognightrider555-cell
REPO=onvif-camtool
BRANCH=main
DEST="$HOME/dssi-field-tools"

say()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31mError:\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -ne 0 ] || fail "Run this as your normal user, not with sudo."
for c in curl tar python3; do command -v "$c" >/dev/null || fail "$c is missing."; done

python3 -c 'import sys; sys.exit(sys.version_info < (3, 11))' \
  || fail "Python 3.11 or newer is needed (this has $(python3 --version 2>&1))."
python3 -c 'import gi; gi.require_version("Gtk", "3.0"); from gi.repository import Gtk' 2>/dev/null \
  || fail "GTK for Python is missing. Run: sudo apt install python3-gi gir1.2-gtk-3.0   then run this again."

KEY="${FT_KEY:-}"
if [ -z "$KEY" ]; then
  [ -r /dev/tty ] || fail "No terminal to ask for the setup key. Set FT_KEY and run again."
  printf 'Paste the setup key and press Enter (it stays hidden): ' > /dev/tty
  IFS= read -rs KEY < /dev/tty
  printf '\n' > /dev/tty
fi
KEY="$(printf '%s' "$KEY" | tr -d '[:space:]')"
[ -n "$KEY" ] || fail "No setup key entered."

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

say "Downloading DSSI Field Tools..."
code="$(curl -sSL -o "$TMP/app.tgz" -w '%{http_code}' \
  -H "Authorization: Bearer $KEY" -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/$OWNER/$REPO/tarball/$BRANCH")" || fail "Download failed. Check the internet connection."
case "$code" in
  200) ;;
  401|403|404) fail "GitHub refused the setup key (HTTP $code). Check the key and run this again." ;;
  *) fail "Download failed (HTTP $code). Try again in a minute." ;;
esac
unset KEY

VER="$(tar -tzf "$TMP/app.tgz" | sed -n '1s#.*-\([0-9a-f]\{7\}\)[0-9a-f]*/$#\1#p')"
mkdir "$TMP/new"
tar -xzf "$TMP/app.tgz" -C "$TMP/new" --strip-components=1
[ -f "$TMP/new/camtool.py" ] && [ -f "$TMP/new/ui/install.sh" ] || fail "The download doesn't look like Field Tools."

# Keep the site settings from this install, or from an older hand-copied ~/onvif-camtool.
for old in "$DEST/cameras.toml" "$HOME/onvif-camtool/cameras.toml"; do
  if [ -f "$old" ]; then cp -p "$old" "$TMP/new/cameras.toml"; say "Kept settings from $old"; break; fi
done

if [ -d "$DEST" ]; then rm -rf "$DEST.old"; mv "$DEST" "$DEST.old"; fi
mv "$TMP/new" "$DEST"
rm -rf "$DEST.old"

say "Adding the icons..."
sh "$DEST/ui/install.sh"

say "Done. Open DSSI Field Tools from the taskbar button, the desktop icon or the app menu."
say "Installed version ${VER:-unknown} in $DEST"
