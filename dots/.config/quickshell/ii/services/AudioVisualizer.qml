pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

/**
 * One cava process shared by every screen's wallpaper visualizer
 * (idea from caelestia-shell's background visualiser).
 * Screens call setActive(screenName, bool); cava only runs while at least one
 * screen wants it and, with onlyWhenPlaying, while some MPRIS player is playing.
 * values: bar heights in 0..1, bass first.
 */
Singleton {
    id: root

    readonly property var config: Config.options.background.visualizer
    property var activeScreens: ({})
    readonly property bool anyScreenActive: Object.values(activeScreens).some(v => v)
    readonly property bool anyPlaying: Mpris.players.values.some(p => p.isPlaying)
    readonly property bool running: (config?.enable ?? false) && anyScreenActive && (!(config?.onlyWhenPlaying ?? true) || anyPlaying)
    property list<real> values: []

    function setActive(screenName: string, active: bool): void {
        if ((root.activeScreens[screenName] ?? false) === active)
            return;
        const copy = Object.assign({}, root.activeScreens);
        copy[screenName] = active;
        root.activeScreens = copy;
    }

    Process {
        id: cavaProc
        running: root.running
        command: ["cava", "-p", `${FileUtils.trimFileProtocol(Directories.scriptPath)}/cava/background_config.txt`]
        onRunningChanged: {
            if (!running)
                root.values = [];
        }
        stdout: SplitParser {
            onRead: data => {
                const vals = [];
                for (const p of data.split(";")) {
                    if (p.length === 0)
                        continue;
                    const v = parseInt(p, 10);
                    if (!isNaN(v))
                        vals.push(Math.min(1, v / 1000));
                }
                root.values = vals;
            }
        }
    }
}
