#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="$HOME/.local/share/kwin/scripts/sidepin"

echo "Installing SidePin from: $SCRIPT_DIR/kwin-script"
echo "Destination: $DEST"

mkdir -p "$DEST"
cp -r "$SCRIPT_DIR/kwin-script/." "$DEST/"

echo "Reloading KWin config..."
gdbus call --session \
    --dest org.kde.KWin \
    --object-path /KWin \
    --method org.kde.KWin.reconfigure \
    > /dev/null

echo ""
echo "Done. If this is your first install, logout+login is required."
echo "For updates (after git pull), reconfigure is enough — no logout needed."
