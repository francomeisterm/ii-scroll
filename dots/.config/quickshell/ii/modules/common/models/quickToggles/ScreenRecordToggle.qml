import QtQuick
import qs.services
import qs.modules.common

// gpu-screen-recorder, focused output with desktop audio. Idea from caelestia-shell.
QuickToggleModel {
    name: Translation.tr("Record")
    toggled: Recorder.recording
    icon: Recorder.recording ? "stop_circle" : "screen_record"
    statusText: Recorder.recording ? Recorder.elapsedString : Translation.tr("Screen + audio")
    tooltipText: Recorder.recording ? Translation.tr("Stop recording") : Translation.tr("Record the focused screen with audio")
    mainAction: () => Recorder.toggleFullscreenRecording()
}
