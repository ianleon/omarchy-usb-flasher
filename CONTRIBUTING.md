# Working on omarchy-usb-flasher

## Layout

```
shell/
  shell.qml        the window: two columns, footer, and the confirm /
                   progress / result overlays
  Theme.qml        palette from the active Omarchy theme's colors.toml,
                   plus fc-match and hyprctl for font and corner radius
  Drives.qml       lsblk poller; splits removable from fixed and flags
                   any disk holding the running system
  Isos.qml         finds .iso/.img files in the usual download directories
  Flasher.qml      runs flash.sh under pkexec and parses its line protocol
  Components/      Btn, Card, SelectRow, Toggle, ProgressTrack
  flash.sh         the privileged half: unmount, wipe, dd, sync, verify
```

`install.sh` symlinks `shell/` into `~/.config/quickshell/`, and Quickshell
reloads on save, so editing a file here updates the running app.

## Dry run

Set `USB_FLASHER_DRY_RUN` to a file path and the app becomes harmless:

```bash
: > /tmp/dryrun.img
USB_FLASHER_DRY_RUN=/tmp/dryrun.img qs -p shell/shell.qml
```

- the drive list gains a fake "Dry run target" row pointing at that file
- `flash.sh` runs directly instead of through `pkexec`, so there is no
  password prompt and no root
- the script skips everything disk-specific (unmount, wipefs, size check)
  when its target is a regular file, and writes and verifies exactly as it
  would to a real drive

This exercises the whole pipeline — progress parsing, stage transitions,
verification, the result screen — without a USB stick.

## Testing without the UI

Quickshell can run a headless config that drives the singletons directly.
Point the import at your checkout:

```qml
import QtQuick
import Quickshell
import "file:/home/you/omarchy-usb-flasher/shell"

ShellRoot {
  Component.onCompleted: Flasher.start("/tmp/in.iso", "/tmp/out.img", true)
  Connections {
    target: Flasher
    function onStateChanged() { console.log(Flasher.state, Flasher.error) }
  }
}
```

```bash
USB_FLASHER_DRY_RUN=1 qs -p that-file.qml
```

`flash.sh` is also runnable on its own, which is the fastest way to iterate on
the privileged half:

```bash
bash shell/flash.sh /tmp/in.iso /tmp/out.img 1
```

## Conventions

- Colors, fonts and radius come from `Theme`; don't hard-code them.
- Anything needing root belongs in `flash.sh`, not in a second `pkexec` call —
  one prompt per flash is a feature.
- Any new destructive path needs a matching guard in `Drives.qml`. The rule
  is that a disk holding the running system must never be selectable.
