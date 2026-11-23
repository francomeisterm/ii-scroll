pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Small transient status popups for system events, separate from notifications
 * (idea from caelestia-shell's utilities/toasts). Shown by modules/ii/toasts.
 *
 * Toasts.show(text, icon, [timeoutMs])
 */
Singleton {
    id: root

    property list<var> toasts: []
    property int nextId: 0
    readonly property bool enabled: Config.options?.toasts?.enable ?? true
    readonly property int defaultTimeout: Config.options?.toasts?.timeout ?? 2500
    readonly property int maxToasts: 4

    // Ignore state settling right after the shell (re)loads, e.g. a persisted keep-awake
    property bool armed: false
    Timer {
        running: true
        interval: 3000
        onTriggered: root.armed = true
    }

    function show(text, icon, timeout = 0) {
        if (!root.enabled || !root.armed) return;
        const toast = {
            id: root.nextId++,
            text: text,
            icon: icon || "info",
            expiresAt: Date.now() + (timeout > 0 ? timeout : root.defaultTimeout)
        };
        // Same text again: just refresh it instead of stacking duplicates
        let list = root.toasts.filter(t => t.text !== text);
        list.push(toast);
        while (list.length > root.maxToasts) list.shift();
        root.toasts = list;
        expiryTimer.restart();
    }

    function dismiss(id) {
        root.toasts = root.toasts.filter(t => t.id !== id);
    }

    Timer {
        id: expiryTimer
        interval: 250
        repeat: true
        running: root.toasts.length > 0
        onTriggered: {
            const now = Date.now();
            if (root.toasts.some(t => t.expiresAt <= now))
                root.toasts = root.toasts.filter(t => t.expiresAt > now);
        }
    }

    // ---- Event sources ----

    Connections {
        target: Idle
        function onInhibitChanged() {
            root.show(Idle.inhibit ? Translation.tr("Keep awake on") : Translation.tr("Keep awake off"),
                Idle.inhibit ? "coffee" : "bedtime", 0);
        }
    }

    // Default output device changed (skip the initial assignment at startup)
    property string lastSinkName: ""
    Connections {
        target: Audio
        function onSinkChanged() {
            const sink = Audio.sink;
            if (!sink) return;
            if (root.lastSinkName !== "" && root.lastSinkName !== sink.name)
                root.show(Translation.tr("Output: %1").arg(Audio.friendlyDeviceName(sink)), "speaker", 0);
            root.lastSinkName = sink.name;
        }
    }
    Component.onCompleted: root.lastSinkName = Audio.sink?.name ?? ""

    IpcHandler {
        target: "toast"

        function push(text: string, icon: string): void {
            root.show(text, icon, 0);
        }
    }
}
