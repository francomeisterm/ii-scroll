import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// Lock screen media card and notification list (idea from caelestia-shell's lock screen).
// Notifications show the app and summary only; bodies stay hidden on the lock screen.
ColumnLayout {
    id: root

    property real cardWidth: 400
    property int maxNotifs: Config.options.lock.maxNotifications

    readonly property var player: MprisController.activePlayer
    readonly property bool showMedia: Config.options.lock.showMedia && player !== null && (player.trackTitle ?? "") !== ""
    readonly property var notifs: Config.options.lock.showNotifications ? [...Notifications.list].sort((a, b) => b.time - a.time) : []
    readonly property bool showNotifs: notifs.length > 0

    spacing: 10
    visible: showMedia || showNotifs

    // Media
    Rectangle {
        id: mediaCard
        visible: root.showMedia
        Layout.preferredWidth: root.cardWidth
        implicitHeight: mediaRow.implicitHeight + 20
        radius: Appearance.rounding.large
        color: Appearance.m3colors.m3surfaceContainer
        clip: true

        StyledRectangularShadow {
            target: mediaCard
            z: -1
        }

        // Blurred album art behind the card
        Image {
            id: bgArt
            anchors.fill: parent
            source: root.player?.trackArtUrl ?? ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
        }
        FastBlur {
            anchors.fill: parent
            source: bgArt
            radius: 48
            opacity: bgArt.status === Image.Ready ? 0.35 : 0
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: mediaCard.width
                    height: mediaCard.height
                    radius: mediaCard.radius
                }
            }
            Behavior on opacity {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }
        }

        RowLayout {
            id: mediaRow
            anchors {
                fill: parent
                margins: 10
            }
            spacing: 12

            Rectangle {
                id: artBox
                Layout.preferredWidth: 56
                Layout.preferredHeight: 56
                radius: Appearance.rounding.normal
                color: Appearance.colors.colSecondaryContainer

                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: art.status !== Image.Ready
                    text: "music_note"
                    iconSize: 28
                    color: Appearance.colors.colOnSecondaryContainer
                }
                Image {
                    id: art
                    anchors.fill: parent
                    source: root.player?.trackArtUrl ?? ""
                    sourceSize.width: 112
                    sourceSize.height: 112
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: artBox.width
                            height: artBox.height
                            radius: artBox.radius
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                StyledText {
                    Layout.fillWidth: true
                    text: StringUtils.cleanMusicTitle(root.player?.trackTitle ?? "") || Translation.tr("Unknown Title")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnLayer1
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    text: root.player?.trackArtist || Translation.tr("Unknown Artist")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                }
            }

            IconToolbarButton {
                implicitHeight: 40
                enabled: MprisController.canGoPrevious
                text: "skip_previous"
                onClicked: MprisController.previous()
            }
            IconToolbarButton {
                implicitHeight: 40
                enabled: MprisController.canTogglePlaying
                toggled: true
                text: MprisController.isPlaying ? "pause" : "play_arrow"
                onClicked: MprisController.togglePlaying()
            }
            IconToolbarButton {
                implicitHeight: 40
                enabled: MprisController.canGoNext
                text: "skip_next"
                onClicked: MprisController.next()
            }
        }
    }

    // Notifications
    Rectangle {
        id: notifCard
        visible: root.showNotifs
        Layout.preferredWidth: root.cardWidth
        implicitHeight: notifColumn.implicitHeight + 20
        radius: Appearance.rounding.large
        color: Appearance.m3colors.m3surfaceContainer

        StyledRectangularShadow {
            target: notifCard
            z: -1
        }

        ColumnLayout {
            id: notifColumn
            anchors {
                fill: parent
                margins: 10
            }
            spacing: 6

            RowLayout {
                Layout.leftMargin: 4
                Layout.rightMargin: 4
                spacing: 6
                MaterialSymbol {
                    text: "notifications"
                    fill: 1
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colSubtext
                }
                StyledText {
                    Layout.fillWidth: true
                    text: root.notifs.length === 1 ? Translation.tr("1 notification") : Translation.tr("%1 notifications").arg(root.notifs.length)
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
            }

            Repeater {
                model: root.notifs.slice(0, root.maxNotifs)
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 10

                    NotificationAppIcon {
                        implicitSize: 32
                        appIcon: modelData.appIcon
                        summary: modelData.summary
                        urgency: modelData.urgency
                        // The notification image can be a chat avatar or a screenshot: keep it off the lock screen
                        image: ""
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        StyledText {
                            Layout.fillWidth: true
                            text: modelData.appName || Translation.tr("Notification")
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.colors.colSubtext
                            elide: Text.ElideRight
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: modelData.summary
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnLayer1
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                        }
                    }
                    StyledText {
                        text: {
                            const d = new Date(modelData.time);
                            return d.toDateString() === new Date().toDateString()
                                ? Qt.formatTime(d, Config.options.time.format)
                                : Qt.formatDate(d, Config.options.time.shortDateFormat);
                        }
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colSubtext
                    }
                }
            }

            StyledText {
                visible: root.notifs.length > root.maxNotifs
                Layout.leftMargin: 4
                text: Translation.tr("+%1 more").arg(root.notifs.length - root.maxNotifs)
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colSubtext
            }
        }
    }
}
