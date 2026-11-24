pragma ComponentBehavior: Bound

import QtQuick
import Qt5Compat.GraphicalEffects
import qs
import qs.services
import qs.modules.common

// Audio bars along the bottom of the wallpaper (idea from caelestia-shell's
// background visualiser): two groups of bars, bass toward the middle, filled with
// a primary -> inverse primary gradient. Data comes from services/AudioVisualizer.
Item {
    id: root

    required property string screenName
    required property bool shouldShow

    readonly property var config: Config.options.background.visualizer
    readonly property int barCount: 40
    readonly property real maxBarHeight: height
    readonly property real sideWidth: width * 0.4
    readonly property real slotWidth: sideWidth / barCount
    readonly property real barSpacing: Math.min(6, slotWidth * 0.3)
    readonly property real barWidth: Math.max(1, slotWidth - barSpacing)
    readonly property bool hasData: AudioVisualizer.values.length > 0

    property real offset: shouldShow ? 0 : height * 0.5
    opacity: shouldShow && hasData ? 1 : 0
    visible: opacity > 0

    onShouldShowChanged: AudioVisualizer.setActive(root.screenName, root.shouldShow)
    Component.onCompleted: AudioVisualizer.setActive(root.screenName, root.shouldShow)
    Component.onDestruction: AudioVisualizer.setActive(root.screenName, false)

    Behavior on opacity {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }
    Behavior on offset {
        animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
    }

    // Bar shapes, used only as the mask for the gradient below
    Item {
        id: bars
        anchors.fill: parent
        anchors.topMargin: root.offset
        anchors.bottomMargin: -root.offset
        visible: false
        layer.enabled: root.visible

        Repeater {
            model: root.barCount * 2
            delegate: Rectangle {
                id: bar
                required property int index
                readonly property bool rightSide: index >= root.barCount
                readonly property int slot: rightSide ? index - root.barCount : index
                // Left group runs right-to-left so bass sits next to the middle gap
                readonly property int valueIndex: rightSide ? slot : root.barCount - slot - 1
                readonly property real value: Math.max(0, Math.min(1, AudioVisualizer.values[valueIndex] ?? 0))

                x: (rightSide ? root.width * 0.6 : 0) + slot * root.slotWidth + root.barSpacing / 2
                anchors.bottom: parent.bottom
                width: root.barWidth
                height: value * root.maxBarHeight
                radius: Math.min(Appearance.rounding.small, width / 2)
                color: "white"

                Behavior on height {
                    NumberAnimation {
                        duration: 90
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }

    Rectangle {
        id: gradientFill
        anchors.fill: bars
        visible: false
        layer.enabled: root.visible
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.alpha(Appearance.m3colors.m3primary, root.config?.opacity ?? 0.7)
            }
            GradientStop {
                position: 1
                color: Qt.alpha(Appearance.m3colors.m3inversePrimary, root.config?.opacity ?? 0.7)
            }
        }
    }

    OpacityMask {
        anchors.fill: bars
        source: gradientFill
        maskSource: bars
    }
}
