pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

/**
 * Scroll port: a small live preview of a workspace, shown under the bar while the pointer
 * rests on that workspace's button (like the tag preview of dwm-style bars).
 * The picture is rebuilt from the workspace's windows (position + live capture) on top of
 * the wallpaper, so it also works for workspaces that are not on screen.
 */
LazyLoader {
    id: root

    required property Item hoverTarget   // the workspaces widget
    required property var monitor        // compat Hyprland monitor of the bar
    property int workspaceId: -1
    property real anchorCenterX: 0       // x of the hovered button's centre, in hoverTarget coordinates
    property bool shown: false
    property real previewWidth: 340

    active: shown

    component: PanelWindow {
        id: popup
        color: "transparent"
        screen: root.hoverTarget.QsWindow.window?.screen ?? null

        readonly property var monitorData: HyprlandData.monitors.find(m => m.id === root.monitor?.id)
        readonly property real factor: root.previewWidth / (monitorData?.width ?? 1920)
        readonly property real previewHeight: (monitorData?.height ?? 1080) * factor
        readonly property var windows: HyprlandData.windowList.filter(w => w.workspace?.id === root.workspaceId)

        anchors.left: true
        anchors.top: !Config.options.bar.bottom
        anchors.bottom: Config.options.bar.bottom
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        WlrLayershell.namespace: "quickshell:popup"
        WlrLayershell.layer: WlrLayer.Overlay
        mask: Region {} // never takes the pointer, so it cannot steal the hover from the bar

        implicitWidth: frame.implicitWidth + Appearance.sizes.elevationMargin * 2
        implicitHeight: frame.implicitHeight + Appearance.sizes.elevationMargin * 2
        margins {
            left: {
                const centre = root.hoverTarget.QsWindow?.mapFromItem(root.hoverTarget, root.anchorCenterX, 0).x ?? 0;
                const wanted = centre - implicitWidth / 2;
                const max = (popup.screen?.width ?? 1920) - implicitWidth;
                return Math.max(0, Math.min(wanted, max));
            }
            top: Appearance.sizes.barHeight
            bottom: Appearance.sizes.barHeight
        }
        Behavior on margins.left {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }

        StyledRectangularShadow {
            target: frame
        }
        Rectangle {
            id: frame
            anchors.centerIn: parent
            readonly property real padding: 8
            implicitWidth: root.previewWidth + padding * 2
            implicitHeight: popup.previewHeight + label.implicitHeight + padding * 3
            color: Appearance.m3colors.m3surfaceContainer
            radius: Appearance.rounding.normal
            border.width: 1
            border.color: Appearance.colors.colLayer0Border

            StyledText {
                id: label
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: frame.padding
                }
                elide: Text.ElideRight
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer1
                text: {
                    const name = Config.options?.bar.workspaces.numberMap[root.workspaceId - 1] || root.workspaceId;
                    const n = popup.windows.length;
                    return `${name}  ·  ${n} ${n === 1 ? "window" : "windows"}`;
                }
            }

            ClippingRectangle {
                id: view
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    margins: frame.padding
                }
                implicitHeight: popup.previewHeight
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer1

                Image { // wallpaper behind the windows
                    anchors.fill: parent
                    source: Config.options.background.wallpaperPath
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: root.previewWidth
                    asynchronous: true
                    cache: true
                }

                Repeater {
                    model: ScriptModel {
                        values: popup.windows
                    }
                    delegate: Item {
                        id: win
                        required property var modelData
                        readonly property var toplevel: ToplevelManager.toplevels.values.find(t => HyprlandData.addressForToplevel(t) === modelData.address) ?? null
                        x: (modelData.at[0] - (popup.monitorData?.x ?? 0)) * popup.factor
                        y: (modelData.at[1] - (popup.monitorData?.y ?? 0)) * popup.factor
                        width: modelData.size[0] * popup.factor
                        height: modelData.size[1] * popup.factor
                        z: (modelData.floating ? 1 : 0) + (modelData.fullscreen ? 2 : 0)

                        Rectangle { // shown until the first captured frame arrives
                            anchors.fill: parent
                            radius: Appearance.rounding.verysmall
                            color: Appearance.colors.colLayer2
                        }
                        ScreencopyView {
                            anchors.fill: parent
                            captureSource: win.toplevel
                            live: true
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: Appearance.rounding.verysmall
                            color: "transparent"
                            border.width: 1
                            border.color: ColorUtils.transparentize(Appearance.m3colors.m3outline, 0.7)
                        }
                    }
                }
            }
        }
    }
}
