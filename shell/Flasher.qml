pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Drives flash.sh under pkexec and turns its protocol lines into progress
// state. One privileged process does unmount, wipe, write, sync and verify,
// so the user authenticates once per flash.
Singleton {
  id: root

  readonly property string helper: Qt.resolvedUrl("flash.sh").toString().replace(/^file:\/\//, "")

  // USB_FLASHER_DRY_RUN=/path/to/file turns the app into a harmless rehearsal:
  // Drives offers that file as a fake target and the write runs unprivileged.
  // Used for development — see CONTRIBUTING.
  readonly property bool dryRun: String(Quickshell.env("USB_FLASHER_DRY_RUN") || "").length > 0

  readonly property var stageLabels: ({
    "unmount": "Unmounting the drive",
    "wipe": "Clearing old partition signatures",
    "write": "Writing the image",
    "sync": "Flushing to the drive",
    "hash-iso": "Checksumming the ISO",
    "hash-device": "Checksumming the drive"
  })

  // idle | running | done | failed
  property string state: "idle"
  property string stage: ""
  property string isoPath: ""
  property string devicePath: ""
  property bool verify: true
  property bool verified: false
  property string error: ""

  property real totalBytes: 0
  property real stageBytes: 0
  property real speed: 0
  property real eta: -1
  property int rootPid: 0
  property bool cancelling: false

  readonly property bool busy: state === "running"
  readonly property string stageLabel: stageLabels[stage] || "Preparing"
  // Write is one pass, verify adds two more; weight them so the bar advances
  // monotonically across the whole job instead of resetting per stage.
  readonly property real progress: {
    if (state === "done") return 1
    if (totalBytes <= 0) return 0
    var fraction = Math.min(1, stageBytes / totalBytes)
    var passes = verify ? 3 : 1
    var completed = { "write": 0, "sync": 1, "hash-iso": 1, "hash-device": 2 }
    if (!(stage in completed)) return 0
    if (stage === "sync") return 1 / passes
    return (completed[stage] + fraction) / passes
  }

  function start(iso, device, verifyAfter) {
    if (busy) return
    isoPath = iso
    devicePath = device
    verify = !!verifyAfter
    verified = false
    error = ""
    stage = ""
    totalBytes = 0
    stageBytes = 0
    speed = 0
    eta = -1
    rootPid = 0
    cancelling = false
    sampler.reset()
    state = "running"
    job.command = (dryRun ? ["/bin/bash"] : ["pkexec", "/bin/bash"])
      .concat([helper, iso, device, verifyAfter ? "1" : "0"])
    job.running = true
  }

  function cancel() {
    if (!busy || cancelling) return
    cancelling = true
    if (dryRun) {
      job.signal(15)
    } else if (rootPid > 0) {
      // The write runs as root, so the kill has to as well. pkexec normally
      // still holds the authorization from the flash itself.
      killer.command = ["pkexec", "/usr/bin/kill", "-TERM", String(rootPid)]
      killer.running = true
    } else {
      job.signal(15)
    }
  }

  function reset() {
    if (busy) return
    state = "idle"
    stage = ""
    error = ""
  }

  function handleLine(line) {
    var trimmed = line.trim()
    if (!trimmed.length) return

    var match
    if ((match = trimmed.match(/^PID (\d+)$/))) {
      rootPid = Number(match[1])
    } else if ((match = trimmed.match(/^TOTAL (\d+)$/))) {
      totalBytes = Number(match[1])
    } else if ((match = trimmed.match(/^STAGE (\S+)$/))) {
      stage = match[1]
      stageBytes = 0
      sampler.reset()
    } else if ((match = trimmed.match(/^(\d+) bytes/))) {
      stageBytes = Number(match[1])
    } else if (trimmed === "VERIFY_OK") {
      verified = true
    } else if ((match = trimmed.match(/^ERROR (.+)$/))) {
      error = match[1]
    }
  }

  Process {
    id: job
    stdout: SplitParser { onRead: line => root.handleLine(line) }
    stderr: SplitParser {
      onRead: line => {
        // pkexec's own refusals (dismissed dialog, wrong password) land here.
        if (/not authorized|dismissed|Authentication failed|Error executing/i.test(line) && !root.error)
          root.error = line.trim()
      }
    }
    onExited: exitCode => {
      if (exitCode === 0) {
        root.stage = ""
        root.stageBytes = root.totalBytes
        root.state = "done"
      } else {
        if (!root.error)
          root.error = root.cancelling
            ? "Cancelled — the drive is half-written and not bootable"
            : (exitCode === 126 || exitCode === 127
               ? "Authentication was dismissed or denied"
               : "The helper exited with code " + exitCode)
        root.state = "failed"
      }
      root.cancelling = false
      root.rootPid = 0
    }
  }

  Process { id: killer }

  // Speed and ETA from the byte counter rather than dd's own rate line, so
  // they stay meaningful across the verify passes too.
  Timer {
    id: sampler
    property real lastBytes: 0
    property real lastAt: 0

    function reset() {
      lastBytes = 0
      lastAt = 0
      root.speed = 0
      root.eta = -1
    }

    running: root.busy
    interval: 500
    repeat: true
    onTriggered: {
      var now = Date.now()
      if (lastAt > 0 && root.stageBytes > lastBytes) {
        var rate = (root.stageBytes - lastBytes) / ((now - lastAt) / 1000)
        // Smooth it; raw dd throughput swings hard on USB writeback.
        root.speed = root.speed > 0 ? root.speed * 0.7 + rate * 0.3 : rate
        root.eta = root.speed > 0 ? Math.max(0, (root.totalBytes - root.stageBytes) / root.speed) : -1
      }
      lastBytes = root.stageBytes
      lastAt = now
    }
  }
}
