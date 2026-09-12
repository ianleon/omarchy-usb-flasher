import QtQuick
import Quickshell
import "."

// Standalone entry point: `qs -p <this directory>`. The same interface is
// available inside omarchy-shell through Overlay.qml.
ShellRoot {
  FloatingWindow {
    id: win

    title: "USB Flasher"
    color: Theme.background
    implicitWidth: 960
    implicitHeight: 680
    minimumSize: Qt.size(760, 560)
    visible: true

    // Quickshell has no quit API and ignores Qt.quit(), so the app ends by
    // signalling its own process.
    function quitApp() {
      Quickshell.execDetached(["/usr/bin/kill", "-TERM", String(Quickshell.processId)])
    }

    onClosed: quitApp()

    FlasherUi {
      anchors.fill: parent
      focus: true
      active: true
      onCloseRequested: win.quitApp()
    }
  }
}
