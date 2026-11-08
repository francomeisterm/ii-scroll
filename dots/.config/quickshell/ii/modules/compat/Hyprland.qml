pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.I3

/**
 * Scroll (sway IPC) stand-in for the Quickshell.Hyprland singleton.
 *
 * Exposes the subset of the Hyprland API that ii uses, with Hyprland's semantics:
 * workspace `id` is the workspace NUMBER (not the sway con id), monitors have `id`,
 * `name` and `activeWorkspace`. Every refresh replaces the snapshot objects, so
 * bindings that read them re-evaluate.
 *
 * Raw state (sway JSON) is kept in `swayWorkspaces`, `swayOutputs` and `swayTree`
 * for HyprlandData, which turns it into hyprctl-shaped JSON.
 */
Singleton {
    id: root

    // sway IPC snapshots
    property var swayWorkspaces: []
    property var swayOutputs: []
    property var swayTree: null

    // Hyprland-like snapshots
    property var monitorList: []
    property var focusedMonitor: null
    property var focusedWorkspace: null
    property QtObject workspaces: QtObject {
        property var values: []
    }

    signal rawEvent(var event)

    function monitorFor(screen) {
        if (!screen)
            return null;
        return root.monitorList.find(m => m.name === screen.name) ?? null;
    }

    function refresh() {
        refreshTimer.restart();
    }

    // ---- Dispatch: translate the hl.dsp.* Lua strings ii uses into sway commands ----

    function _target(win) {
        // "address:0x<con id>" -> [con_id=<id>]
        const m = /address:0x([0-9a-fA-F]+)/.exec(win ?? "");
        return m ? `[con_id=${parseInt(m[1], 16)}] ` : "";
    }

    function _wsArg(ws) {
        const s = String(ws).replace(/^"|"$/g, "");
        if (s === "r+1" || s === "e+1" || s === "+1")
            return "next_on_output";
        if (s === "r-1" || s === "e-1" || s === "-1")
            return "prev_on_output";
        if (/^-?\d+$/.test(s))
            return `number ${s}`;
        return `"${s}"`;
    }

    function translate(cmd) {
        let m;
        if ((m = /hl\.dsp\.focus\(\{\s*workspace\s*=\s*("?[^,}"]+"?)\s*\}\)/.exec(cmd)))
            return `workspace ${_wsArg(m[1])}`;
        if ((m = /hl\.dsp\.focus\(\{\s*window\s*=\s*"([^"]+)"\s*\}\)/.exec(cmd)))
            return `${_target(m[1])}focus`;
        if ((m = /hl\.dsp\.window\.close\(\{\s*window\s*=\s*"([^"]+)"\s*\}\)/.exec(cmd)))
            return `${_target(m[1])}kill`;
        if ((m = /hl\.dsp\.window\.pin\(\{\s*window\s*=\s*"([^"]+)"\s*\}\)/.exec(cmd)))
            return `${_target(m[1])}sticky toggle`;
        if ((m = /hl\.dsp\.window\.move\(\{\s*workspace\s*=\s*([^,]+),.*window\s*=\s*"([^"]+)"/.exec(cmd)))
            return `${_target(m[2])}move container to workspace ${_wsArg(m[1].trim())}`;
        if ((m = /hl\.dsp\.window\.move\(\{\s*x\s*=\s*"([\d.]+)",\s*y\s*=\s*"([\d.]+)",.*window\s*=\s*"([^"]+)"/.exec(cmd)))
            return `${_target(m[3])}move position ${Math.round(parseFloat(m[1]))} ${Math.round(parseFloat(m[2]))}`;
        if (/hl\.dsp\.workspace\.toggle_special/.test(cmd))
            return "scratchpad show";
        if ((m = /hl\.dsp\.global\("quickshell:([^"]+)"\)/.exec(cmd))) {
            GlobalShortcutRegistry.trigger(m[1]);
            return "";
        }
        if (/hl\.config\(/.test(cmd))
            return ""; // Hyprland options (cursor warps etc.) have no Scroll equivalent
        return cmd; // assume it's already a sway command
    }

    function dispatch(cmd) {
        const swayCmd = root.translate(cmd);
        if (swayCmd.length === 0)
            return;
        I3.dispatch(swayCmd);
    }

    // ---- Refresh ----

    function _rebuild() {
        const outputs = root.swayOutputs.filter(o => o.active !== false && !o.name.startsWith("__"));
        const wsList = root.swayWorkspaces.filter(w => w.num >= 1 && w.num <= 100);

        let mons = outputs.map((o, i) => {
            const cur = wsList.find(w => w.output === o.name && w.visible);
            return {
                id: i,
                name: o.name,
                x: o.rect.x,
                y: o.rect.y,
                width: o.rect.width,
                height: o.rect.height,
                scale: o.scale,
                focused: o.focused,
                activeWorkspace: cur ? { id: cur.num, name: cur.name } : { id: 1, name: "1" },
                lastIpcObject: o
            };
        });
        // Windows per workspace number, for HyprlandWorkspace.toplevels (ii only reads
        // toplevel.wayland.fullscreen / activated, title and address from it)
        const winsByWs = {};
        function walk(node, wsNum) {
            if (!node)
                return;
            if (node.type === "workspace")
                wsNum = node.num ?? -1;
            if ((node.type === "con" || node.type === "floating_con") && (node.pid ?? 0) > 0) {
                (winsByWs[wsNum] = winsByWs[wsNum] ?? []).push({
                    address: node.id.toString(16),
                    title: node.name ?? "",
                    wayland: {
                        appId: node.app_id ?? node.window_properties?.class ?? "",
                        title: node.name ?? "",
                        fullscreen: (node.fullscreen_mode ?? 0) > 0,
                        activated: node.focused
                    }
                });
            }
            (node.nodes ?? []).forEach(n => walk(n, wsNum));
            (node.floating_nodes ?? []).forEach(n => walk(n, wsNum));
        }
        walk(root.swayTree, -1);

        let wss = wsList.map(w => {
            const mon = mons.find(m => m.name === w.output) ?? null;
            return {
                id: w.num,
                name: w.name,
                monitor: mon,
                active: w.visible,
                focused: w.focused,
                urgent: w.urgent,
                lastIpcObject: w,
                toplevels: { values: winsByWs[w.num] ?? [] },
                activate: function () { I3.dispatch(`workspace number ${w.num}`); }
            };
        });
        root.monitorList = mons;
        root.workspaces.values = wss;
        const fm = mons.find(m => m.focused) ?? mons[0] ?? null;
        if (JSON.stringify(fm) !== JSON.stringify(root.focusedMonitor))
            root.focusedMonitor = fm;
        const fw = wss.find(w => w.focused) ?? null;
        if (fw?.id !== root.focusedWorkspace?.id || fw?.monitor?.name !== root.focusedWorkspace?.monitor?.name)
            root.focusedWorkspace = fw;
    }

    Timer {
        id: refreshTimer
        interval: 15
        onTriggered: query.running = true
    }

    Process {
        id: query
        command: ["sh", "-c", 'printf \'{"ws":%s,"out":%s,"tree":%s}\' "$(scrollmsg -s \"${SWAYSOCK:-$SCROLLSOCK}\" -r -t get_workspaces)" "$(scrollmsg -s \"${SWAYSOCK:-$SCROLLSOCK}\" -r -t get_outputs)" "$(scrollmsg -s \"${SWAYSOCK:-$SCROLLSOCK}\" -r -t get_tree)"']
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text);
                    root.swayWorkspaces = data.ws;
                    root.swayOutputs = data.out;
                    root.swayTree = data.tree;
                    root._rebuild();
                } catch (e) {
                    console.warn("[compat/Hyprland] bad scrollmsg output:", e);
                }
            }
        }
    }

    I3IpcListener {
        subscriptions: ["workspace", "window", "output", "mode", "input"]
        onIpcEvent: event => {
            root.rawEvent({ name: event.type, data: event.data });
            if (event.type !== "input")
                root.refresh();
        }
    }

    Connections {
        target: Quickshell
        function onScreensChanged() { root.refresh(); }
    }

    Component.onCompleted: query.running = true
}
