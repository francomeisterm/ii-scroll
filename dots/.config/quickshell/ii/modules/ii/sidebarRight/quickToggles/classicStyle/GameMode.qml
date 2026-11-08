import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.modules.common.models.quickToggles
import Quickshell
import Quickshell.Io

QuickToggleButton {
    id: root
    buttonIcon: "gamepad"

    // Scroll port: same as the android-style toggle, through HyprlandConfig
    GameModeToggle {
        id: gameModeModel
    }
    toggled: gameModeModel.toggled
    onClicked: gameModeModel.mainAction()
    StyledToolTip {
        text: Translation.tr("Game mode")
    }
}