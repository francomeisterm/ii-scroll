pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Scroll has no hyprland-global-shortcuts protocol, so compat GlobalShortcut objects
 * register here and the compositor triggers them over Quickshell IPC:
 *
 *   bindsym $mod+Tab exec qs -c ii ipc call shortcut trigger overviewWorkspacesToggle
 *   bindsym $mod+x exec qs -c ii ipc call shortcut press workspaceNumber
 *   bindsym --release $mod+x exec qs -c ii ipc call shortcut release workspaceNumber
 */
Singleton {
    id: root

    property list<QtObject> shortcuts: []

    function register(s) {
        if (root.shortcuts.indexOf(s) === -1)
            root.shortcuts.push(s);
    }

    function unregister(s) {
        const i = root.shortcuts.indexOf(s);
        if (i !== -1)
            root.shortcuts.splice(i, 1);
    }

    function _matching(name) {
        return root.shortcuts.filter(s => s && s.name === name);
    }

    function press(name) {
        const list = root._matching(name);
        list.forEach(s => s.pressed());
        return list.length;
    }

    function release(name) {
        const list = root._matching(name);
        list.forEach(s => s.released());
        return list.length;
    }

    function trigger(name) {
        const list = root._matching(name);
        list.forEach(s => {
            s.pressed();
            s.released();
        });
        return list.length;
    }

    IpcHandler {
        target: "shortcut"

        function press(name: string): string {
            return root.press(name) > 0 ? "ok" : `no shortcut named ${name}`;
        }
        function release(name: string): string {
            return root.release(name) > 0 ? "ok" : `no shortcut named ${name}`;
        }
        function trigger(name: string): string {
            return root.trigger(name) > 0 ? "ok" : `no shortcut named ${name}`;
        }
        function list(): string {
            return [...new Set(root.shortcuts.map(s => s.name))].sort().join("\n");
        }
    }
}
