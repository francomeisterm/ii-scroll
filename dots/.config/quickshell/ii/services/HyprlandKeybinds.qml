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
 * Files pulled in with `include` are read too (get_config returns the main file only).
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
                if (m[1].includes("--release")) continue;
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
                // Only the bind right after a "#!" line gets listed (like Hyprland's bindd);
                // undescribed alternates (Super+T vs Super+Enter...) are hidden from the cheatsheet.
                const text = pendingDesc;
                binds.push({
                    key: key,
                    modmask: modmask,
                    description: text.length === 0 ? "" : (category.length > 0 ? `${category}: ${text}` : text),
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
        // Main config from IPC, then every `include` file it names (get_config has the main file only)
        command: ["sh", "-c", 'cfg="$(scrollmsg -s "${SWAYSOCK:-$SCROLLSOCK}" -r -t get_config | jq -r .config)"; printf "%s\\n" "$cfg"; printf "%s\\n" "$cfg" | sed -nE "s/^[[:space:]]*include[[:space:]]+//p" | while read -r f; do f="${f/#\\~/$HOME}"; case "$f" in /*) ;; *) f="$HOME/.config/scroll/$f" ;; esac; cat "$f" 2>/dev/null; done']

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.keybinds = root.parse(text);
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
