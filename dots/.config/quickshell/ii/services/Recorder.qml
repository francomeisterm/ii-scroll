pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * gpu-screen-recorder state + controls (idea from caelestia-shell's Recorder service).
 * The actual capture is done by scripts/videos/record.sh, so keybinds, the region selector
 * and this service all share one set of settings (Config.options.screenRecord).
 */
Singleton {
    id: root

    property bool recording: false
    property bool replayActive: false
    property int elapsedSeconds: 0
    readonly property string elapsedString: {
        const m = Math.floor(elapsedSeconds / 60);
        const s = elapsedSeconds % 60;
        return `${m}:${s.toString().padStart(2, "0")}`;
    }
    readonly property int replaySeconds: Config.options?.screenRecord?.replaySeconds ?? 30

    function load() {} // Force singleton instantiation (IPC + polling)

    function run(args) {
        Quickshell.execDetached([Directories.recordScriptPath, ...args]);
        pollSoon.restart();
    }
    function toggleFullscreenRecording() { run(["--fullscreen", "--sound"]); }
    function stopRecording() { run(["--stop"]); }
    function toggleReplay() { run(["--replay"]); }
    function saveReplay() { run(["--save-replay"]); }

    onRecordingChanged: {
        if (recording) {
            elapsedSeconds = 0;
            Toasts.show(Translation.tr("Recording started"), "screen_record");
        } else {
            Toasts.show(Translation.tr("Recording stopped"), "stop_circle");
        }
    }
    onReplayActiveChanged: {
        if (replayActive) Toasts.show(Translation.tr("Replay buffer on · Alt+F10 saves the last %1s").arg(replaySeconds), "history");
    }

    Timer {
        id: elapsedTimer
        interval: 1000
        repeat: true
        running: root.recording
        onTriggered: root.elapsedSeconds += 1
    }

    // Poll the process list; cheap, and catches recordings started outside the shell (keybinds)
    Timer {
        interval: 2000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: if (!pollProc.running) pollProc.running = true
    }
    Timer {
        id: pollSoon
        interval: 600
        onTriggered: if (!pollProc.running) pollProc.running = true
    }
    Process {
        id: pollProc
        command: ["pgrep", "-a", "-f", "^gpu-screen-recorder"]
        stdout: StdioCollector {
            id: pollCollector
            onStreamFinished: {
                const lines = pollCollector.text.split("\n").filter(l => l.length > 0);
                const isReplay = l => / -r [0-9]/.test(l);
                root.recording = lines.some(l => !isReplay(l));
                root.replayActive = lines.some(isReplay);
            }
        }
    }

    IpcHandler {
        target: "recorder"

        function toggle(): void { root.toggleFullscreenRecording(); }
        function stop(): void { root.stopRecording(); }
        function toggleReplay(): void { root.toggleReplay(); }
        function saveReplay(): void { root.saveReplay(); }
    }
}
