pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
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

    // Saved recordings (newest first), idea from caelestia-shell's RecordingList.
    // [{ name, path, mtime (ms), size (bytes), thumb (path or "") }]
    property list<var> recordings: []
    readonly property string recordingsDir: {
        const path = Config.options?.screenRecord?.savePath || FileUtils.trimFileProtocol(Directories.videos);
        return path.replace(/^~(?=\/|$)/, FileUtils.trimFileProtocol(Directories.home));
    }
    readonly property string thumbnailDir: FileUtils.trimFileProtocol(`${Directories.cache}/media/recordings`)
    readonly property int maxListed: 50
    onRecordingsDirChanged: refreshRecordings()

    function load() {} // Force singleton instantiation (IPC + polling)

    function run(args) {
        Quickshell.execDetached([Directories.recordScriptPath, ...args]);
        pollSoon.restart();
    }
    function toggleFullscreenRecording() { run(["--fullscreen", "--sound"]); }
    function stopRecording() { run(["--stop"]); }
    function toggleReplay() { run(["--replay"]); }
    function saveReplay() {
        run(["--save-replay"]);
        refreshAfterSave.restart();
    }

    function refreshRecordings() {
        if (listProc.running) listQueued = true;
        else listProc.running = true;
    }
    function openRecording(path) {
        Quickshell.execDetached(["xdg-open", path]);
    }
    function openFolder() {
        Quickshell.execDetached(["xdg-open", root.recordingsDir]);
    }
    // Copies the file itself (text/uri-list), so it pastes as an attachment in chat apps/browsers
    function copyRecording(path) {
        Quickshell.execDetached(["bash", "-c", 'printf "file://%s\\n" "$1" | wl-copy -t text/uri-list', "bash", path]);
        Toasts.show(Translation.tr("Copied · paste to attach"), "content_copy");
    }
    function deleteRecording(path) {
        trashProc.command = ["gio", "trash", path];
        trashProc.running = true;
    }

    onRecordingChanged: {
        if (recording) {
            elapsedSeconds = 0;
            Toasts.show(Translation.tr("Recording started"), "screen_record");
        } else {
            Toasts.show(Translation.tr("Recording stopped"), "stop_circle");
            refreshAfterSave.restart();
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

    // ---- Recording list ----
    property bool listQueued: false
    Timer {
        id: refreshAfterSave
        interval: 2000 // let gpu-screen-recorder finish writing the file
        onTriggered: root.refreshRecordings()
    }
    Process {
        id: listProc
        command: ["bash", "-c", `
            dir="$1"; thumbs="$2"; max="$3"
            mkdir -p "$thumbs"
            find "$dir" -maxdepth 1 -type f \\( -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.webm' -o -iname '*.mov' \\) \\
                -printf '%T@\\t%s\\t%p\\n' 2>/dev/null | sort -rn | head -n "$max" |
            while IFS=$'\\t' read -r t s p; do
                th="$thumbs/$(basename "$p").jpg"
                [ "$th" -nt "$p" ] || ffmpegthumbnailer -s 256 -q 6 -i "$p" -o "$th" >/dev/null 2>&1 || rm -f "$th"
                [ -s "$th" ] || th=""
                printf '%s\\t%s\\t%s\\t%s\\n' "$t" "$s" "$p" "$th"
            done
        `, "bash", root.recordingsDir, root.thumbnailDir, `${root.maxListed}`]
        stdout: StdioCollector {
            id: listCollector
            onStreamFinished: {
                root.recordings = listCollector.text.split("\n").filter(l => l.length > 0).map(l => {
                    const [t, s, p, th] = l.split("\t");
                    return { name: p.split("/").pop(), path: p, mtime: parseFloat(t) * 1000, size: Number(s), thumb: th ?? "" };
                });
            }
        }
        onExited: {
            if (root.listQueued) {
                root.listQueued = false;
                listProc.running = true;
            }
        }
    }
    Process {
        id: trashProc
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) Toasts.show(Translation.tr("Moved to trash"), "delete");
            else Toasts.show(Translation.tr("Could not delete the recording"), "error");
            root.refreshRecordings();
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
