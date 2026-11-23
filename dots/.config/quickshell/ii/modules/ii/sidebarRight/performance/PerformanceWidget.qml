pragma ComponentBehavior: Bound
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Qt5Compat.GraphicalEffects

/**
 * Sidebar "Performance" tab: CPU, GPU, RAM and storage cards.
 * Layout idea from caelestia-shell's dashboard/performance; data from services/ResourceUsage.
 */
Item {
    id: root

    // Root filesystem usage (polled slowly, only while this tab is shown)
    property real diskUsed: 0
    property real diskTotal: 1
    Process {
        id: dfProc
        running: true
        command: ["df", "-B1", "--output=used,size", "/"]
        stdout: StdioCollector {
            id: dfCollector
            onStreamFinished: {
                const nums = dfCollector.text.trim().split("\n").pop().trim().split(/\s+/).map(Number);
                if (nums.length === 2 && nums[1] > 0) {
                    root.diskUsed = nums[0];
                    root.diskTotal = nums[1];
                }
            }
        }
    }
    Timer {
        running: true
        repeat: true
        interval: 60000
        onTriggered: dfProc.running = true
    }

    GridLayout {
        anchors {
            fill: parent
            topMargin: 10
            bottomMargin: 10
            rightMargin: 10
        }
        columns: 2
        rowSpacing: 8
        columnSpacing: 8

        PerfCard {
            icon: "planner_review"
            title: "CPU"
            value: ResourceUsage.cpuUsage
            history: ResourceUsage.cpuUsageHistory
            badge: ResourceUsage.tempString(ResourceUsage.cpuTemp)
            badgeWarning: ResourceUsage.cpuTemp >= 85
            detail: ResourceUsage.maxAvailableCpuString
        }
        PerfCard {
            visible: ResourceUsage.gpuAvailable
            icon: "videogame_asset"
            title: "GPU"
            value: ResourceUsage.gpuUsage
            history: ResourceUsage.gpuUsageHistory
            badge: ResourceUsage.tempString(ResourceUsage.gpuJunctionTemp)
            badgeWarning: ResourceUsage.gpuJunctionTemp >= 95
            detail: isNaN(ResourceUsage.gpuPower) ? ""
                : `${Math.round(ResourceUsage.gpuPower)} W · ${ResourceUsage.bytesToGbString(ResourceUsage.gpuVramUsed)} VRAM`
        }
        PerfCard {
            icon: "memory"
            title: "RAM"
            value: ResourceUsage.memoryUsedPercentage
            history: ResourceUsage.memoryUsageHistory
            detail: `${ResourceUsage.kbToGbString(ResourceUsage.memoryUsed)} / ${ResourceUsage.maxAvailableMemoryString}`
        }
        PerfCard {
            icon: "hard_drive"
            title: Translation.tr("Disk")
            value: root.diskUsed / root.diskTotal
            showGraph: false
            detail: `${ResourceUsage.bytesToGbString(root.diskUsed)} / ${ResourceUsage.bytesToGbString(root.diskTotal)}`
        }
    }

    component PerfCard: Rectangle {
        id: card
        required property string icon
        required property string title
        required property real value
        property list<real> history: []
        property bool showGraph: true
        property string badge: ""
        property bool badgeWarning: false
        property string detail: ""

        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer2
        clip: true

        // Usage history behind the content
        Item {
            id: graphWrapper
            visible: card.showGraph
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
            height: parent.height * 0.45
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: graphWrapper.width
                    height: graphWrapper.height
                    radius: card.radius
                }
            }
            Graph {
                anchors.fill: parent
                values: card.history
                points: ResourceUsage.historyLength
                alignment: Graph.Alignment.Right
                fillOpacity: 0.25
                color: card.value >= 0.9 ? Appearance.colors.colError : Appearance.colors.colPrimary
            }
        }

        ColumnLayout {
            anchors {
                fill: parent
                margins: 10
            }
            spacing: 2

            RowLayout {
                spacing: 6
                MaterialSymbol {
                    text: card.icon
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colOnLayer2
                }
                StyledText {
                    Layout.fillWidth: true
                    text: card.title
                    color: Appearance.colors.colOnLayer2
                    font.pixelSize: Appearance.font.pixelSize.small
                }
                Rectangle {
                    visible: card.badge.length > 0
                    implicitWidth: badgeText.implicitWidth + 12
                    implicitHeight: badgeText.implicitHeight + 4
                    radius: Appearance.rounding.full
                    color: card.badgeWarning ? Appearance.colors.colError : Appearance.colors.colSecondaryContainer
                    StyledText {
                        id: badgeText
                        anchors.centerIn: parent
                        text: card.badge
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: card.badgeWarning ? Appearance.colors.colOnError : Appearance.colors.colOnSecondaryContainer
                    }
                }
            }

            StyledText {
                text: `${Math.round(card.value * 100)}%`
                color: Appearance.colors.colOnLayer2
                font {
                    family: Appearance.font.family.numbers
                    variableAxes: Appearance.font.variableAxes.numbers
                    pixelSize: Appearance.font.pixelSize.huge
                }
            }
            StyledText {
                Layout.fillWidth: true
                visible: card.detail.length > 0
                text: card.detail
                elide: Text.ElideRight
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smallie
            }

            Item { Layout.fillHeight: true }

            StyledProgressBar {
                visible: !card.showGraph
                Layout.fillWidth: true
                value: card.value
                highlightColor: card.value >= 0.9 ? Appearance.colors.colError : Appearance.colors.colPrimary
            }
        }
    }
}
