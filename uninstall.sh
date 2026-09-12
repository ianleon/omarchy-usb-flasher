#!/bin/bash
set -euo pipefail

for link in \
  "$HOME/.config/quickshell/omarchy-usb-flasher" \
  "$HOME/.local/bin/omarchy-usb-flasher" \
  "$HOME/.local/share/applications/omarchy-usb-flasher.desktop"
do
  if [[ -L $link ]]; then
    rm "$link"
    echo "removed $link"
  fi
done
