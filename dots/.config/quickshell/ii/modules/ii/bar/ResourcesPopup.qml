import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root

    // Helper function to format KB to GB
    function formatKB(kb) {
        return (kb / (1024 * 1024)).toFixed(1) + " GB";
    }

    Row {
        anchors.centerIn: parent
        spacing: 12

        Column {
            anchors.top: parent.top
            spacing: 8

            StyledPopupHeaderRow {
                icon: "memory"
                label: "RAM"
            }
            Column {
                spacing: 4
                StyledPopupValueRow {
                    icon: "clock_loader_60"
                    label: Translation.tr("Used:")
                    value: root.formatKB(ResourceUsage.memoryUsed)
                }
                StyledPopupValueRow {
                    icon: "check_circle"
                    label: Translation.tr("Free:")
                    value: root.formatKB(ResourceUsage.memoryFree)
                }
                StyledPopupValueRow {
                    icon: "empty_dashboard"
                    label: Translation.tr("Total:")
                    value: root.formatKB(ResourceUsage.memoryTotal)
                }
            }
        }

        Column {
            visible: ResourceUsage.swapTotal > 0
            anchors.top: parent.top
            spacing: 8

            StyledPopupHeaderRow {
                icon: "swap_horiz"
                label: "Swap"
            }
            Column {
                spacing: 4
                StyledPopupValueRow {
                    icon: "clock_loader_60"
                    label: Translation.tr("Used:")
                    value: root.formatKB(ResourceUsage.swapUsed)
                }
                StyledPopupValueRow {
                    icon: "check_circle"
                    label: Translation.tr("Free:")
                    value: root.formatKB(ResourceUsage.swapFree)
                }
                StyledPopupValueRow {
                    icon: "empty_dashboard"
                    label: Translation.tr("Total:")
                    value: root.formatKB(ResourceUsage.swapTotal)
                }
            }
        }

        Column {
            anchors.top: parent.top
            spacing: 8

            StyledPopupHeaderRow {
                icon: "planner_review"
                label: "CPU"
            }
            Column {
                spacing: 4
                StyledPopupValueRow {
                    icon: "bolt"
                    label: Translation.tr("Load:")
                    value: `${Math.round(ResourceUsage.cpuUsage * 100)}%`
                }
                StyledPopupValueRow {
                    visible: !isNaN(ResourceUsage.cpuTemp)
                    icon: "thermometer"
                    label: Translation.tr("Temp:")
                    value: ResourceUsage.tempString(ResourceUsage.cpuTemp)
                }
            }
        }

        Column {
            visible: ResourceUsage.gpuAvailable
            anchors.top: parent.top
            spacing: 8

            StyledPopupHeaderRow {
                icon: "videogame_asset"
                label: "GPU"
            }
            Column {
                spacing: 4
                StyledPopupValueRow {
                    icon: "bolt"
                    label: Translation.tr("Load:")
                    value: `${Math.round(ResourceUsage.gpuUsage * 100)}%`
                }
                StyledPopupValueRow {
                    icon: ResourceUsage.gpuJunctionTemp >= 95 ? "thermometer_alert" : "thermometer"
                    label: Translation.tr("Temp:")
                    value: `${ResourceUsage.tempString(ResourceUsage.gpuTemp)} / ${ResourceUsage.tempString(ResourceUsage.gpuJunctionTemp)}`
                }
                StyledPopupValueRow {
                    icon: "memory_alt"
                    label: Translation.tr("VRAM:")
                    value: `${ResourceUsage.bytesToGbString(ResourceUsage.gpuVramUsed)} / ${ResourceUsage.bytesToGbString(ResourceUsage.gpuVramTotal)}`
                }
                StyledPopupValueRow {
                    visible: !isNaN(ResourceUsage.gpuPower)
                    icon: "electric_bolt"
                    label: Translation.tr("Power:")
                    value: `${Math.round(ResourceUsage.gpuPower)} W`
                }
                StyledPopupValueRow {
                    visible: !isNaN(ResourceUsage.gpuClock)
                    icon: "speed"
                    label: Translation.tr("Clock:")
                    value: `${Math.round(ResourceUsage.gpuClock)} MHz`
                }
            }
        }
    }
}
