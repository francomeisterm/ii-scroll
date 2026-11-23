import QtQuick
import qs.services
import qs.modules.common

// gpu-screen-recorder replay buffer ("save the last N seconds"). Idea from caelestia-shell.
QuickToggleModel {
    name: Translation.tr("Replay")
    toggled: Recorder.replayActive
    icon: "history"
    statusText: Recorder.replayActive ? Translation.tr("Last %1s · click to save").arg(Recorder.replaySeconds) : Translation.tr("Off")
    tooltipText: Translation.tr("Icon: replay buffer on/off | Click or Alt+F10: save the last %1s").arg(Recorder.replaySeconds)
    mainAction: () => Recorder.toggleReplay()
    altAction: () => Recorder.saveReplay()
}
