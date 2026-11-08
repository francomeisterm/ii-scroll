pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.I3

/**
 * Scroll port of upstream's "Configs Hyprland" service.
 *
 * Upstream writes Hyprland keywords into a Lua overrides file. Scroll has no such
 * thing, so the Hyprland keys ii toggles are translated into runtime Scroll commands,
 * and the overrides are kept in memory (they don't survive a Scroll reload or relogin).
 * Keys with no Scroll equivalent are remembered (so toggles show the right state) but
 * otherwise ignored. Resetting a key that changed something runs `reload`, which
 * restores ~/.config/scroll/config, then re-applies the remaining overrides.
 */
Singleton {
    id: root

    signal reloaded()

    // key -> value currently overridden by the shell
    property var overrides: ({})

    // Values Hyprland would report when nothing is overridden (for HyprlandConfigOption)
    readonly property var defaults: ({
        "animations:enabled": 1,
        "decoration:blur:enabled": 1,
        "decoration:shadow:enabled": 1,
        "general:allow_tearing": 0
    })

    function _bool(v) {
        return !(v === 0 || v === "0" || v === false || v === "false" || v === "no");
    }

    // Returns a Scroll command for a Hyprland key, or "" if there's no equivalent.
    function translate(key, value) {
        switch (key) {
        case "general:gaps_in":
            return `gaps inner all set ${parseInt(value)}`;
        case "general:gaps_out":
            return `gaps outer all set ${parseInt(value)}`;
        case "general:border_size":
            return `[all] border pixel ${parseInt(value)}`;
        case "decoration:blur:enabled":
            return `[all] window_blur ${root._bool(value) ? "on" : "off"}`;
        case "general:allow_tearing":
            return `[all] allow_tearing ${root._bool(value) ? "yes" : "no"}`;
        default:
            return "";
        }
    }

    function valueOf(key) {
        return (key in root.overrides) ? root.overrides[key] : (root.defaults[key] ?? null);
    }

    function isSet(key) {
        return key in root.overrides;
    }

    function _apply(entries) {
        const cmds = [];
        for (let key in entries) {
            const c = root.translate(key, entries[key]);
            if (c.length > 0)
                cmds.push(c);
        }
        if (cmds.length > 0)
            I3.dispatch(cmds.join("; "));
    }

    function set(key: string, value: var) {
        let e = {};
        e[key] = value;
        root.setMany(e);
    }

    function setMany(entries: var) {
        let next = Object.assign({}, root.overrides);
        for (let key in entries)
            next[key] = entries[key];
        root.overrides = next;
        root._apply(entries);
        root.reloaded();
    }

    function reset(key: string) {
        root.resetMany([key]);
    }

    function resetMany(keys: list<string>) {
        let next = Object.assign({}, root.overrides);
        let needReload = false;
        for (let i = 0; i < keys.length; i++) {
            if (keys[i] in next && root.translate(keys[i], next[keys[i]]).length > 0)
                needReload = true;
            delete next[keys[i]];
        }
        root.overrides = next;
        if (needReload) {
            I3.dispatch("reload");
            reapplyTimer.restart();
        } else {
            root.reloaded();
        }
    }

    Timer {
        id: reapplyTimer
        interval: 300
        onTriggered: {
            root._apply(root.overrides);
            root.reloaded();
        }
    }
}
