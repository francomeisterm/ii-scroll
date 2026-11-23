import QtQuick
import qs.services
import qs.modules.common

// gpu-screen-recorder replay buffer ("save the last N seconds"). Idea from caelestia-shell.
QuickToggleModel {
    name: Translation.tr("Replay")
    toggled: Recorder.replayActive
    icon: "history"
    statusText: Recorder.replayActive ? Translation.tr("Last %1s · right-click saves").arg(Recorder.replaySeconds) : Translation.tr("Off")
    tooltipText: Translation.tr("Replay buffer | Right-click or Alt+F10 to save the last %1s").arg(Recorder.replaySeconds)
    mainAction: () => Recorder.toggleReplay()
    altAction: () => Recorder.saveReplay()
}
