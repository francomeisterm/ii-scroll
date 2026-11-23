pragma ComponentBehavior: Bound
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Qt5Compat.GraphicalEffects

/**
 * Sidebar "Recordings" tab: saved screen recordings and replays, newest first,
 * with record / replay controls. Idea from caelestia-shell's RecordingList.
 */
Item {
    id: root

    Component.onCompleted: Recorder.refreshRecordings()

    function formatSize(bytes) {
        if (bytes >= 1024 * 1024 * 1024) return (bytes / (1024 * 1024 * 1024)).toFixed(1) + " GB";
        return Math.max(1, Math.round(bytes / (1024 * 1024))) + " MB";
    }
    function formatDate(ms) {
        const date = new Date(ms);
        const now = new Date();
        const sameDay = date.toDateString() === now.toDateString();
        return sameDay ? Qt.formatDateTime(date, Config.options?.time?.format ?? "hh:mm")
            : Qt.formatDateTime(date, "MMM d · hh:mm");
    }

    ColumnLayout {
        anchors {
            fill: parent
            topMargin: 10
            bottomMargin: 10
            rightMargin: 10
        }
        spacing: 8

        // Controls
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            ControlChip {
                iconName: Recorder.recording ? "stop_circle" : "screen_record"
                label: Recorder.recording ? Recorder.elapsedString : Translation.tr("Record")
                active: Recorder.recording
                tooltip: Translation.tr("Record the focused screen with audio")
                onClicked: Recorder.toggleFullscreenRecording()
            }
            ControlChip {
                iconName: "history"
                label: Recorder.replayActive ? Translation.tr("Replay on") : Translation.tr("Replay")
                active: Recorder.replayActive
                tooltip: Translation.tr("Replay buffer (keeps the last %1s)").arg(Recorder.replaySeconds)
                onClicked: Recorder.toggleReplay()
            }
            ControlChip {
                visible: Recorder.replayActive
                iconName: "save"
                label: Translation.tr("Save")
                tooltip: Translation.tr("Save the last %1s (Alt+F10)").arg(Recorder.replaySeconds)
                onClicked: Recorder.saveReplay()
            }
            Item { Layout.fillWidth: true }
            ItemButton {
                iconName: "folder_open"
                tooltip: Translation.tr("Open folder")
                onClicked: Recorder.openFolder()
            }
        }

        // List
        StyledListView {
            id: listView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 6
            animateAppearance: false
            model: ScriptModel {
                values: Recorder.recordings
                objectProp: "path"
            }
            delegate: RecordingItem {}

            // Empty state
            ColumnLayout {
                anchors.centerIn: parent
                visible: Recorder.recordings.length === 0
                spacing: 4
                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: "videocam_off"
                    iconSize: 40
                    color: Appearance.colors.colSubtext
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Translation.tr("No recordings yet")
                    color: Appearance.colors.colSubtext
                }
            }
        }
    }

    component ControlChip: RippleButton {
        id: chip
        property string iconName
        property string label
        property string tooltip
        property bool active: false
        implicitHeight: 32
        implicitWidth: chipRow.implicitWidth + 20
        buttonRadius: Appearance.rounding.full
        colBackground: active ? Appearance.colors.colPrimary : Appearance.colors.colLayer2
        colBackgroundHover: active ? Appearance.colors.colPrimaryHover : Appearance.colors.colLayer2Hover
        colRipple: active ? Appearance.colors.colPrimaryActive : Appearance.colors.colLayer2Active
        contentItem: Item {
            implicitWidth: chipRow.implicitWidth
            RowLayout {
                id: chipRow
                anchors.centerIn: parent
                spacing: 4
                MaterialSymbol {
                    text: chip.iconName
                    iconSize: Appearance.font.pixelSize.large
                    color: chip.active ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2
                }
                StyledText {
                    text: chip.label
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: chip.active ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2
                }
            }
        }
        StyledToolTip {
            text: chip.tooltip
            extraVisibleCondition: chip.tooltip.length > 0
        }
    }

    component ItemButton: RippleButton {
        id: itemButton
        property string iconName
        property string tooltip
        property color iconColor: Appearance.colors.colOnLayer2
        implicitWidth: 30
        implicitHeight: 30
        buttonRadius: Appearance.rounding.full
        contentItem: MaterialSymbol {
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: itemButton.iconName
            iconSize: Appearance.font.pixelSize.larger
            color: itemButton.iconColor
        }
        StyledToolTip {
            text: itemButton.tooltip
            extraVisibleCondition: itemButton.tooltip.length > 0
        }
    }

    component RecordingItem: Rectangle {
        id: item
        required property var modelData
        property bool confirmDelete: false
        width: ListView.view?.width ?? 0
        implicitHeight: 62
        radius: Appearance.rounding.small
        color: Appearance.colors.colLayer2

        Timer {
            id: confirmReset
            interval: 3000
            onTriggered: item.confirmDelete = false
        }

        RowLayout {
            anchors {
                fill: parent
                margins: 6
            }
            spacing: 10

            // Thumbnail (click to play)
            Rectangle {
                id: thumbFrame
                Layout.fillHeight: true
                implicitWidth: height * 16 / 9
                radius: Appearance.rounding.verysmall
                color: Appearance.colors.colLayer3
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: thumbFrame.width
                        height: thumbFrame.height
                        radius: thumbFrame.radius
                    }
                }
                Image {
                    anchors.fill: parent
                    visible: item.modelData.thumb.length > 0
                    source: item.modelData.thumb.length > 0 ? `file://${item.modelData.thumb}` : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    sourceSize.width: 256
                }
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "play_arrow"
                    fill: 1
                    iconSize: 22
                    color: "white"
                    opacity: thumbMouse.containsMouse || item.modelData.thumb.length === 0 ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }
                MouseArea {
                    id: thumbMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Recorder.openRecording(item.modelData.path)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                StyledText {
                    Layout.fillWidth: true
                    text: item.modelData.name.startsWith("Replay") ? Translation.tr("Replay") : Translation.tr("Recording")
                    color: Appearance.colors.colOnLayer2
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    text: `${root.formatDate(item.modelData.mtime)} · ${root.formatSize(item.modelData.size)}`
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                }
            }

            ItemButton {
                iconName: "content_copy"
                tooltip: Translation.tr("Copy file (paste to attach)")
                onClicked: Recorder.copyRecording(item.modelData.path)
            }
            ItemButton {
                iconName: item.confirmDelete ? "delete_forever" : "delete"
                iconColor: item.confirmDelete ? Appearance.colors.colError : Appearance.colors.colOnLayer2
                tooltip: item.confirmDelete ? Translation.tr("Click again to move to trash") : Translation.tr("Delete")
                onClicked: {
                    if (item.confirmDelete) {
                        confirmReset.stop();
                        Recorder.deleteRecording(item.modelData.path);
                    } else {
                        item.confirmDelete = true;
                        confirmReset.restart();
                    }
                }
            }
        }
    }
}
