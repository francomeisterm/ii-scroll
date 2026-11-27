import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import qs.modules.compat

Scope {
    id: notificationPopup

    PanelWindow {
        id: root
        // Popups already up when a game goes fullscreen are hidden too (their timers keep running); critical ones stay
        visible: (Notifications.popupList.length > 0) && !GlobalStates.screenLocked
            && !(Notifications.fullscreenInhibited && !Notifications.popupList.some(n => n.urgency === NotificationUrgency.Critical.toString()))
        screen: Quickshell.screens.find(s => Config.options.notifications.forceMonitor?.enable ? s.name === Config.options.notifications.forceMonitor.name : s.name === Hyprland.focusedMonitor?.name) ?? null

        WlrLayershell.namespace: "quickshell:notificationPopup"
        WlrLayershell.layer: WlrLayer.Overlay
        exclusiveZone: 0

        anchors {
            top: true
            right: true
            bottom: true
        }

        mask: Region {
            item: listview.contentItem
        }

        color: "transparent"

        // Scroll: blur behind each popup card (see BlurRegion). The cards register
        // themselves in listview.blurTargets, one region each.
        BackgroundEffect.blurRegion: Region {
            regions: {
                const list = [];
                for (let i = 0; i < popupBlurRegions.count; i++) list.push(popupBlurRegions.objectAt(i));
                return list;
            }
        }
        Instantiator {
            id: popupBlurRegions
            model: listview.blurTargets
            delegate: BlurRegion {
                required property var modelData
                target: modelData
            }
        }
        implicitWidth: Appearance.sizes.notificationPopupWidth

        // Caelestia-style: the popups sit in a panel flush with the bar and the screen edge,
        // joined to them by concave corners
        readonly property bool hug: Config.options.notifications.hug
        readonly property int hugRadius: Appearance.rounding.screenRounding
        readonly property int hugPadding: 8
        Rectangle {
            id: hugPanel
            visible: root.hug && height > 0
            anchors.top: parent.top
            anchors.right: parent.right
            width: parent.width - root.hugRadius
            height: listview.contentHeight > 0 ? listview.contentHeight + root.hugPadding * 2 : 0
            color: Appearance.colors.colLayer0
            bottomLeftRadius: root.hugRadius
            Behavior on height {
                animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
            }
            RoundCorner { // joins the bar
                anchors.right: parent.left
                anchors.top: parent.top
                implicitSize: root.hugRadius
                color: Appearance.colors.colLayer0
                corner: RoundCorner.CornerEnum.TopRight
            }
            RoundCorner { // joins the screen edge below
                anchors.right: parent.right
                anchors.top: parent.bottom
                implicitSize: root.hugRadius
                color: Appearance.colors.colLayer0
                corner: RoundCorner.CornerEnum.TopRight
            }
        }

        NotificationListView {
            id: listview
            anchors {
                top: parent.top
                bottom: parent.bottom
                right: parent.right
                rightMargin: root.hug ? root.hugPadding : 4
                topMargin: root.hug ? root.hugPadding : 4
            }
            implicitWidth: root.hug ? hugPanel.width - root.hugPadding * 2 : parent.width - Appearance.sizes.elevationMargin * 2
            popup: true
        }
    }
}
