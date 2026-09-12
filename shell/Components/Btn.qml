import QtQuick
import ".."

Rectangle {
  id: root

  property string text: ""
  property bool enabled: true
  property bool primary: false
  property color tone: primary ? Theme.accent : Theme.foreground
  signal clicked

  implicitWidth: label.implicitWidth + 32
  implicitHeight: 34
  radius: Theme.cornerRadius
  opacity: enabled ? 1 : 0.35
  color: !enabled ? Theme.dim(tone, 0.04)
       : area.pressed ? Theme.dim(tone, 0.3)
       : area.containsMouse ? Theme.dim(tone, 0.18)
       : Theme.dim(tone, primary ? 0.12 : 0.05)
  border.width: 1
  border.color: Theme.dim(tone, area.containsMouse && enabled ? 0.8 : 0.35)

  Behavior on color { ColorAnimation { duration: 90 } }

  Text {
    id: label
    anchors.centerIn: parent
    text: root.text
    color: root.primary ? root.tone : Theme.foreground
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontBody
    font.bold: root.primary
  }

  MouseArea {
    id: area
    anchors.fill: parent
    enabled: root.enabled
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
