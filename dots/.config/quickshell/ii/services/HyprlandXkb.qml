pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.compat
import qs.modules.common

/**
 * Exposes the active Hyprland Xkb keyboard layout name and code for indicators.
 */
Singleton {
    id: root
    // You can read these
    property list<string> layoutCodes: []
    property var cachedLayoutCodes: ({})
    property string currentLayoutName: ""
    property string currentLayoutCode: ""
    // For the service
    property var baseLayoutFilePath: "/usr/share/X11/xkb/rules/base.lst"
    property bool needsLayoutRefresh: false

    // Update the layout code according to the layout name (Hyprland gives the name not the code)
    onCurrentLayoutNameChanged: root.updateLayoutCode()
    function updateLayoutCode() {
        if (cachedLayoutCodes.hasOwnProperty(currentLayoutName)) {
            root.currentLayoutCode = cachedLayoutCodes[currentLayoutName];
        } else {
            getLayoutProc.running = true;
        }
    }

    // Get the layout code from the base.lst file by grabbing the line with the current layout name
    Process {
        id: getLayoutProc
        command: ["cat", root.baseLayoutFilePath]

        stdout: StdioCollector {
            id: layoutCollector

            onStreamFinished: {
                const lines = layoutCollector.text.split("\n");
                const targetDescription = root.currentLayoutName;
                const foundLine = lines.find(line => {
                    // Skip comment lines and empty lines
                    if (!line.trim() || line.trim().startsWith('!'))
                        return false;

                    // Match layout: (whitespace + ) key + whitespace + description
                    const matchLayout = line.match(/^\s*(\S+)\s+(.+)$/);
                    if (matchLayout && matchLayout[2] === targetDescription) {
                        root.cachedLayoutCodes[matchLayout[2]] = matchLayout[1];
                        root.currentLayoutCode = matchLayout[1];
                        return true;
                    }

                    // Match variant: (whitespace + ) variant + whitespace + key + whitespace + description
                    const matchVariant = line.match(/^\s*(\S+)\s+(\S+)\s+(.+)$/);
                    if (matchVariant && matchVariant[3] === targetDescription) {
                        const complexLayout = matchVariant[2] + matchVariant[1];
                        root.cachedLayoutCodes[matchVariant[3]] = complexLayout;
                        root.currentLayoutCode = complexLayout;
                        return true;
                    }
                    
                    return false;
                });
                // console.log("[HyprlandXkb] Found line:", foundLine);
                // console.log("[HyprlandXkb] Layout:", root.currentLayoutName, "| Code:", root.currentLayoutCode);
                // console.log("[HyprlandXkb] Cached layout codes:", JSON.stringify(root.cachedLayoutCodes, null, 2));
            }
        }
    }

    // Scroll port: layouts come from sway IPC get_inputs (names, not codes; the code is
    // looked up from base.lst by updateLayoutCode()), refreshed on "input" events.
    Process {
        id: fetchLayoutsProc
        running: true
        command: ["sh", "-c", 'scrollmsg -s "${SWAYSOCK:-$SCROLLSOCK}" -r -t get_inputs']

        stdout: StdioCollector {
            id: devicesCollector
            onStreamFinished: {
                try {
                    const inputs = JSON.parse(devicesCollector.text);
                    const keyboards = inputs.filter(i => i.type === "keyboard" && (i.xkb_layout_names ?? []).length > 0);
                    // Prefer a keyboard with several layouts, else the first one
                    const kb = keyboards.find(k => k.xkb_layout_names.length > 1) ?? keyboards[0];
                    if (!kb)
                        return;
                    root.layoutCodes = kb.xkb_layout_names;
                    if (root.currentLayoutName !== kb.xkb_active_layout_name) {
                        root.currentLayoutName = kb.xkb_active_layout_name ?? "";
                        if (root.layoutCodes.length > 1)
                            Config.options.osk.layout = root.currentLayoutName.split(" (")[0];
                    }
                } catch (e) {
                    console.warn("[HyprlandXkb] bad get_inputs output:", e);
                }
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "input")
                fetchLayoutsProc.running = true;
        }
    }
}
