pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.compat

/**
 * Scroll port: keybinds for the cheatsheet, parsed from the running config
 * (`scrollmsg -t get_config`) instead of `hyprctl binds -j`.
 *
 * Output objects mimic hyprctl's: { key, modmask, description: "Category: text" }.
 * Category = the nearest preceding "### Heading" comment. Text = a "#! text" comment
 * directly above the bindsym if there is one, otherwise a cleaned-up command.
 * Includes are not followed (get_config returns the main file only).
 */
Singleton {
    id: root
    property var keybinds: []
    property var keybindCategories: []

    // Hyprland modmask bits, as CheatsheetKeybindsCategory decodes them
    readonly property var modBits: ({
        "shift": 1, "lock": 2, "caps": 2, "ctrl": 4, "control": 4,
        "alt": 8, "mod1": 8, "mod2": 16, "mod3": 32,
        "mod4": 64, "super": 64, "mod5": 128
    })

    function describe(cmd) {
        let m;
        if ((m = /ipc call shortcut (?:trigger|press) (\S+)/.exec(cmd)))
            return m[1].replace(/([a-z])([A-Z])/g, "$1 $2").toLowerCase();
        if ((m = /ipc call (\S+) (\S+)/.exec(cmd)))
            return `${m[1]} ${m[2]}`;
        cmd = cmd.replace(/^exec\s+(--no-startup-id\s+)?/, "").replace(/^(uwsm app --|\$app)\s+/, "");
        return cmd.length > 60 ? cmd.substring(0, 57) + "..." : cmd;
    }

    function parse(text) {
        const vars = {};
        const binds = [];
        let category = "";
        let pendingDesc = "";
        const lines = text.split("\n");
        for (let raw of lines) {
            const line = raw.trim();
            let m;
            if ((m = /^###\s*(.+)$/.exec(line))) {
                category = m[1].trim();
                pendingDesc = "";
                continue;
            }
            if ((m = /^#!\s*(.+)$/.exec(line))) {
                pendingDesc = m[1].trim();
                continue;
            }
            if ((m = /^set\s+(\$\S+)\s+(.+)$/.exec(line))) {
                vars[m[1]] = m[2].trim();
                continue;
            }
            if ((m = /^bind(?:sym|code)\s+((?:--\S+\s+)*)(\S+)\s+(.+)$/.exec(line))) {
                if (m[1].includes("--release")) { pendingDesc = ""; continue; }
                let combo = m[2];
                for (const v in vars)
                    combo = combo.split(v).join(vars[v]);
                const parts = combo.split("+");
                const key = parts.pop();
                let modmask = 0;
                parts.forEach(p => modmask |= (root.modBits[p.toLowerCase()] ?? 0));
                let cmd = m[3];
                for (const v in vars)
                    cmd = cmd.split(v).join(vars[v]);
                const text = pendingDesc.length > 0 ? pendingDesc : root.describe(cmd);
                binds.push({
                    key: key,
                    modmask: modmask,
                    description: category.length > 0 ? `${category}: ${text}` : text,
                    dispatcher: "exec",
                    arg: cmd
                });
            }
            if (line.length > 0 && !line.startsWith("#"))
                pendingDesc = "";
        }
        return binds;
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name == "configreloaded")
                getKeybinds.running = true;
        }
    }

    Process {
        id: getKeybinds
        running: true
        command: ["scrollmsg", "-r", "-t", "get_config"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.keybinds = root.parse(JSON.parse(text).config ?? "");
                    var groups = [];
                    for (var i = 0; i < root.keybinds.length; i++) {
                        var bind = root.keybinds[i].description;
                        var group = bind.substring(0, bind.indexOf(":"));
                        if (!groups.includes(group) && group.length > 0)
                            groups.push(group);
                    }
                    root.keybindCategories = groups;
                } catch (e) {
                    console.error("[CheatsheetKeybinds] Error parsing keybinds:", e);
                }
            }
        }
    }
}
