import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    layerNamespacePlugin: "z13-control"

    property string z13ctlBinary: pluginData.z13ctlBinary || "z13ctl"
    property int refreshInterval: pluginData.refreshInterval || 10
    
    readonly property string commandNamespace: "z13." + Math.floor(Math.random() * 1000000000)

    property string currentMode: "..."
    property int temperature: 0
    property string fanSpeed: "..."
    property string tdpLimit: "..."
    property int batteryLimit: 80
    property int kbBrightness: pluginData.kbBrightness !== undefined ? pluginData.kbBrightness : 100
    property string kbEffect: pluginData.kbEffect || "static"
    property string kbColor: pluginData.kbColor || "ff00ff"

    property var supportedFeatures: []
    property var supportedProfiles: ["quiet", "balanced", "performance"]
    property var supportedEffects: ["static", "breathe", "cycle", "rainbow", "strobe", "wave"]

    property bool hasThermal: true
    property bool hasLighting: true
    property bool hasBatteryLimit: true
    property bool hasTDPLimit: true

    readonly property var allProfiles: [
        { cmd: "quiet", label: "Quiet", icon: "bedtime" },
        { cmd: "balance", label: "Balanced", icon: "balance" },
        { cmd: "performance", label: "Performance", icon: "rocket_launch" }
    ]

    readonly property var allKbEffects: [
        { cmd: "static", label: "Static", needsColor: true },
        { cmd: "breathe", label: "Breathe", needsColor: true },
        { cmd: "cycle", label: "Cycle", needsColor: false },
        { cmd: "rainbow", label: "Rainbow", needsColor: false },
        { cmd: "strobe", label: "Strobe", needsColor: false },
        { cmd: "wave", label: "Wave", needsColor: true }
    ]

    property var profiles: allProfiles
    property var kbEffects: allKbEffects

    function runZ13ctl(id, args, callback) {
        Proc.runCommand(root.commandNamespace + "." + id, [root.z13ctlBinary].concat(args), callback, 500)
    }

    function parseStatus() {
        runZ13ctl("status", ["status"], (stdout, exitCode) => {
            if (exitCode !== 0) return
            var lines = stdout.split("\n")
            var section = ""
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i].trim()
                if (!line) continue
                if (line.toLowerCase().includes("profile")) {
                    var parts = line.split(":")
                    if (parts.length > 1) root.currentMode = parts[1].trim()
                } else if (line.toLowerCase().includes("temp") || line.includes("°C")) {
                    var parts = line.split(/[:°C]/)
                    if (parts.length > 1) root.temperature = parseInt(parts[1].trim()) || 0
                } else if (line.toLowerCase().includes("fan")) {
                    var parts = line.split(":")
                    if (parts.length > 1) root.fanSpeed = parts[1].trim()
                } else if (line.toLowerCase().includes("tdp")) {
                    var parts = line.split(":")
                    if (parts.length > 1) root.tdpLimit = parts[1].trim()
                }
            }
        })
    }

    function queryAll() {
        runZ13ctl("qm", ["profile"], (stdout, exitCode) => {
            if (exitCode === 0) {
                var trimmed = stdout.trim()
                root.currentMode = trimmed.length > 0 ? trimmed : "balanced"
            }
        })
        runZ13ctl("battery", ["batterylimit"], (stdout, exitCode) => {
            if (exitCode === 0) {
                var val = parseInt(stdout.trim()) || 80
                if (val > 0) root.batteryLimit = val
            }
        })
        parseStatus()
    }

    Component.onCompleted: {
        queryAll()
    }

    Timer {
        interval: root.refreshInterval * 1000
        running: true
        repeat: true
        onTriggered: {
            root.runZ13ctl("poll", ["status"], (stdout, exitCode) => {
                if (exitCode === 0) {
                    var lines = stdout.split("\n")
                    for (var i = 0; i < lines.length; i++) {
                        var line = lines[i].trim().toLowerCase()
                        if (line.includes("profile")) {
                            var parts = line.split(":")
                            if (parts.length > 1) root.currentMode = parts[1].trim()
                        }
                    }
                }
            })
        }
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS
            DankIcon {
                name: "bolt"
                size: Theme.iconSize - 4
                color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter
            }
            StyledText {
                text: root.currentMode
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        DankIcon {
            name: "bolt"
            size: 24
            color: Theme.primary
        }
    }

    component ColorPicker: Item {
        id: picker
        height: 120

        property real hue: 0
        property real saturation: 1.0
        property real value: 1.0
        property string hexColor: hsvToHex(hue, saturation, value)

        signal colorSelected(string hex)

        function hsvToHex(h, s, v) {
            var r, g, b
            var i = Math.floor(h / 60) % 6
            var f = (h / 60) - Math.floor(h / 60)
            var p = v * (1 - s)
            var q = v * (1 - f * s)
            var t = v * (1 - (1 - f) * s)
            switch (i) {
                case 0: r = v; g = t; b = p; break
                case 1: r = q; g = v; b = p; break
                case 2: r = p; g = v; b = t; break
                case 3: r = p; g = q; b = v; break
                case 4: r = t; g = p; b = v; break
                default: r = v; g = p; b = q; break
            }
            function toH(c) {
                var x = Math.round(c * 255).toString(16)
                return x.length === 1 ? "0" + x : x
            }
            return toH(r) + toH(g) + toH(b)
        }

        function hexToHsv(hex) {
            hex = hex.replace(/^#/, "")
            if (hex.length !== 6) return null
            var r = parseInt(hex.substr(0, 2), 16) / 255
            var g = parseInt(hex.substr(2, 2), 16) / 255
            var b = parseInt(hex.substr(4, 2), 16) / 255
            var max = Math.max(r, g, b), min = Math.min(r, g, b), d = max - min
            var h = 0, s = max === 0 ? 0 : d / max, v = max
            if (d !== 0) {
                if (max === r) h = 60 * (((g - b) / d) % 6)
                else if (max === g) h = 60 * ((b - r) / d + 2)
                else h = 60 * ((r - g) / d + 4)
            }
            return { h: h < 0 ? h + 360 : h, s: s, v: v }
        }

        Timer {
            id: colorDebounce
            interval: 300
            onTriggered: picker.colorSelected(picker.hexColor)
        }

        onHueChanged: { svCanvas.requestPaint(); colorDebounce.restart() }
        onSaturationChanged: { svCanvas.requestPaint(); colorDebounce.restart() }
        onValueChanged: { svCanvas.requestPaint(); colorDebounce.restart() }

        Column {
            id: pickerCol
            width: parent.width
            spacing: Theme.spacingS

            Item {
                width: parent.width
                height: 20

                Rectangle {
                    anchors.fill: parent
                    radius: 4
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.000; color: "#ff0000" }
                        GradientStop { position: 0.167; color: "#ffff00" }
                        GradientStop { position: 0.333; color: "#00ff00" }
                        GradientStop { position: 0.500; color: "#00ffff" }
                        GradientStop { position: 0.667; color: "#0000ff" }
                        GradientStop { position: 0.833; color: "#ff00ff" }
                        GradientStop { position: 1.000; color: "#ff0000" }
                    }
                }

                Rectangle {
                    x: Math.max(0, Math.min(parent.width - width, (picker.hue / 360) * parent.width - width / 2))
                    width: 6
                    height: parent.height
                    radius: 3
                    color: "white"
                    border.width: 1
                    border.color: "#00000060"
                }

                MouseArea {
                    anchors.fill: parent
                    preventStealing: true
                    onPositionChanged: (m) => picker.hue = Math.max(0, Math.min(359.9, m.x / parent.width * 360))
                    onClicked: (m) => picker.hue = Math.max(0, Math.min(359.9, m.x / parent.width * 360))
                }
            }

            Canvas {
                id: svCanvas
                width: parent.width
                height: 90
                clip: true

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)

                    var hueColor = Qt.hsva(picker.hue / 360, 1, 1, 1)

                    var gH = ctx.createLinearGradient(0, 0, width, 0)
                    gH.addColorStop(0, "white")
                    gH.addColorStop(1, hueColor.toString())
                    ctx.fillStyle = gH
                    ctx.fillRect(0, 0, width, height)

                    var gV = ctx.createLinearGradient(0, 0, 0, height)
                    gV.addColorStop(0, "rgba(0,0,0,0)")
                    gV.addColorStop(1, "rgba(0,0,0,1)")
                    ctx.fillStyle = gV
                    ctx.fillRect(0, 0, width, height)

                    var cx = picker.saturation * width
                    var cy = (1 - picker.value) * height
                    ctx.beginPath()
                    ctx.arc(cx, cy, 5, 0, Math.PI * 2)
                    ctx.strokeStyle = picker.value > 0.4 ? "black" : "white"
                    ctx.lineWidth = 2
                    ctx.stroke()
                    ctx.beginPath()
                    ctx.arc(cx, cy, 7, 0, Math.PI * 2)
                    ctx.strokeStyle = "white"
                    ctx.lineWidth = 1.5
                    ctx.stroke()
                }

                MouseArea {
                    anchors.fill: parent
                    preventStealing: true
                    onPositionChanged: (m) => {
                        picker.saturation = Math.max(0, Math.min(1, m.x / parent.width))
                        picker.value = Math.max(0, Math.min(1, 1 - m.y / parent.height))
                    }
                    onClicked: (m) => {
                        picker.saturation = Math.max(0, Math.min(1, m.x / parent.width))
                        picker.value = Math.max(0, Math.min(1, 1 - m.y / parent.height))
                    }
                }
            }
        }
    }

    popoutContent: Component {
        Flickable {
            implicitWidth: root.popoutWidth
            implicitHeight: root.popoutHeight
            contentWidth: width
            contentHeight: mainCol.height + Theme.spacingM * 2
            clip: true

            Column {
                id: mainCol
                x: Theme.spacingM
                y: Theme.spacingM
                width: parent.width - Theme.spacingM * 2
                spacing: Theme.spacingM

                Rectangle {
                    width: parent.width
                    height: 56
                    radius: Theme.cornerRadius
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) }
                        GradientStop { position: 1.0; color: Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.08) }
                    }
                    border.width: 1
                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)

                    Row {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: Theme.spacingM }
                        spacing: Theme.spacingM

                        Rectangle {
                            width: 36; height: 36; radius: 10
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
                            anchors.verticalCenter: parent.verticalCenter
                            DankIcon { name: "bolt"; size: 20; color: Theme.primary; anchors.centerIn: parent }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3
                            StyledText { text: "Z13 Control"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Bold }
                            Rectangle {
                                height: 18
                                width: headerModeLabel.implicitWidth + Theme.spacingS * 2
                                radius: 9
                                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
                                border.width: 1
                                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35)
                                StyledText {
                                    id: headerModeLabel
                                    anchors.centerIn: parent
                                    text: root.currentMode
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Bold
                                    color: Theme.primary
                                }
                            }
                        }
                    }
                }

                Column {
                    id: thermalSection
                    width: parent.width
                    spacing: Theme.spacingS
                    visible: root.hasThermal

                    Row {
                        spacing: Theme.spacingS
                        Rectangle { width: 4; height: 20; radius: 2; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        DankIcon { name: "bolt"; size: 16; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText {
                            text: "THERMAL MODE"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Column {
                        id: modesColumn
                        width: parent.width
                        spacing: Theme.spacingXS

                        readonly property int buttonWidth: Math.floor((width - 3 * Theme.spacingXS) / 4)

                        Repeater {
                            model: Math.ceil(root.profiles.length / 4)

                            Row {
                                readonly property var rowModes: root.profiles.slice(index * 4, Math.min((index + 1) * 4, root.profiles.length))
                                spacing: Theme.spacingXS
                                anchors.horizontalCenter: parent.horizontalCenter

                                Repeater {
                                    model: rowModes

                                    Rectangle {
                                        width: modesColumn.buttonWidth
                                        height: 50
                                        radius: Theme.cornerRadius

                                        readonly property bool active: root.currentMode.toLowerCase() === modelData.label.toLowerCase() || root.currentMode.toLowerCase().includes(modelData.cmd.toLowerCase())

                                        scale: modeArea.pressed ? 0.95 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 100 } }

                                        color: active ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
                                                      : modeArea.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer
                                        border.width: active ? 1 : 0
                                        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4)

                                        Column {
                                            anchors.centerIn: parent
                                            spacing: 2

                                            DankIcon {
                                                name: modelData.icon
                                                size: 14
                                                color: parent.parent.active ? Theme.primary : Theme.surfaceVariantText
                                                anchors.horizontalCenter: parent.horizontalCenter
                                            }

                                            StyledText {
                                                text: modelData.label
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: parent.parent.active ? Theme.primary : Theme.surfaceText
                                                font.weight: parent.parent.active ? Font.Bold : Font.Normal
                                                elide: Text.ElideRight
                                                width: modesColumn.buttonWidth - 8
                                                horizontalAlignment: Text.AlignHCenter
                                            }
                                        }

                                        MouseArea {
                                            id: modeArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                var cmd = modelData.cmd
                                                var label = modelData.label
                                                root.runZ13ctl("setProfile", ["profile", "--set", cmd], (stdout, exitCode) => {
                                                    if (exitCode === 0) root.currentMode = label
                                                })
                                            }
                                        }

                                        DankRipple {
                                            anchors.fill: parent
                                            cornerRadius: Theme.cornerRadius
                                            rippleColor: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width; height: 1
                    color: Theme.outline; opacity: 0.3
                    visible: root.hasThermal && root.hasBatteryLimit
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingS
                    visible: root.hasBatteryLimit

                    Row {
                        spacing: Theme.spacingS
                        Rectangle { width: 4; height: 20; radius: 2; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        DankIcon { name: "battery_charging_full"; size: 16; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText {
                            text: "BATTERY LIMIT"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledSlider {
                            id: batterySlider
                            width: parent.width - 48 - Theme.spacingS * 2
                            from: 50; to: 100; stepSize: 5
                            value: root.batteryLimit
                            anchors.verticalCenter: parent.verticalCenter
                            onPressedChanged: {
                                if (!pressed) {
                                    root.batteryLimit = Math.round(value)
                                    pluginService?.savePluginData("z13-control", "batteryLimit", root.batteryLimit)
                                    root.runZ13ctl("batterylimit", ["batterylimit", "--set", root.batteryLimit.toString()], () => {})
                                }
                            }
                        }

                        Rectangle {
                            height: 18
                            width: Math.max(42, batteryVal.implicitWidth + Theme.spacingS * 2)
                            radius: 9
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                            anchors.verticalCenter: parent.verticalCenter
                            StyledText {
                                id: batteryVal
                                anchors.centerIn: parent
                                text: Math.round(batterySlider.value) + "%"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Bold
                                color: Theme.primary
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width; height: 1
                    color: Theme.outline; opacity: 0.3
                    visible: root.hasBatteryLimit && root.hasLighting
                }

                Column {
                    id: kbSection
                    width: parent.width
                    spacing: Theme.spacingS
                    visible: root.hasLighting

                    property bool needsColor: ["static", "breathe", "wave"].indexOf(root.kbEffect) >= 0

                    Row {
                        spacing: Theme.spacingS
                        Rectangle { width: 4; height: 20; radius: 2; color: Theme.secondary; anchors.verticalCenter: parent.verticalCenter }
                        DankIcon { name: "keyboard"; size: 16; color: Theme.secondary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText {
                            text: "KEYBOARD"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingS

                        DankIcon {
                            name: "brightness_high"
                            size: 18
                            color: Theme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledSlider {
                            id: kbBrightnessSlider
                            width: parent.width - 18 - 40 - Theme.spacingS * 2
                            from: 0; to: 100; stepSize: 1
                            value: root.kbBrightness
                            anchors.verticalCenter: parent.verticalCenter
                            onPressedChanged: {
                                if (!pressed) {
                                    root.kbBrightness = Math.round(value)
                                    pluginService?.savePluginData("z13-control", "kbBrightness", root.kbBrightness)
                                    root.runZ13ctl("brightness", ["brightness", Math.round(value).toString()], () => {})
                                }
                            }
                        }

                        StyledText {
                            text: Math.round(kbBrightnessSlider.value) + "%"
                            width: 40
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Flow {
                        id: kbEffectsFlow
                        width: parent.width
                        spacing: Theme.spacingXS

                        Repeater {
                            model: root.kbEffects

                            Rectangle {
                                height: 28
                                width: kbEffLabel.implicitWidth + Theme.spacingM * 2
                                radius: Theme.cornerRadius

                                scale: kbEffArea.pressed ? 0.95 : 1.0
                                Behavior on scale { NumberAnimation { duration: 100 } }

                                color: root.kbEffect === modelData.cmd
                                    ? Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.18)
                                    : kbEffArea.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer
                                border.width: root.kbEffect === modelData.cmd ? 1 : 0
                                border.color: Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.4)

                                StyledText {
                                    id: kbEffLabel
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: root.kbEffect === modelData.cmd ? Theme.secondary : Theme.surfaceText
                                }

                                MouseArea {
                                    id: kbEffArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var cmd = modelData.cmd
                                        var needsCol = modelData.needsColor
                                        root.kbEffect = cmd
                                        pluginService?.savePluginData("z13-control", "kbEffect", cmd)
                                        var args = ["apply", "--mode", cmd]
                                        if (needsCol) args.push("--color", root.kbColor)
                                        args.push("--brightness", root.kbBrightness.toString())
                                        root.runZ13ctl("kbEffect", args, () => {})
                                    }
                                }

                                DankRipple {
                                    anchors.fill: parent
                                    cornerRadius: Theme.cornerRadius
                                    rippleColor: Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.2)
                                }
                            }
                        }
                    }

                    ColorPicker {
                        id: kbColorPicker
                        width: parent.width
                        visible: kbSection.needsColor && root.hasLighting
                        height: kbSection.needsColor && root.hasLighting ? 120 : 0
                        clip: true

                        Component.onCompleted: {
                            var hsv = hexToHsv(root.kbColor)
                            if (hsv) { hue = hsv.h; saturation = hsv.s; value = hsv.v }
                        }

                        onColorSelected: (hex) => {
                            root.kbColor = hex
                            pluginService?.savePluginData("z13-control", "kbColor", hex)
                            var args = ["apply", "--mode", root.kbEffect, "--color", hex, "--brightness", root.kbBrightness.toString()]
                            root.runZ13ctl("kbColor", args, () => {})
                        }
                    }
                }

                Item { width: parent.width; height: Theme.spacingM }
            }
        }
    }

    popoutWidth: 420
    popoutHeight: 600
}