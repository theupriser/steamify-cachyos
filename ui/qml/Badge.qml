// "Update" (a newer version of it will be applied) or "New" (a default
// option added since the last run), after an item's name.
import QtQuick

Chip {
    property bool update: false
    property bool isNew: false
    visible: update || isNew
    height: 20
    text: update ? "Update" : "New"
    fg: update ? Theme.warn : Theme.good
    bgc: update ? Theme.warnBg : Theme.goodBg
}
