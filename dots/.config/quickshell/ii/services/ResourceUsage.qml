pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Simple polled resource usage service with RAM, Swap, CPU and GPU usage.
 * GPU/temperature readout (amdgpu sysfs + k10temp) adapted from caelestia-shell's
 * performance dashboard idea, reimplemented in QML without the C++ plugin.
 */
Singleton {
    id: root
	property real memoryTotal: 1
	property real memoryFree: 0
	property real memoryUsed: memoryTotal - memoryFree
    property real memoryUsedPercentage: memoryUsed / memoryTotal
    property real swapTotal: 1
	property real swapFree: 0
	property real swapUsed: swapTotal - swapFree
    property real swapUsedPercentage: swapTotal > 0 ? (swapUsed / swapTotal) : 0
    property real cpuUsage: 0
    property var previousCpuStats
    property real cpuTemp: NaN // °C (k10temp Tctl / coretemp package)

    // GPU (amdgpu sysfs). Paths are discovered at startup by name, since hwmon indices can change between boots.
    property bool gpuAvailable: false
    property string gpuDevicePath: ""
    property string gpuHwmonPath: ""
    property string cpuTempPath: ""
    property real gpuUsage: 0 // 0-1
    property real gpuTemp: NaN // edge, °C
    property real gpuJunctionTemp: NaN // °C
    property real gpuMemTemp: NaN // °C
    property real gpuVramUsed: 0 // bytes
    property real gpuVramTotal: 1 // bytes
    property real gpuVramUsedPercentage: gpuVramTotal > 0 ? gpuVramUsed / gpuVramTotal : 0
    property real gpuPower: NaN // W
    property real gpuClock: NaN // MHz
    property real gpuFan: NaN // RPM

    property string maxAvailableMemoryString: kbToGbString(ResourceUsage.memoryTotal)
    property string maxAvailableSwapString: kbToGbString(ResourceUsage.swapTotal)
    property string maxAvailableCpuString: "--"

    readonly property int historyLength: Config?.options.resources.historyLength ?? 60
    property list<real> cpuUsageHistory: []
    property list<real> memoryUsageHistory: []
    property list<real> swapUsageHistory: []
    property list<real> gpuUsageHistory: []

    function kbToGbString(kb) {
        return (kb / (1024 * 1024)).toFixed(1) + " GB";
    }
    function bytesToGbString(bytes) {
        return (bytes / (1024 * 1024 * 1024)).toFixed(1) + " GB";
    }
    function tempString(celsius) {
        return isNaN(celsius) ? "--" : `${Math.round(celsius)}°C`;
    }

    function readNumber(fileView) {
        fileView.reload();
        const value = parseFloat(fileView.text());
        return isNaN(value) ? NaN : value;
    }

    function updateGpu() {
        if (!root.gpuAvailable) return;
        const busy = readNumber(fileGpuBusy);
        if (!isNaN(busy)) root.gpuUsage = busy / 100;
        root.gpuVramUsed = readNumber(fileGpuVramUsed) || 0;
        root.gpuVramTotal = readNumber(fileGpuVramTotal) || 1;
        if (root.gpuHwmonPath.length > 0) {
            root.gpuTemp = readNumber(fileGpuTempEdge) / 1000;
            root.gpuJunctionTemp = readNumber(fileGpuTempJunction) / 1000;
            root.gpuMemTemp = readNumber(fileGpuTempMem) / 1000;
            root.gpuPower = readNumber(fileGpuPower) / 1000000;
            root.gpuClock = readNumber(fileGpuClock) / 1000000;
            root.gpuFan = readNumber(fileGpuFan);
        }
    }

    function updateCpuTemp() {
        if (root.cpuTempPath.length === 0) return;
        root.cpuTemp = readNumber(fileCpuTemp) / 1000;
    }

    function updateMemoryUsageHistory() {
        memoryUsageHistory = [...memoryUsageHistory, memoryUsedPercentage]
        if (memoryUsageHistory.length > historyLength) {
            memoryUsageHistory.shift()
        }
    }
    function updateSwapUsageHistory() {
        swapUsageHistory = [...swapUsageHistory, swapUsedPercentage]
        if (swapUsageHistory.length > historyLength) {
            swapUsageHistory.shift()
        }
    }
    function updateCpuUsageHistory() {
        cpuUsageHistory = [...cpuUsageHistory, cpuUsage]
        if (cpuUsageHistory.length > historyLength) {
            cpuUsageHistory.shift()
        }
    }
    function updateGpuUsageHistory() {
        if (!gpuAvailable) return
        gpuUsageHistory = [...gpuUsageHistory, gpuUsage]
        if (gpuUsageHistory.length > historyLength) {
            gpuUsageHistory.shift()
        }
    }
    function updateHistories() {
        updateMemoryUsageHistory()
        updateSwapUsageHistory()
        updateCpuUsageHistory()
        updateGpuUsageHistory()
    }

	Timer {
		interval: 1
        running: true 
        repeat: true
		onTriggered: {
            // Reload files
            fileMeminfo.reload()
            fileStat.reload()

            // Parse memory and swap usage
            const textMeminfo = fileMeminfo.text()
            memoryTotal = Number(textMeminfo.match(/MemTotal: *(\d+)/)?.[1] ?? 1)
            memoryFree = Number(textMeminfo.match(/MemAvailable: *(\d+)/)?.[1] ?? 0)
            swapTotal = Number(textMeminfo.match(/SwapTotal: *(\d+)/)?.[1] ?? 1)
            swapFree = Number(textMeminfo.match(/SwapFree: *(\d+)/)?.[1] ?? 0)

            // Parse CPU usage
            const textStat = fileStat.text()
            const cpuLine = textStat.match(/^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/)
            if (cpuLine) {
                const stats = cpuLine.slice(1).map(Number)
                const total = stats.reduce((a, b) => a + b, 0)
                const idle = stats[3]

                if (previousCpuStats) {
                    const totalDiff = total - previousCpuStats.total
                    const idleDiff = idle - previousCpuStats.idle
                    cpuUsage = totalDiff > 0 ? (1 - idleDiff / totalDiff) : 0
                }

                previousCpuStats = { total, idle }
            }

            root.updateCpuTemp()
            root.updateGpu()
            root.updateHistories()
            interval = Config.options?.resources?.updateInterval ?? 3000
        }
	}

	FileView { id: fileMeminfo; path: "/proc/meminfo" }
    FileView { id: fileStat; path: "/proc/stat" }

    // GPU / temperature sensor files (empty path until discovered)
    FileView { id: fileGpuBusy; path: root.gpuDevicePath ? `${root.gpuDevicePath}/gpu_busy_percent` : "" }
    FileView { id: fileGpuVramUsed; path: root.gpuDevicePath ? `${root.gpuDevicePath}/mem_info_vram_used` : "" }
    FileView { id: fileGpuVramTotal; path: root.gpuDevicePath ? `${root.gpuDevicePath}/mem_info_vram_total` : "" }
    FileView { id: fileGpuTempEdge; path: root.gpuHwmonPath ? `${root.gpuHwmonPath}/temp1_input` : "" }
    FileView { id: fileGpuTempJunction; path: root.gpuHwmonPath ? `${root.gpuHwmonPath}/temp2_input` : "" }
    FileView { id: fileGpuTempMem; path: root.gpuHwmonPath ? `${root.gpuHwmonPath}/temp3_input` : "" }
    FileView { id: fileGpuPower; path: root.gpuHwmonPath ? `${root.gpuHwmonPath}/power1_average` : "" }
    FileView { id: fileGpuClock; path: root.gpuHwmonPath ? `${root.gpuHwmonPath}/freq1_input` : "" }
    FileView { id: fileGpuFan; path: root.gpuHwmonPath ? `${root.gpuHwmonPath}/fan1_input` : "" }
    FileView { id: fileCpuTemp; path: root.cpuTempPath }

    // Find the amdgpu card + its hwmon, and the CPU temperature sensor, by name
    Process {
        id: findSensorsProc
        running: true
        command: ["bash", "-c", `
            for d in /sys/class/drm/card*/device; do
                if [ -r "$d/gpu_busy_percent" ]; then
                    echo "gpu=$(readlink -f "$d")"
                    for h in "$d"/hwmon/hwmon*; do [ -r "$h/temp1_input" ] && echo "gpuhwmon=$h" && break; done
                    break
                fi
            done
            for h in /sys/class/hwmon/hwmon*; do
                case "$(cat "$h/name" 2>/dev/null)" in
                    k10temp|coretemp|zenpower) echo "cputemp=$h/temp1_input"; break ;;
                esac
            done
        `]
        stdout: StdioCollector {
            id: sensorsCollector
            onStreamFinished: {
                for (const line of sensorsCollector.text.split("\n")) {
                    const [key, value] = [line.slice(0, line.indexOf("=")), line.slice(line.indexOf("=") + 1)];
                    if (key === "gpu") root.gpuDevicePath = value;
                    else if (key === "gpuhwmon") root.gpuHwmonPath = value;
                    else if (key === "cputemp") root.cpuTempPath = value;
                }
                root.gpuAvailable = root.gpuDevicePath.length > 0;
            }
        }
    }

    Process {
        id: findCpuMaxFreqProc
        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })
        command: ["bash", "-c", "lscpu | grep 'CPU max MHz' | awk '{print $4}'"]
        running: true
        stdout: StdioCollector {
            id: outputCollector
            onStreamFinished: {
                root.maxAvailableCpuString = (parseFloat(outputCollector.text) / 1000).toFixed(0) + " GHz"
            }
        }
    }
}
