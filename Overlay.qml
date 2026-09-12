import QtQuick
import Quickshell
import Quickshell.Wayland
import "."

// Omarchy shell overlay entry point. Summoned with
//   omarchy-shell shell toggle io.github.ianleon.usb-flasher '{}'
// The shell injects `shell` and `manifest`; `omarchyPath` is declared for the
// same host-injection contract the first-party overlays use.
Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  property bool opened: false

  function open(payloadJson) {
    root.opened = true
    Qt.callLater(function () { flasher.forceActiveFocus() })
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    // A write in progress outlives the overlay, but hiding it mid-flash loses
    // the only progress indicator the user has, so refuse.
    if (Flasher.busy) return
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "io.github.ianleon.usb-flasher")
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  PanelWindow {
    id: panel

    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-usb-flasher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: Theme.dim(Theme.background, 0.6)

      MouseArea {
        anchors.fill: parent
        onClicked: root.dismiss()
      }
    }

    Rectangle {
      anchors.centerIn: parent
      width: Math.min(1040, panel.width - 96)
      height: Math.min(740, panel.height - 96)
      color: Theme.background
      radius: Theme.cornerRadius
      border.width: 1
      border.color: Theme.dim(Theme.foreground, 0.25)

      // Swallow clicks so they do not reach the dismissing scrim behind.
      MouseArea { anchors.fill: parent }

      FlasherUi {
        id: flasher
        anchors.fill: parent
        anchors.margins: 6
        focus: true
        active: root.opened
        onCloseRequested: root.dismiss()
      }
    }
  }
}
