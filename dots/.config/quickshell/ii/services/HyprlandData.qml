pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.compat

/**
 * Scroll port: same API as upstream's HyprlandData, but built from the sway IPC
 * snapshots held by the compat Hyprland singleton (get_tree / get_workspaces /
 * get_outputs) instead of `hyprctl ... -j`. Objects are shaped like hyprctl's JSON.
 *
 * Window "address" is "0x" + the sway con id in hex, so the compat dispatcher can
 * turn "address:0x.." back into [con_id=..].
 */
Singleton {
    id: root
    property var windowList: []
    property var addresses: []
    property var windowByAddress: ({})
    property var workspaces: []
    property var workspaceIds: []
    property var workspaceById: ({})
    property var activeWorkspace: null
    property var monitors: []
    property var layers: ({})

    // Convenient stuff

    // Quickshell's wlr-foreign-toplevel Toplevel has no con id, so match on
    // app id + title, preferring the activated/focused state on ties.
    function clientForToplevel(toplevel) {
        if (!toplevel)
            return null;
        const candidates = root.windowList.filter(w => w.class === toplevel.appId && w.title === toplevel.title);
        if (candidates.length <= 1)
            return candidates[0] ?? null;
        return candidates.find(w => w.focused === toplevel.activated) ?? candidates[0];
    }

    function addressForToplevel(toplevel) {
        return root.clientForToplevel(toplevel)?.address ?? "";
    }

    function toplevelsForWorkspace(workspace) {
        return ToplevelManager.toplevels.values.filter(toplevel => {
            return root.clientForToplevel(toplevel)?.workspace?.id === workspace;
        });
    }

    function hyprlandClientsForWorkspace(workspace) {
        return root.windowList.filter(win => win.workspace.id === workspace);
    }

    function biggestWindowForWorkspace(workspaceId) {
        const windowsInThisWorkspace = root.windowList.filter(w => w.workspace.id == workspaceId);
        return windowsInThisWorkspace.reduce((maxWin, win) => {
            const maxArea = (maxWin?.size?.[0] ?? 0) * (maxWin?.size?.[1] ?? 0);
            const winArea = (win?.size?.[0] ?? 0) * (win?.size?.[1] ?? 0);
            return winArea > maxArea ? win : maxWin;
        }, null);
    }

    function updateAll() {
        Hyprland.refresh();
    }

    // Internals

    function _rebuild() {
        const outputs = Hyprland.swayOutputs.filter(o => o.active !== false && !o.name.startsWith("__"));
        const swayWs = Hyprland.swayWorkspaces;

        // Monitors
        const mons = outputs.map((o, i) => {
            const cur = swayWs.find(w => w.output === o.name && w.visible);
            const r = cur?.rect ?? o.rect;
            return {
                id: i,
                name: o.name,
                description: `${o.make ?? ""} ${o.model ?? ""}`.trim(),
                x: o.rect.x,
                y: o.rect.y,
                width: Math.round(o.rect.width * o.scale),
                height: Math.round(o.rect.height * o.scale),
                scale: o.scale,
                transform: 0,
                focused: o.focused,
                reserved: [r.x - o.rect.x, r.y - o.rect.y, (o.rect.x + o.rect.width) - (r.x + r.width), (o.rect.y + o.rect.height) - (r.y + r.height)],
                activeWorkspace: cur ? { id: cur.num, name: cur.name } : { id: -1, name: "" },
                specialWorkspace: { id: 0, name: "" },
                hdr: o.hdr ?? false
            };
        });
        const monIdByName = {};
        mons.forEach(m => monIdByName[m.name] = m.id);

        // Windows: walk the tree, remembering the enclosing output and workspace
        const wins = [];
        let focusOrder = 0;
        function walk(node, outName, ws) {
            if (!node)
                return;
            if (node.type === "output")
                outName = node.name;
            if (node.type === "workspace")
                ws = node;
            const isWin = (node.type === "con" || node.type === "floating_con") && (node.app_id !== undefined || node.window_properties !== undefined) && (node.pid ?? 0) > 0;
            if (isWin) {
                const scratch = ws?.name === "__i3_scratch";
                const wsNum = scratch ? -99 : (ws?.num ?? -1);
                wins.push({
                    address: `0x${node.id.toString(16)}`,
                    conId: node.id,
                    mapped: true,
                    hidden: !node.visible,
                    at: [node.rect.x, node.rect.y],
                    size: [node.rect.width, node.rect.height],
                    workspace: { id: wsNum, name: scratch ? "special:scratchpad" : (ws?.name ?? "") },
                    floating: node.type === "floating_con",
                    pseudo: false,
                    monitor: monIdByName[outName] ?? -1,
                    class: node.app_id ?? node.window_properties?.class ?? "",
                    title: node.name ?? "",
                    initialClass: node.app_id ?? node.window_properties?.class ?? "",
                    initialTitle: node.name ?? "",
                    pid: node.pid,
                    xwayland: node.shell === "xwayland",
                    pinned: node.sticky ?? false,
                    fullscreen: (node.fullscreen_mode ?? 0) > 0 ? 2 : 0,
                    fullscreenClient: node.fullscreen_mode ?? 0,
                    focused: node.focused,
                    focusHistoryID: node.focused ? 0 : ++focusOrder,
                    swallowing: "0x0",
                    tags: []
                });
            }
            (node.nodes ?? []).forEach(n => walk(n, outName, ws));
            (node.floating_nodes ?? []).forEach(n => walk(n, outName, ws));
        }
        walk(Hyprland.swayTree, "", null);

        root.windowList = wins;
        const byAddr = {};
        wins.forEach(w => byAddr[w.address] = w);
        root.windowByAddress = byAddr;
        root.addresses = wins.map(w => w.address);

        // Workspaces
        const wss = swayWs.filter(w => w.num >= 1 && w.num <= 100).map(w => {
            const inWs = wins.filter(x => x.workspace.id === w.num);
            const focusedWin = inWs.find(x => x.focused) ?? inWs[0];
            return {
                id: w.num,
                name: w.name,
                monitor: w.output,
                monitorID: monIdByName[w.output] ?? -1,
                windows: inWs.length,
                hasfullscreen: inWs.some(x => x.fullscreen > 0),
                lastwindow: focusedWin?.address ?? "0x0",
                lastwindowtitle: focusedWin?.title ?? ""
            };
        });
        root.workspaces = wss;
        const byId = {};
        wss.forEach(w => byId[w.id] = w);
        root.workspaceById = byId;
        root.workspaceIds = wss.map(w => w.id);
        const fw = swayWs.find(w => w.focused);
        root.activeWorkspace = fw ? (byId[fw.num] ?? { id: fw.num, name: fw.name, monitor: fw.output }) : null;

        root.monitors = mons;
    }

    Connections {
        target: Hyprland
        function onSwayTreeChanged() {
            root._rebuild();
        }
    }

    Component.onCompleted: {
        if (Hyprland.swayTree)
            root._rebuild();
    }
}
