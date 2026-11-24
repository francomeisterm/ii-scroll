import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell.Io
import Quickshell
import Quickshell.Wayland
import qs.modules.compat

Scope {
    id: root
    property int sidebarWidth: Appearance.sizes.sidebarWidth
    // Caelestia-style: no gaps, flush with the bar and the screen edge, concave corners on the inner side
    readonly property bool hug: Config.options.sidebar.hug
    readonly property int hugRadius: Appearance.rounding.screenRounding

    PanelWindow {
        id: panelWindow
        // Scroll port: Hyprland slides layer surfaces in/out (layer_rule "slide right");
        // Scroll only animates layer resizes, so slide the content here and keep the
        // surface mapped until the exit slide finishes.
        property real reveal: GlobalStates.sidebarRightOpen ? 1 : 0
        readonly property real slideOffset: (1 - reveal) * sidebarWidth
        Behavior on reveal {
            NumberAnimation {
                duration: GlobalStates.sidebarRightOpen ? Appearance.animation.elementMoveEnter.duration : Appearance.animation.elementMoveExit.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: GlobalStates.sidebarRightOpen ? Appearance.animation.elementMoveEnter.bezierCurve : Appearance.animation.elementMoveExit.bezierCurve
            }
        }
        visible: GlobalStates.sidebarRightOpen || reveal > 0

        function hide() {
            GlobalStates.sidebarRightOpen = false;
        }

        exclusiveZone: 0
        implicitWidth: sidebarWidth
        WlrLayershell.namespace: "quickshell:sidebarRight"
        // Scroll: blur behind the background (see BlurRegion)
        BackgroundEffect.blurRegion: BlurRegion {
            target: sidebarContentLoader
            radius: Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut + 1
        }
        WlrLayershell.keyboardFocus: GlobalStates.sidebarRightOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        color: "transparent"

        anchors {
            top: true
            right: true
            bottom: true
        }

        // Grab follows the open state, not visibility (visible lags during the exit slide)
        function syncFocusGrab() {
            if (GlobalStates.sidebarRightOpen && visible) {
                GlobalFocusGrab.addDismissable(panelWindow);
            } else {
                GlobalFocusGrab.removeDismissable(panelWindow);
            }
        }
        onVisibleChanged: syncFocusGrab()
        Connections {
            target: GlobalStates
            function onSidebarRightOpenChanged() {
                panelWindow.syncFocusGrab();
            }
        }
        Connections {
            target: GlobalFocusGrab
            function onDismissed() {
                panelWindow.hide();
            }
        }

        Loader {
            id: sidebarContentLoader
            active: panelWindow.visible || Config?.options.sidebar.keepRightSidebarLoaded
            anchors {
                fill: parent
                margins: root.hug ? 0 : Appearance.sizes.hyprlandGapsOut
                leftMargin: (root.hug ? root.hugRadius : Appearance.sizes.elevationMargin) + panelWindow.slideOffset
                rightMargin: (root.hug ? 0 : Appearance.sizes.hyprlandGapsOut) - panelWindow.slideOffset
            }
            width: sidebarWidth - Appearance.sizes.hyprlandGapsOut - Appearance.sizes.elevationMargin
            height: parent.height - Appearance.sizes.hyprlandGapsOut * 2

            focus: GlobalStates.sidebarRightOpen
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    panelWindow.hide();
                }
            }

            sourceComponent: SidebarRightContent {}
        }

        // Hug: concave corners joining the panel to the bar above and the screen edge below
        RoundCorner {
            visible: root.hug && sidebarContentLoader.active
            anchors.right: sidebarContentLoader.left
            anchors.top: sidebarContentLoader.top
            implicitSize: root.hugRadius
            color: Appearance.colors.colLayer0
            corner: RoundCorner.CornerEnum.TopRight
        }
        RoundCorner {
            visible: root.hug && sidebarContentLoader.active
            anchors.right: sidebarContentLoader.left
            anchors.bottom: sidebarContentLoader.bottom
            implicitSize: root.hugRadius
            color: Appearance.colors.colLayer0
            corner: RoundCorner.CornerEnum.BottomRight
        }
    }

    IpcHandler {
        target: "sidebarRight"

        function toggle(): void {
            GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
        }

        function close(): void {
            GlobalStates.sidebarRightOpen = false;
        }

        function open(): void {
            GlobalStates.sidebarRightOpen = true;
        }
    }

    GlobalShortcut {
        name: "sidebarRightToggle"
        description: "Toggles right sidebar on press"

        onPressed: {
            GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
        }
    }
    GlobalShortcut {
        name: "sidebarRightOpen"
        description: "Opens right sidebar on press"

        onPressed: {
            GlobalStates.sidebarRightOpen = true;
        }
    }
    GlobalShortcut {
        name: "sidebarRightClose"
        description: "Closes right sidebar on press"

        onPressed: {
            GlobalStates.sidebarRightOpen = false;
        }
    }
}
