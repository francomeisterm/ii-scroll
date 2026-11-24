pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.I3
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.modules.compat

/**
 * Window info panel (idea from caelestia-shell's windowinfo): live preview of a
 * window, its details from Scroll's tree, and actions (float/tile, fullscreen,
 * sticky, move to workspace, close).
 * Opened by right-clicking the window title in the bar, or:
 *   qs -c ii ipc call windowInfo toggle
 * Shows the window that was focused when it opened, and follows it while open.
 */
Scope {
    id: root

    property string targetAddress: ""
    readonly property var client: HyprlandData.windowList.find(w => w.address === root.targetAddress) ?? null
    readonly property var toplevel: ToplevelManager.toplevels.values.find(t => HyprlandData.addressForToplevel(t) === root.targetAddress) ?? null

    function open(address: string): void {
        const addr = address || (HyprlandData.windowList.find(w => w.focused)?.address ?? "");
        if (!addr) {
            Toasts.show(Translation.tr("No focused window"), "web_asset_off");
            return;
        }
        root.targetAddress = addr;
        panelLoader.active = true;
    }
    function close(): void {
        panelLoader.active = false;
    }
    function toggle(address: string): void {
        if (panelLoader.active)
            root.close();
        else
            root.open(address);
    }
    function run(cmd: string): void {
        if (!root.client)
            return;
        I3.dispatch(`[con_id=${root.client.conId}] ${cmd}`);
        HyprlandData.updateAll();
    }

    Connections {
        target: GlobalStates
        function onWindowInfoRequestChanged() {
            if (GlobalStates.windowInfoRequest === "")
                return;
            root.toggle(GlobalStates.windowInfoRequest === "focused" ? "" : GlobalStates.windowInfoRequest);
            GlobalStates.windowInfoRequest = "";
        }
    }

    // Close when the window goes away
    onClientChanged: {
        if (panelLoader.active && !root.client)
            closeTimer.restart();
    }
    Timer {
        id: closeTimer
        interval: 400 // the tree refresh can briefly lag behind a focus change
        onTriggered: if (!root.client) root.close()
    }

    Loader {
        id: panelLoader
        active: false
        sourceComponent: PanelWindow {
            id: panelWindow
            visible: true
            screen: Quickshell.screens.find(s => s.name === HyprlandData.monitors[root.client?.monitor ?? -1]?.name) ?? Quickshell.screens[0]
            color: "transparent"
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:windowInfo"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            anchors {
                top: !Config.options.bar.bottom
                bottom: Config.options.bar.bottom
                left: true
            }
            margins {
                top: Config.options.bar.vertical ? Appearance.sizes.elevationMargin : Appearance.sizes.barHeight
                bottom: Config.options.bar.vertical ? Appearance.sizes.elevationMargin : Appearance.sizes.barHeight
                left: Config.options.bar.vertical ? Appearance.sizes.verticalBarWidth : 0
            }
            implicitWidth: background.implicitWidth + Appearance.sizes.elevationMargin * 2
            implicitHeight: background.implicitHeight + Appearance.sizes.elevationMargin * 2
            mask: Region {
                item: background
            }

            Component.onCompleted: GlobalFocusGrab.addDismissable(panelWindow)
            Component.onDestruction: GlobalFocusGrab.removeDismissable(panelWindow)
            Connections {
                target: GlobalFocusGrab
                function onDismissed() {
                    root.close();
                }
            }

            StyledRectangularShadow {
                target: background
            }
            Rectangle {
                id: background
                anchors.centerIn: parent
                color: Appearance.colors.colLayer0
                border.width: 1
                border.color: Appearance.colors.colLayer0Border
                radius: Appearance.rounding.windowRounding
                readonly property real padding: 14
                implicitWidth: contentRow.implicitWidth + padding * 2
                implicitHeight: contentRow.implicitHeight + padding * 2
                focus: true
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape)
                        root.close();
                }

                RowLayout {
                    id: contentRow
                    anchors.centerIn: parent
                    spacing: 14

                    // Preview
                    Rectangle {
                        id: previewBox
                        Layout.alignment: Qt.AlignTop
                        readonly property real boxHeight: 300
                        readonly property real aspect: root.client ? Math.max(0.3, Math.min(3, root.client.size[0] / Math.max(1, root.client.size[1]))) : 16 / 9
                        implicitWidth: Math.min(boxHeight * aspect, 520)
                        implicitHeight: Math.min(boxHeight, implicitWidth / aspect)
                        radius: Appearance.rounding.normal
                        color: Appearance.colors.colLayer1
                        clip: true

                        MaterialSymbol {
                            anchors.centerIn: parent
                            visible: !root.toplevel
                            text: "web_asset_off"
                            iconSize: 48
                            color: Appearance.colors.colSubtext
                        }
                        ScreencopyView {
                            anchors.fill: parent
                            captureSource: root.toplevel
                            live: true
                        }
                    }

                    // Details and actions
                    ColumnLayout {
                        Layout.alignment: Qt.AlignTop
                        Layout.preferredWidth: 320
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            IconImage {
                                implicitSize: 32
                                source: Quickshell.iconPath(AppSearch.guessIcon(root.client?.class ?? ""), "image-missing")
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                StyledText {
                                    Layout.fillWidth: true
                                    text: root.client?.title || Translation.tr("Untitled")
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    color: Appearance.colors.colOnLayer0
                                    elide: Text.ElideRight
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    text: root.client?.class || Translation.tr("Unknown app")
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colSubtext
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: detailsGrid.implicitHeight + 16
                            radius: Appearance.rounding.normal
                            color: Appearance.colors.colLayer1

                            GridLayout {
                                id: detailsGrid
                                anchors {
                                    fill: parent
                                    margins: 8
                                }
                                columns: 2
                                rowSpacing: 4
                                columnSpacing: 12

                                DetailRow {
                                    icon: "workspaces"
                                    text: Translation.tr("Workspace %1").arg(root.client?.workspace.name || root.client?.workspace.id || "?")
                                }
                                DetailRow {
                                    icon: "desktop_windows"
                                    text: HyprlandData.monitors[root.client?.monitor ?? -1]?.name ?? "?"
                                }
                                DetailRow {
                                    icon: "location_searching"
                                    text: root.client ? `${root.client.at[0]}, ${root.client.at[1]}` : "?"
                                }
                                DetailRow {
                                    icon: "resize"
                                    text: root.client ? `${root.client.size[0]} × ${root.client.size[1]}` : "?"
                                }
                                DetailRow {
                                    icon: "account_tree"
                                    text: Translation.tr("PID %1").arg(root.client?.pid ?? "?")
                                }
                                DetailRow {
                                    icon: "gradient"
                                    text: root.client?.xwayland ? "Xwayland" : "Wayland"
                                }
                                DetailRow {
                                    icon: "picture_in_picture_center"
                                    text: root.client?.floating ? Translation.tr("Floating") : Translation.tr("Tiled")
                                }
                                DetailRow {
                                    icon: "keep"
                                    text: root.client?.pinned ? Translation.tr("Sticky") : Translation.tr("Not sticky")
                                }
                            }
                        }

                        // Actions
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            ActionButton {
                                symbol: root.client?.floating ? "grid_view" : "picture_in_picture_center"
                                caption: root.client?.floating ? Translation.tr("Tile") : Translation.tr("Float")
                                onClicked: root.run("floating toggle")
                            }
                            ActionButton {
                                symbol: (root.client?.fullscreen ?? 0) > 0 ? "fullscreen_exit" : "fullscreen"
                                caption: Translation.tr("Fullscreen")
                                onClicked: root.run("fullscreen toggle")
                            }
                            ActionButton {
                                visible: root.client?.floating ?? false
                                symbol: "keep"
                                caption: root.client?.pinned ? Translation.tr("Unstick") : Translation.tr("Stick")
                                onClicked: root.run("sticky toggle")
                            }
                            ActionButton {
                                symbol: "close"
                                caption: Translation.tr("Close")
                                danger: true
                                onClicked: {
                                    root.run("kill");
                                    root.close();
                                }
                            }
                        }

                        StyledText {
                            text: Translation.tr("Move to workspace")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 5
                            rowSpacing: 4
                            columnSpacing: 4
                            Repeater {
                                model: 10
                                delegate: RippleButton {
                                    id: wsButton
                                    required property int index
                                    readonly property int wsNum: index + 1
                                    readonly property bool current: root.client?.workspace.id === wsNum
                                    Layout.fillWidth: true
                                    implicitHeight: 32
                                    buttonRadius: Appearance.rounding.small
                                    toggled: current
                                    colBackground: Appearance.colors.colLayer1
                                    onClicked: {
                                        if (wsButton.current)
                                            return;
                                        root.run(`move container to workspace number ${wsNum}`);
                                        I3.dispatch(`workspace number ${wsNum}`);
                                    }
                                    contentItem: StyledText {
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        text: wsButton.wsNum
                                        color: wsButton.current ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component DetailRow: RowLayout {
        id: detailRow
        required property string icon
        required property string text
        Layout.fillWidth: true
        spacing: 6
        MaterialSymbol {
            text: detailRow.icon
            iconSize: Appearance.font.pixelSize.normal
            color: Appearance.colors.colSubtext
        }
        StyledText {
            Layout.fillWidth: true
            text: detailRow.text
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colOnLayer1
            elide: Text.ElideRight
        }
    }

    component ActionButton: RippleButton {
        id: actionButton
        required property string symbol
        required property string caption
        property bool danger: false
        Layout.fillWidth: true
        implicitHeight: 52
        buttonRadius: Appearance.rounding.normal
        colBackground: danger ? Appearance.colors.colErrorContainer : Appearance.colors.colLayer1
        colBackgroundHover: danger ? Appearance.colors.colErrorContainerHover : Appearance.colors.colLayer1Hover
        contentItem: ColumnLayout {
            spacing: 0
            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                text: actionButton.symbol
                iconSize: Appearance.font.pixelSize.larger
                color: actionButton.danger ? Appearance.colors.colOnErrorContainer : Appearance.colors.colOnLayer1
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: actionButton.caption
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: actionButton.danger ? Appearance.colors.colOnErrorContainer : Appearance.colors.colOnLayer1
            }
        }
    }

    IpcHandler {
        target: "windowInfo"

        function toggle(): void {
            root.toggle("");
        }
        function open(): void {
            root.open("");
        }
        function close(): void {
            root.close();
        }
    }

    GlobalShortcut {
        name: "windowInfoToggle"
        description: "Toggles the window info panel for the focused window"
        onPressed: root.toggle("")
    }
}
