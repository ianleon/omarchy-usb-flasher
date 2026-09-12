pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Polls lsblk and splits what it finds into removable drives (safe to offer)
// and everything else (offered only behind the "show every disk" toggle, and
// never when the running system lives on it).
Singleton {
  id: root

  // Mounting anywhere in here means the disk is carrying the live system.
  readonly property var systemMounts: ["/", "/boot", "/boot/efi", "/efi", "/home", "/var", "/nix", "[SWAP]"]

  readonly property string dryRunTarget: String(Quickshell.env("USB_FLASHER_DRY_RUN") || "")

  property var removable: []
  property var fixed: []
  property bool scanned: false
  property bool polling: false

  function refresh() {
    if (!scan.running) scan.running = true
  }

  function describe(node) {
    var name = [node.vendor, node.model].filter(function (part) {
      return part && String(part).trim().length
    }).join(" ").trim()
    return name.length ? name : node.name
  }

  function humanSize(bytes) {
    var units = ["B", "KB", "MB", "GB", "TB"]
    var value = Number(bytes) || 0
    var unit = 0
    while (value >= 1000 && unit < units.length - 1) {
      value /= 1000
      unit++
    }
    return (value >= 100 || unit === 0 ? Math.round(value) : value.toFixed(1)) + " " + units[unit]
  }

  function collectMounts(node, into) {
    var points = node.mountpoints || []
    for (var i = 0; i < points.length; i++)
      if (points[i]) into.push(points[i])
    var children = node.children || []
    for (var j = 0; j < children.length; j++)
      collectMounts(children[j], into)
    return into
  }

  function toDrive(node) {
    var mounts = collectMounts(node, [])
    var system = mounts.some(function (mount) {
      return root.systemMounts.indexOf(mount) >= 0
    })
    return {
      path: node.path,
      name: node.name,
      label: describe(node),
      size: Number(node.size) || 0,
      sizeText: humanSize(node.size),
      transport: (node.tran || "").toUpperCase(),
      removable: !!node.rm || !!node.hotplug || node.tran === "usb",
      readOnly: !!node.ro,
      mounts: mounts,
      isSystem: system
    }
  }

  Process {
    id: scan
    command: ["lsblk", "-J", "-b", "-o", "NAME,PATH,SIZE,MODEL,VENDOR,TRAN,RM,HOTPLUG,TYPE,MOUNTPOINTS,RO"]
    stdout: StdioCollector {
      onStreamFinished: {
        var parsed
        try {
          parsed = JSON.parse(text)
        } catch (e) {
          return
        }

        var removable = []
        var fixed = []
        if (root.dryRunTarget.length) {
          removable.push({
            path: root.dryRunTarget,
            name: "dry-run",
            label: "Dry run target (not a real drive)",
            size: Number.MAX_SAFE_INTEGER,
            sizeText: "dry run",
            transport: "FILE",
            removable: true,
            readOnly: false,
            mounts: [],
            isSystem: false
          })
        }
        var nodes = parsed.blockdevices || []
        for (var i = 0; i < nodes.length; i++) {
          var node = nodes[i]
          if (node.type !== "disk") continue
          // Virtual block devices are never a flash target.
          if (/^(zram|loop|ram|md|dm-|sr)/.test(node.name)) continue

          var drive = root.toDrive(node)
          if (drive.readOnly) continue
          if (drive.removable && !drive.isSystem) removable.push(drive)
          else fixed.push(drive)
        }
        root.removable = removable
        root.fixed = fixed
        root.scanned = true
      }
    }
  }

  Timer {
    running: root.polling
    interval: 2000
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }
}
