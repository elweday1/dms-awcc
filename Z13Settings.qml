import QtQuick
import QtQuick.Controls

import ":/qs/modules/common"

Column {
    spacing: 12
    
    Label { text: "Z13 Control Settings" }

    TextField {
        text: root.z13ctlBinary
        placeholderText: "Binary path (z13ctl)"
        onTextChanged: root.z13ctlBinary = text
    }

    Row {
        Label { text: "Refresh:"; anchors.verticalCenter: parent.verticalCenter }
        SpinBox {
            value: root.refreshInterval
            from: 1
            to: 60
            onValueChanged: root.refreshInterval = value
        }
        Label { text: "s"; anchors.verticalCenter: parent.verticalCenter }
    }
}