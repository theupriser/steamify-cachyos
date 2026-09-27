// The bar at the bottom of a screen, for its buttons.
import QtQuick

Rectangle {
    anchors.bottom: parent.bottom; width: parent.width; height: 64; color: Theme.bar
    Rectangle { width: parent.width; height: 1; color: Theme.line }
}
