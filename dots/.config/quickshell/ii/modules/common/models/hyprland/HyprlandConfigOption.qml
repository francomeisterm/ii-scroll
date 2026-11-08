pragma ComponentBehavior: Bound
import QtQml
import QtQuick
import qs.services
import "../"

/**
 * Scroll port: reads the value from HyprlandConfig's in-memory overrides instead of
 * `hyprctl getoption`.
 */
NestableObject {
    id: root

    required property string key
    property bool fetching: false
    property bool set
    property var value

    Component.onCompleted: fetch()

    Connections {
        target: HyprlandConfig
        function onReloaded() {
            root.fetch();
        }
    }

    function fetch() {
        root.set = HyprlandConfig.isSet(root.key);
        root.value = HyprlandConfig.valueOf(root.key);
    }

    function setValue(newValue) {
        HyprlandConfig.set(root.key, newValue)
    }

    function reset() {
        HyprlandConfig.reset(root.key)
    }
}
