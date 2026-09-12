import QtQuick
import ".."

Rectangle {
  id: track

  property real value: 0
  property color tone: Theme.accent

  height: 8
  radius: height / 2
  color: Theme.dim(Theme.foreground, 0.1)

  Rectangle {
    width: Math.max(0, Math.min(1, track.value)) * parent.width
    height: parent.height
    radius: parent.radius
    color: track.tone

    Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
  }
}
