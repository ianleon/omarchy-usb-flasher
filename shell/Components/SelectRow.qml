import QtQuick
import ".."

// One selectable line in either list: bold primary text, dim secondary text,
// and a right-aligned badge (size, transport).
Rectangle {
  id: row

  property string primary: ""
  property string secondary: ""
  property string badge: ""
  property bool selected: false
  property bool warn: false
  readonly property color tone: warn ? Theme.warning : Theme.accent
  signal clicked

  height: 52
  radius: Theme.cornerRadius
  color: selected ? Theme.dim(tone, 0.16)
       : area.containsMouse ? Theme.dim(Theme.foreground, 0.07)
       : "transparent"
  border.width: 1
  border.color: selected ? Theme.dim(tone, 0.9) : "transparent"

  Behavior on color { ColorAnimation { duration: 90 } }

  Column {
    anchors.left: parent.left
    anchors.right: badgeText.left
    anchors.leftMargin: 12
    anchors.rightMargin: 10
    anchors.verticalCenter: parent.verticalCenter
    spacing: 3

    Text {
      width: parent.width
      text: row.primary
      elide: Text.ElideMiddle
      color: Theme.foreground
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontBody
      font.bold: row.selected
    }

    Text {
      width: parent.width
      text: row.secondary
      elide: Text.ElideMiddle
      visible: text.length > 0
      color: row.warn ? Theme.warning : Theme.muted
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSmall
    }
  }

  Text {
    id: badgeText
    anchors.right: parent.right
    anchors.rightMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    text: row.badge
    color: row.selected ? row.tone : Theme.dim(Theme.foreground, 0.6)
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontBody
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: row.clicked()
  }
}
