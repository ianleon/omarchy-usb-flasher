import QtQuick
import ".."

Rectangle {
  id: card

  property string title: ""
  property string hint: ""
  property bool focused: false
  default property alias content: body.data

  color: Theme.dim(Theme.surface, 0.35)
  radius: Theme.cornerRadius
  border.width: 1
  border.color: focused ? Theme.dim(Theme.accent, 0.55) : Theme.dim(Theme.foreground, 0.12)

  Behavior on border.color { ColorAnimation { duration: 120 } }

  Column {
    anchors.fill: parent
    anchors.margins: 14
    spacing: 10

    Row {
      width: parent.width
      spacing: 8

      Text {
        id: titleText
        text: card.title
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontTitle
        font.bold: true
      }

      Text {
        anchors.baseline: titleText.baseline
        text: card.hint
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSmall
      }
    }

    Item {
      id: body
      width: parent.width
      height: parent.height - y
    }
  }
}
