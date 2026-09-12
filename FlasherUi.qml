import QtQuick
import QtQuick.Dialogs
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "Components"
import "."

// The whole interface, independent of how it is presented. shell.qml hosts it
// in a normal window; Overlay.qml hosts it as an Omarchy shell overlay. The
// host decides what closing means, so this emits closeRequested rather than
// ending the process itself.
Item {
  id: ui

  signal closeRequested

  // Polling lsblk every two seconds is only worth it while the user can see
  // the list, which matters when the shell keeps this plugin loaded.
  property bool active: true
  onActiveChanged: {
    Drives.polling = active
    if (active) Isos.refresh()
  }
  Component.onCompleted: Drives.polling = active

  property string isoPath: ""
  property var drive: null
  property bool showAllDisks: false
  property bool confirming: false
  property bool verifyAfterWrite: true
  // Which list the arrow keys drive. Clicking either list moves it here.
  property string pane: "iso"

  readonly property var iso: {
    for (var i = 0; i < Isos.images.length; i++)
      if (Isos.images[i].path === isoPath) return Isos.images[i]
    return null
  }
  readonly property var driveList: showAllDisks
    ? Drives.removable.concat(Drives.fixed)
    : Drives.removable
  readonly property bool tooSmall: !!(iso && drive && iso.size > 0 && drive.size > 0 && drive.size < iso.size)
  readonly property bool ready: !!iso && !!drive && !drive.isSystem && !tooSmall
  readonly property bool overlayOpen: confirming || Flasher.state !== "idle"

  // Keep the chosen drive pointing at live lsblk data, and drop it the
  // moment the drive is unplugged.
  Connections {
    target: Drives
    function onRemovableChanged() { ui.resyncDrive() }
    function onFixedChanged() { ui.resyncDrive() }
  }

  function resyncDrive() {
    if (!drive) return
    var all = Drives.removable.concat(Drives.fixed)
    for (var i = 0; i < all.length; i++)
      if (all[i].path === drive.path) { drive = all[i]; return }
    if (!Flasher.busy) drive = null
  }

  function indexOfPath(list, path) {
    for (var i = 0; i < list.length; i++)
      if (list[i].path === path) return i
    return -1
  }

  function step(list, currentPath, delta) {
    if (!list.length) return null
    var index = indexOfPath(list, currentPath)
    if (index < 0) return list[delta > 0 ? 0 : list.length - 1]
    return list[Math.max(0, Math.min(list.length - 1, index + delta))]
  }

  function togglePane() {
    pane = pane === "iso" ? "drive" : "iso"
  }

  function move(delta) {
    if (pane === "iso") {
      var image = step(Isos.images, isoPath, delta)
      if (image) isoPath = image.path
    } else {
      var target = step(driveList, drive ? drive.path : "", delta)
      if (target && !target.isSystem) drive = target
    }
  }

  function humanTime(seconds) {
    if (seconds < 0 || !isFinite(seconds)) return "—"
    var total = Math.round(seconds)
    var minutes = Math.floor(total / 60)
    var rest = total % 60
    if (minutes >= 60) return Math.floor(minutes / 60) + "h " + (minutes % 60) + "m"
    return minutes > 0 ? minutes + "m " + rest + "s" : rest + "s"
  }

  FileDialog {
    id: picker
    title: "Choose a disk image"
    nameFilters: ["Disk images (*.iso *.img)", "All files (*)"]
    onAccepted: ui.isoPath = Isos.adopt(selectedFile)
  }

  Process { id: ejector }

  Item {
    anchors.fill: parent
    focus: true

    Keys.onEscapePressed: {
      if (ui.confirming) ui.confirming = false
      else if (Flasher.state === "done" || Flasher.state === "failed") Flasher.reset()
      else if (!Flasher.busy) ui.closeRequested()
    }

    // Tab is swallowed by Qt's focus traversal before Keys.onPressed sees it.
    Keys.onTabPressed: if (!Flasher.busy && !ui.confirming) ui.togglePane()
    Keys.onBacktabPressed: if (!Flasher.busy && !ui.confirming) ui.togglePane()

    Keys.onPressed: event => {
      if (Flasher.busy) return

      if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
        if (Flasher.state === "done" || Flasher.state === "failed") Flasher.reset()
        else if (ui.confirming) {
          ui.confirming = false
          Flasher.start(ui.iso.path, ui.drive.path, ui.verifyAfterWrite)
        } else if (ui.ready) ui.confirming = true
        event.accepted = true
        return
      }

      if (ui.confirming) return

      switch (event.key) {
      case Qt.Key_Down:
      case Qt.Key_J:
        ui.move(1); event.accepted = true; break
      case Qt.Key_Up:
      case Qt.Key_K:
        ui.move(-1); event.accepted = true; break
      case Qt.Key_Right:
      case Qt.Key_Left:
      case Qt.Key_H:
      case Qt.Key_L:
        ui.togglePane(); event.accepted = true; break
      case Qt.Key_V:
        ui.verifyAfterWrite = !ui.verifyAfterWrite; event.accepted = true; break
      case Qt.Key_R:
        Isos.refresh(); Drives.refresh(); event.accepted = true; break
      }
    }

    // ------------------------------------------------------------ main
    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 22
      spacing: 18
      enabled: !ui.overlayOpen
      opacity: ui.overlayOpen ? 0.25 : 1

      Behavior on opacity { NumberAnimation { duration: 140 } }

      RowLayout {
        Layout.fillWidth: true
        spacing: 12

        ColumnLayout {
          spacing: 3
          Text {
            text: "Flash a bootable USB"
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontHeading
            font.bold: true
          }
          Text {
            text: "Writes a Linux ISO straight to the drive. Everything on it is erased."
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSmall
          }
        }

        Item { Layout.fillWidth: true }

        Btn {
          text: "Rescan"
          onClicked: { Isos.refresh(); Drives.refresh() }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 16

        // ------------------------------------------------- ISO column
        Card {
          Layout.fillWidth: true
          Layout.fillHeight: true
          Layout.preferredWidth: 1
          title: "1 · Disk image"
          hint: Isos.images.length + " found"
          focused: ui.pane === "iso"

          ColumnLayout {
            anchors.fill: parent
            spacing: 10

            ListView {
              id: isoList
              Layout.fillWidth: true
              Layout.fillHeight: true
              clip: true
              spacing: 4
              model: Isos.images
              currentIndex: ui.indexOfPath(Isos.images, ui.isoPath)
              onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)

              delegate: SelectRow {
                required property var modelData
                width: isoList.width
                primary: modelData.name
                secondary: modelData.dir
                badge: modelData.sizeText
                selected: ui.isoPath === modelData.path
                onClicked: {
                  ui.isoPath = modelData.path
                  ui.pane = "iso"
                }
              }

              Text {
                anchors.centerIn: parent
                width: parent.width - 24
                visible: Isos.scanned && Isos.images.length === 0
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: "No .iso or .img files in Downloads, Desktop, Documents or ISOs.\nUse Browse to point at one."
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSmall
              }
            }

            Btn {
              Layout.fillWidth: true
              text: "Browse…"
              onClicked: picker.open()
            }
          }
        }

        // ----------------------------------------------- drive column
        Card {
          Layout.fillWidth: true
          Layout.fillHeight: true
          Layout.preferredWidth: 1
          title: "2 · Target drive"
          hint: ui.showAllDisks ? "every disk" : "removable only"
          focused: ui.pane === "drive"

          ColumnLayout {
            anchors.fill: parent
            spacing: 10

            ListView {
              id: driveList
              Layout.fillWidth: true
              Layout.fillHeight: true
              clip: true
              spacing: 4
              model: ui.driveList
              currentIndex: ui.indexOfPath(ui.driveList, ui.drive ? ui.drive.path : "")
              onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)

              delegate: SelectRow {
                required property var modelData
                width: driveList.width
                primary: modelData.label
                secondary: modelData.isSystem
                  ? modelData.path + " · in use by this system"
                  : modelData.path
                    + (modelData.transport ? " · " + modelData.transport : "")
                    + (modelData.removable ? "" : " · internal disk")
                    + (modelData.mounts.length ? " · mounted at " + modelData.mounts.join(", ") : "")
                badge: modelData.sizeText
                warn: modelData.isSystem || !modelData.removable
                selected: !!ui.drive && ui.drive.path === modelData.path
                opacity: modelData.isSystem ? 0.5 : 1
                onClicked: {
                  if (modelData.isSystem) return
                  ui.drive = modelData
                  ui.pane = "drive"
                }
              }

              Text {
                anchors.centerIn: parent
                width: parent.width - 24
                visible: Drives.scanned && driveList.count === 0
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: "No removable drive detected.\nPlug in the USB stick — this list updates itself."
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSmall
              }
            }

            Toggle {
              text: "Show internal disks too"
              tone: Theme.warning
              checked: ui.showAllDisks
              onToggled: value => {
                ui.showAllDisks = value
                if (!value && ui.drive && !ui.drive.removable) ui.drive = null
              }
            }
          }
        }
      }

      // ------------------------------------------------------- footer
      RowLayout {
        Layout.fillWidth: true
        spacing: 16

        ColumnLayout {
          spacing: 4

          Toggle {
            text: "Verify the drive after writing"
            checked: ui.verifyAfterWrite
            onToggled: value => ui.verifyAfterWrite = value
          }

          Text {
            text: "↑↓ choose · tab switch column · v verify · r rescan · enter flash"
            color: Theme.dim(Theme.foreground, 0.4)
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSmall
          }
        }

        Item { Layout.fillWidth: true }

        Text {
          Layout.maximumWidth: 360
          horizontalAlignment: Text.AlignRight
          wrapMode: Text.WordWrap
          color: ui.tooSmall ? Theme.danger : Theme.muted
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSmall
          text: ui.tooSmall
            ? "That drive is smaller than the image."
            : !ui.iso ? "Pick a disk image to continue."
            : !ui.drive ? "Pick the drive to write it to."
            : ui.iso.name + " → " + ui.drive.path
        }

        Btn {
          text: "Flash"
          primary: true
          enabled: ui.ready
          implicitWidth: 140
          implicitHeight: 40
          onClicked: ui.confirming = true
        }
      }
    }

    // --------------------------------------------------------- scrim
    Rectangle {
      anchors.fill: parent
      visible: ui.overlayOpen
      color: Theme.dim(Theme.background, 0.8)

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
      }
    }

    // ------------------------------------------------------- confirm
    Rectangle {
      anchors.centerIn: parent
      visible: ui.confirming
      width: 520
      height: confirmBody.implicitHeight + 44
      radius: Theme.cornerRadius
      border.width: 1
      border.color: Theme.danger

      ColumnLayout {
        id: confirmBody
        anchors.centerIn: parent
        width: parent.width - 44
        spacing: 14

        Text {
          Layout.fillWidth: true
          text: "Erase " + (ui.drive ? ui.drive.label : "") + "?"
          color: Theme.danger
          wrapMode: Text.WordWrap
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontHeading
          font.bold: true
        }

        Text {
          Layout.fillWidth: true
          wrapMode: Text.WordWrap
          color: Theme.foreground
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontBody
          text: ui.drive && ui.iso
            ? "Every partition and file on " + ui.drive.path + " (" + ui.drive.sizeText
              + ") is destroyed and replaced with " + ui.iso.name + "."
              + (ui.drive.mounts.length ? "\n\nIt is mounted at " + ui.drive.mounts.join(", ") + " and will be unmounted first." : "")
              + (ui.drive.removable ? "" : "\n\nThis is an internal disk, not a removable drive.")
            : ""
        }

        Text {
          Layout.fillWidth: true
          text: "You will be asked for your password."
          color: Theme.muted
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSmall
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: 10

          Item { Layout.fillWidth: true }

          Btn {
            text: "Cancel"
            onClicked: ui.confirming = false
          }

          Btn {
            text: "Erase and flash"
            primary: true
            tone: Theme.danger
            onClicked: {
              ui.confirming = false
              Flasher.start(ui.iso.path, ui.drive.path, ui.verifyAfterWrite)
            }
          }
        }
      }
    }

    // ------------------------------------------------------ progress
    Rectangle {
      anchors.centerIn: parent
      visible: Flasher.busy
      width: 560
      height: progressBody.implicitHeight + 44
      radius: Theme.cornerRadius
      border.width: 1
      border.color: Theme.dim(Theme.accent, 0.6)

      ColumnLayout {
        id: progressBody
        anchors.centerIn: parent
        width: parent.width - 44
        spacing: 14

        Text {
          Layout.fillWidth: true
          text: Flasher.stageLabel + "…"
          color: Theme.foreground
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontTitle
          font.bold: true
        }

        Text {
          Layout.fillWidth: true
          elide: Text.ElideMiddle
          text: Flasher.isoPath.split("/").pop() + " → " + Flasher.devicePath
          color: Theme.muted
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSmall
        }

        ProgressTrack {
          Layout.fillWidth: true
          value: Flasher.progress
        }

        RowLayout {
          Layout.fillWidth: true

          Text {
            text: Math.round(Flasher.progress * 100) + "%  ·  "
              + Drives.humanSize(Flasher.stageBytes) + " of " + Drives.humanSize(Flasher.totalBytes)
              + (Flasher.verify ? "  ·  pass " + Flasher.pass + " of 3" : "")
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSmall
          }

          Item { Layout.fillWidth: true }

          Text {
            text: Flasher.speed > 0
              ? Drives.humanSize(Flasher.speed) + "/s  ·  " + ui.humanTime(Flasher.eta) + " left"
              : "measuring…"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSmall
          }
        }

        Text {
          Layout.fillWidth: true
          wrapMode: Text.WordWrap
          text: "Do not unplug the drive."
          color: Theme.warning
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSmall
        }

        RowLayout {
          Layout.fillWidth: true
          Item { Layout.fillWidth: true }
          Btn {
            text: Flasher.cancelling ? "Stopping…" : "Cancel"
            enabled: !Flasher.cancelling
            onClicked: Flasher.cancel()
          }
        }
      }
    }

    // -------------------------------------------------------- result
    Rectangle {
      anchors.centerIn: parent
      visible: Flasher.state === "done" || Flasher.state === "failed"
      width: 560
      height: resultBody.implicitHeight + 44
      radius: Theme.cornerRadius
      border.width: 1
      border.color: Flasher.state === "done" ? Theme.success : Theme.danger

      ColumnLayout {
        id: resultBody
        anchors.centerIn: parent
        width: parent.width - 44
        spacing: 14

        Text {
          Layout.fillWidth: true
          wrapMode: Text.WordWrap
          text: Flasher.state === "done" ? "Drive is ready to boot" : "Flash failed"
          color: Flasher.state === "done" ? Theme.success : Theme.danger
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontHeading
          font.bold: true
        }

        Text {
          Layout.fillWidth: true
          wrapMode: Text.WordWrap
          color: Theme.foreground
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontBody
          text: Flasher.state === "done"
            ? Flasher.isoPath.split("/").pop() + " was written to " + Flasher.devicePath + "."
              + (Flasher.verified ? " The drive's checksum matches the image."
                                  : " It was not verified — enable verification if you want that check.")
            : Flasher.error
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: 10

          Item { Layout.fillWidth: true }

          Btn {
            text: "Eject drive"
            visible: Flasher.state === "done"
            onClicked: {
              ejector.command = ["udisksctl", "power-off", "-b", Flasher.devicePath]
              ejector.running = true
              Flasher.reset()
            }
          }

          Btn {
            text: Flasher.state === "done" ? "Done" : "Back"
            primary: true
            onClicked: Flasher.reset()
          }
        }
      }
    }
  }
}
