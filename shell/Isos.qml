pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Finds disk images in the handful of places they actually get downloaded to,
// newest first. Anything outside those directories comes in through the file
// picker instead.
Singleton {
  id: root

  readonly property string home: String(Quickshell.env("HOME") || "")
  readonly property var searchDirs: [
    home + "/Downloads",
    home + "/Desktop",
    home + "/Documents",
    home + "/ISOs",
    home + "/isos",
    home + "/Images"
  ]

  property var images: []
  property bool scanned: false

  function refresh() {
    if (!scan.running) scan.running = true
  }

  function basename(path) {
    var parts = String(path).split("/")
    return parts[parts.length - 1]
  }

  function dirname(path) {
    var full = String(path).replace(/\/[^\/]*$/, "")
    return full.indexOf(home) === 0 ? "~" + full.slice(home.length) : full
  }

  // Files are added by the picker; keep the newest-first order and never
  // list the same path twice.
  function adopt(path) {
    var cleaned = String(path).replace(/^file:\/\//, "")
    var kept = images.filter(function (image) {
      return image.path !== cleaned
    })
    kept.unshift({
      path: cleaned,
      name: basename(cleaned),
      dir: dirname(cleaned),
      size: 0,
      sizeText: ""
    })
    images = kept
    sizeProbe.target = cleaned
    sizeProbe.running = true
    return cleaned
  }

  function applySize(path, bytes) {
    images = images.map(function (image) {
      if (image.path !== path) return image
      return {
        path: image.path,
        name: image.name,
        dir: image.dir,
        size: bytes,
        sizeText: Drives.humanSize(bytes)
      }
    })
  }

  Process {
    id: scan
    running: true
    command: ["bash", "-c",
      "for dir in \"$@\"; do [ -d \"$dir\" ] && find \"$dir\" -maxdepth 2 -type f " +
      "\\( -iname '*.iso' -o -iname '*.img' \\) -printf '%s\\t%T@\\t%p\\n'; done 2>/dev/null | sort -k2 -rn",
      "find-images"].concat(root.searchDirs)
    stdout: StdioCollector {
      onStreamFinished: {
        var found = []
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
          var fields = lines[i].split("\t")
          if (fields.length < 3) continue
          var bytes = Number(fields[0]) || 0
          found.push({
            path: fields[2],
            name: root.basename(fields[2]),
            dir: root.dirname(fields[2]),
            size: bytes,
            sizeText: Drives.humanSize(bytes)
          })
        }
        root.images = found
        root.scanned = true
      }
    }
  }

  Process {
    id: sizeProbe
    property string target: ""
    command: ["stat", "-Lc", "%s", target]
    stdout: StdioCollector {
      onStreamFinished: {
        var bytes = Number(text.trim())
        if (bytes > 0) root.applySize(sizeProbe.target, bytes)
      }
    }
  }
}
