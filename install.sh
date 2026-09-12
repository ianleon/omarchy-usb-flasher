#!/bin/bash
# Symlink the app into place so edits in this checkout are live.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config_dir="$HOME/.config/quickshell/omarchy-usb-flasher"
bin_dir="$HOME/.local/bin"
apps_dir="$HOME/.local/share/applications"

command -v qs >/dev/null || { echo "quickshell (qs) is not installed" >&2; exit 1; }

mkdir -p "$(dirname "$config_dir")" "$bin_dir" "$apps_dir"

# A stale symlink is replaced; a real directory is left alone so a hand-made
# copy is never silently destroyed.
if [[ -e $config_dir && ! -L $config_dir ]]; then
  echo "$config_dir already exists and is not a symlink — move it aside first" >&2
  exit 1
fi

ln -sfn "$repo" "$config_dir"
ln -sf "$repo/bin/omarchy-usb-flasher" "$bin_dir/omarchy-usb-flasher"
ln -sf "$repo/share/omarchy-usb-flasher.desktop" "$apps_dir/omarchy-usb-flasher.desktop"

echo "Installed:"
echo "  $config_dir -> $repo"
echo "  $bin_dir/omarchy-usb-flasher"
echo "  $apps_dir/omarchy-usb-flasher.desktop"
echo
echo "Run it with: omarchy-usb-flasher"

case ":$PATH:" in
  *":$bin_dir:"*) ;;
  *) echo "Note: $bin_dir is not on your PATH." ;;
esac
