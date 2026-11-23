pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.modules.compat

/**
 * Bottom-right stack of small status toasts (see services/Toasts.qml).
 * Idea from caelestia-shell's utilities/toasts.
 */
Scope {
    id: root
    property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

    Loader {
        id: toastLoader
        // Keep the window a moment after the last toast so the exit animation can play
        active: Toasts.toasts.length > 0 || hideDelay.running

        Timer {
            id: hideDelay
            interval: 400
        }
        Connections {
            target: Toasts
            function onToastsChanged() {
                if (Toasts.toasts.length === 0) hideDelay.restart();
            }
        }

        sourceComponent: PanelWindow {
            id: toastWindow
            screen: root.focusedScreen
            color: "transparent"
            WlrLayershell.namespace: "quickshell:toasts"
            WlrLayershell.layer: WlrLayer.Overlay
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0

            anchors {
                bottom: true
                right: true
            }
            margins {
                bottom: Config.options.bar.bottom ? Appearance.sizes.barHeight : 0
            }

            implicitWidth: 360
            implicitHeight: toastColumn.implicitHeight + Appearance.sizes.elevationMargin * 2
            mask: Region {
                item: toastColumn
            }

            Column {
                id: toastColumn
                anchors {
                    bottom: parent.bottom
                    right: parent.right
                    margins: Appearance.sizes.elevationMargin
                }
                spacing: 6

                add: Transition {
                    NumberAnimation {
                        properties: "opacity"
                        from: 0
                        to: 1
                        duration: Appearance.animation.elementMoveFast.duration
                    }
                    NumberAnimation {
                        properties: "x"
                        from: 60
                        duration: Appearance.animation.elementMoveEnter.duration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
                    }
                }
                move: Transition {
                    NumberAnimation {
                        properties: "y"
                        duration: Appearance.animation.elementMove.duration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                    }
                }

                Repeater {
                    model: ScriptModel {
                        values: Toasts.toasts
                        objectProp: "id"
                    }
                    delegate: ToastItem {}
                }
            }
        }
    }

    component ToastItem: Item {
        id: toastItem
        required property var modelData
        anchors.right: parent?.right
        implicitWidth: toastBackground.implicitWidth
        implicitHeight: toastBackground.implicitHeight

        StyledRectangularShadow {
            target: toastBackground
        }
        Rectangle {
            id: toastBackground
            property real padding: 10
            implicitWidth: Math.min(340, toastRow.implicitWidth + padding * 2 + 4)
            implicitHeight: toastRow.implicitHeight + padding * 2
            radius: Appearance.rounding.full
            color: Appearance.colors.colLayer0
            border.width: 1
            border.color: Appearance.colors.colLayer0Border

            RowLayout {
                id: toastRow
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    leftMargin: toastBackground.padding
                    rightMargin: toastBackground.padding + 4
                }
                spacing: 8

                Rectangle {
                    implicitWidth: 28
                    implicitHeight: 28
                    radius: Appearance.rounding.full
                    color: Appearance.colors.colPrimaryContainer
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: toastItem.modelData.icon
                        iconSize: Appearance.font.pixelSize.large
                        color: Appearance.colors.colOnPrimaryContainer
                    }
                }
                StyledText {
                    Layout.fillWidth: true
                    text: toastItem.modelData.text
                    elide: Text.ElideRight
                    color: Appearance.colors.colOnLayer0
                    font.pixelSize: Appearance.font.pixelSize.normal
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: Toasts.dismiss(toastItem.modelData.id)
            }
        }
    }
}
