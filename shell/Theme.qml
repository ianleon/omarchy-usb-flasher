pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Palette + metrics pulled from the theme Omarchy has applied right now, so
// the app repaints itself when `omarchy theme set` runs. Only colors.toml is
// read: it is the one file every Omarchy theme is guaranteed to ship.
Singleton {
  id: root

  readonly property string statePath: String(Quickshell.env("HOME") || "") + "/.local/state/omarchy/current/theme"

  property color background: "#2e3440"
  property color surface: "#3b4252"
  property color foreground: "#d8dee9"
  property color muted: "#4c566a"
  property color accent: "#81a1c1"
  property color danger: "#bf616a"
  property color warning: "#ebcb8b"
  property color success: "#a3be8c"

  property string fontFamily: "monospace"
  property int cornerRadius: 0

  readonly property int fontSmall: 11
  readonly property int fontBody: 13
  readonly property int fontTitle: 15
  readonly property int fontHeading: 19

  function dim(color, alpha) {
    return Qt.rgba(color.r, color.g, color.b, alpha)
  }

  function parse(raw) {
    var values = ({})
    var lines = String(raw || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var kv = lines[i].match(/^\s*([A-Za-z0-9_]+)\s*=\s*["']?(#[0-9A-Fa-f]{6})/)
      if (kv) values[kv[1]] = kv[2]
    }
    if (!Object.keys(values).length) return

    background = values["background"] || background
    surface = values["lighter_background"] || values["selection"] || surface
    foreground = values["foreground"] || foreground
    muted = values["dark_foreground"] || values["muted"] || muted
    accent = values["accent"] || values["blue"] || accent
    danger = values["red"] || danger
    warning = values["yellow"] || values["orange"] || warning
    success = values["green"] || success
  }

  FileView {
    path: root.statePath + "/colors.toml"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: root.parse(text())
  }

  // Same two lookups the shell does, so the app agrees with the bar about
  // which monospace family and how much corner rounding is in force.
  Process {
    running: true
    command: ["fc-match", "-f", "%{family[0]}", "monospace"]
    stdout: StdioCollector {
      onStreamFinished: if (text.trim()) root.fontFamily = text.trim()
    }
  }

  Process {
    running: true
    command: ["hyprctl", "getoption", "decoration:rounding", "-j"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var value = JSON.parse(text).int
          if (value >= 0) root.cornerRadius = Math.min(value, 16)
        } catch (e) {}
      }
    }
  }
}
