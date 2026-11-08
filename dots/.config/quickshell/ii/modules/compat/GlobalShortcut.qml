import QtQuick
import Quickshell

/**
 * Drop-in for Quickshell.Hyprland's GlobalShortcut. Triggered over IPC through
 * GlobalShortcutRegistry (target "shortcut") instead of hyprland-global-shortcuts.
 */
Scope {
    id: root

    property string name: ""
    property string description: ""
    property string appid: "quickshell"

    signal pressed()
    signal released()

    Component.onCompleted: GlobalShortcutRegistry.register(root)
    Component.onDestruction: GlobalShortcutRegistry.unregister(root)
}
