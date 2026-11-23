pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * NetworkManager VPN connections (OpenConnect/AnyConnect, OpenVPN, WireGuard, ...).
 * Idea from caelestia-shell's VPN service; this one goes through nmcli, so secrets and
 * auth prompts are handled by NetworkManager and its secret agent (nm-applet).
 *
 * The quick toggle connects Config.options.vpn.connection, or the first VPN listed.
 */
Singleton {
    id: root

    property list<var> connections: [] // [{ name, type, uuid }]
    property string activeName: "" // fully activated VPN, if any
    property string activatingName: ""
    readonly property bool connected: activeName.length > 0
    readonly property bool busy: activatingName.length > 0 || upProc.running || downProc.running
    readonly property bool available: connections.length > 0

    readonly property string preferredName: {
        const wanted = Config.options?.vpn?.connection ?? "";
        if (wanted.length > 0 && connections.some(c => c.name === wanted)) return wanted;
        return connections[0]?.name ?? "";
    }
    readonly property string targetName: connected ? activeName : preferredName

    function load() {} // Force singleton instantiation

    // nmcli -t escapes ':' and '\' with a backslash
    function splitTerse(line) {
        const out = [];
        let cur = "";
        for (let i = 0; i < line.length; i++) {
            const ch = line[i];
            if (ch === "\\" && i + 1 < line.length) { cur += line[++i]; continue; }
            if (ch === ":") { out.push(cur); cur = ""; continue; }
            cur += ch;
        }
        out.push(cur);
        return out;
    }
    function isVpnType(type) {
        return type === "vpn" || type === "wireguard";
    }

    function refresh() {
        if (!listProc.running) listProc.running = true;
        if (!activeProc.running) activeProc.running = true;
    }

    // Connects `name` (default: the preferred VPN). Another VPN that is up gets taken down first.
    function connect(name) {
        const target = name || root.preferredName;
        if (!target || upProc.running) return;
        if (target === root.activeName) return;
        root.activatingName = target;
        Toasts.show(Translation.tr("Connecting to %1…").arg(target), "vpn_lock", 0);
        upProc.command = ["bash", "-c",
            'if [ -n "$1" ]; then nmcli connection down id "$1" >/dev/null 2>&1; fi; exec nmcli connection up id "$2"',
            "bash", root.activeName, target];
        upProc.running = true;
    }
    // Makes `name` the toggle's default (saved in config) and connects it
    function select(name) {
        if (Config.options?.vpn) Config.options.vpn.connection = name;
        connect(name);
    }
    function typeLabel(type) {
        return type === "wireguard" ? "WireGuard" : Translation.tr("VPN");
    }
    function disconnect() {
        if (!root.activeName || downProc.running) return;
        downProc.command = ["nmcli", "connection", "down", "id", root.activeName];
        downProc.running = true;
    }
    function toggle() {
        if (root.connected) disconnect();
        else connect();
    }

    onActiveNameChanged: {
        if (activeName) Toasts.show(Translation.tr("VPN connected · %1").arg(activeName), "vpn_lock", 0);
        else Toasts.show(Translation.tr("VPN disconnected"), "vpn_key_off", 0);
    }

    Component.onCompleted: refresh()

    Process {
        id: listProc
        command: ["nmcli", "-t", "-f", "NAME,TYPE,UUID", "connection", "show"]
        stdout: StdioCollector {
            id: listCollector
            onStreamFinished: {
                root.connections = listCollector.text.split("\n")
                    .filter(l => l.length > 0)
                    .map(l => root.splitTerse(l))
                    .filter(f => root.isVpnType(f[1]))
                    .map(f => ({ name: f[0], type: f[1], uuid: f[2] }));
            }
        }
    }

    Process {
        id: activeProc
        command: ["nmcli", "-t", "-f", "NAME,TYPE,STATE", "connection", "show", "--active"]
        stdout: StdioCollector {
            id: activeCollector
            onStreamFinished: {
                const vpns = activeCollector.text.split("\n")
                    .filter(l => l.length > 0)
                    .map(l => root.splitTerse(l))
                    .filter(f => root.isVpnType(f[1]));
                root.activeName = vpns.find(f => f[2] === "activated")?.[0] ?? "";
                const activating = vpns.find(f => f[2] === "activating")?.[0] ?? "";
                if (!upProc.running) root.activatingName = activating;
            }
        }
    }

    Process {
        id: upProc
        stderr: StdioCollector { id: upErr }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                const reason = upErr.text.trim().split("\n").pop() || Translation.tr("unknown error");
                Toasts.show(Translation.tr("VPN failed: %1").arg(reason), "error", 5000);
            }
            root.activatingName = "";
            root.refresh();
        }
    }

    Process {
        id: downProc
        onExited: root.refresh()
    }

    // React to NetworkManager changes (also catches connects from nm-applet / nmcli)
    Process {
        id: monitorProc
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            onRead: _ => refreshDebounce.restart()
        }
        onExited: monitorRestart.start()
    }
    Timer {
        id: monitorRestart
        interval: 5000
        onTriggered: monitorProc.running = true
    }
    Timer {
        id: refreshDebounce
        interval: 400
        onTriggered: root.refresh()
    }

    IpcHandler {
        target: "vpn"

        function toggle(): void { root.toggle(); }
        function connect(): void { root.connect(""); }
        function disconnect(): void { root.disconnect(); }
        function status(): string {
            return root.connected ? `connected: ${root.activeName}` : (root.busy ? `connecting: ${root.activatingName}` : "disconnected");
        }
    }
}
