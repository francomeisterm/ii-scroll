import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell

/**
 * VPN picker (right-click on the VPN quick toggle): every NetworkManager VPN/WireGuard
 * connection. Click one to connect it (and make it the toggle's default); click the
 * connected one to disconnect.
 */
WindowDialog {
    id: root
    backgroundHeight: 420

    WindowDialogTitle {
        text: Translation.tr("VPN")
    }
    WindowDialogSeparator {
        visible: !Vpn.busy
    }
    StyledIndeterminateProgressBar {
        visible: Vpn.busy
        Layout.fillWidth: true
        Layout.topMargin: -8
        Layout.bottomMargin: -8
        Layout.leftMargin: -Appearance.rounding.large
        Layout.rightMargin: -Appearance.rounding.large
    }
    ListView {
        Layout.fillHeight: true
        Layout.fillWidth: true
        Layout.topMargin: -15
        Layout.bottomMargin: -16
        Layout.leftMargin: -Appearance.rounding.large
        Layout.rightMargin: -Appearance.rounding.large

        clip: true
        spacing: 0

        model: ScriptModel {
            values: Vpn.connections
            objectProp: "uuid"
        }
        delegate: DialogListItem {
            id: vpnItem
            required property var modelData
            readonly property bool isActive: Vpn.activeName === modelData.name
            readonly property bool isConnecting: Vpn.activatingName === modelData.name
            readonly property bool isPreferred: Vpn.preferredName === modelData.name
            width: ListView.view.width
            active: isActive
            enabled: !Vpn.busy || isConnecting
            onClicked: {
                if (vpnItem.isActive) Vpn.disconnect();
                else Vpn.select(vpnItem.modelData.name);
            }

            contentItem: RowLayout {
                anchors {
                    fill: parent
                    topMargin: vpnItem.verticalPadding
                    bottomMargin: vpnItem.verticalPadding
                    leftMargin: vpnItem.horizontalPadding
                    rightMargin: vpnItem.horizontalPadding
                }
                spacing: 10

                MaterialSymbol {
                    iconSize: Appearance.font.pixelSize.larger
                    text: vpnItem.isActive ? "vpn_lock" : "vpn_key"
                    fill: vpnItem.isActive ? 1 : 0
                    color: vpnItem.isActive ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    StyledText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: vpnItem.modelData.name
                        textFormat: Text.PlainText
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                    StyledText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                        text: {
                            const parts = [Vpn.typeLabel(vpnItem.modelData.type)];
                            if (vpnItem.isActive) parts.push(Translation.tr("Connected · click to disconnect"));
                            else if (vpnItem.isConnecting) parts.push(Translation.tr("Connecting…"));
                            else if (vpnItem.isPreferred) parts.push(Translation.tr("Toggle default"));
                            return parts.join(" · ");
                        }
                    }
                }
                MaterialSymbol {
                    visible: vpnItem.isActive || vpnItem.isPreferred
                    text: vpnItem.isActive ? "check" : "star"
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colOnSurfaceVariant
                }
            }
        }

        // Empty state
        ColumnLayout {
            anchors.centerIn: parent
            visible: Vpn.connections.length === 0
            width: parent.width - 40
            spacing: 4
            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                text: "vpn_key_off"
                iconSize: 40
                color: Appearance.colors.colSubtext
            }
            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: Translation.tr("No VPN connections in NetworkManager. Add one with Edit, or import a .ovpn / WireGuard .conf with nmcli.")
                color: Appearance.colors.colSubtext
            }
        }
    }
    WindowDialogSeparator {}
    WindowDialogButtonRow {
        DialogButton {
            buttonText: Translation.tr("Edit")
            onClicked: {
                Quickshell.execDetached(["nm-connection-editor"]);
                GlobalStates.sidebarRightOpen = false;
            }
        }

        Item {
            Layout.fillWidth: true
        }

        DialogButton {
            buttonText: Translation.tr("Done")
            onClicked: root.dismiss()
        }
    }
}
