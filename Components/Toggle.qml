import QtQuick
import ".."

MouseArea {
  id: root

  property string text: ""
  property bool checked: false
  property color tone: Theme.accent
  signal toggled(bool value)

  implicitWidth: layout.implicitWidth
  implicitHeight: Math.max(20, layout.implicitHeight)
  hoverEnabled: true
  cursorShape: Qt.PointingHandCursor
  onClicked: {
    checked = !checked
    toggled(checked)
  }

  Row {
    id: layout
    anchors.verticalCenter: parent.verticalCenter
    spacing: 8

    Rectangle {
      width: 16
      height: 16
      anchors.verticalCenter: parent.verticalCenter
      radius: Math.min(3, Theme.cornerRadius)
      color: root.checked ? Theme.dim(root.tone, 0.85) : "transparent"
      border.width: 1
      border.color: root.checked ? root.tone : Theme.dim(Theme.foreground, root.containsMouse ? 0.7 : 0.35)

      Text {
        anchors.centerIn: parent
        text: "✓"
        visible: root.checked
        color: Theme.background
        font.family: Theme.fontFamily
        font.pixelSize: 12
        font.bold: true
      }
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: root.text
      color: root.containsMouse ? Theme.foreground : Theme.dim(Theme.foreground, 0.75)
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontBody
    }
  }
}
