import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.modules.compat

Scope {
    id: notificationPopup

    PanelWindow {
        id: root
        visible: (Notifications.popupList.length > 0) && !GlobalStates.screenLocked
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

        // Scroll: blur behind each popup card (see BlurRegion). One region per list row;
        // itemAtIndex() is not a binding, so count/contentHeight re-run it when rows change.
        BackgroundEffect.blurRegion: Region {
            regions: {
                const list = [];
                for (let i = 0; i < popupBlurRegions.count; i++) list.push(popupBlurRegions.objectAt(i));
                return list;
            }
        }
        Instantiator {
            id: popupBlurRegions
            model: listview.count
            delegate: BlurRegion {
                required property int index
                target: (listview.count, listview.contentHeight, listview.itemAtIndex(index))?.blurTarget ?? null
            }
        }
        implicitWidth: Appearance.sizes.notificationPopupWidth

        NotificationListView {
            id: listview
            anchors {
                top: parent.top
                bottom: parent.bottom
                right: parent.right
                rightMargin: 4
                topMargin: 4
            }
            implicitWidth: parent.width - Appearance.sizes.elevationMargin * 2
            popup: true
        }
    }
}
