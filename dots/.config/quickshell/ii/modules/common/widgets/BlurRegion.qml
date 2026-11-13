import QtQuick
import Quickshell

/**
 * Scroll port: a blur region that follows an item, for `BackgroundEffect.blurRegion`.
 * Hyprland blurs ii's layers with layer rules; Scroll only blurs what the client asks for
 * (ext-background-effect-v1), so each panel passes the shape of its background.
 * Region.item only notices the item's own x/y/size, so this walks the parents instead
 * (the binding re-runs when any of them moves). Empty when there is no target.
 */
Region {
    id: root
    property Item target: null
    property bool active: true
    readonly property bool shown: active && target !== null && target.visible
    readonly property point origin: {
        let px = 0, py = 0;
        for (let i = root.target; i && i.parent; i = i.parent) {
            px += i.x;
            py += i.y;
        }
        return Qt.point(px, py);
    }
    x: shown ? Math.round(origin.x) : 0
    y: shown ? Math.round(origin.y) : 0
    width: shown ? Math.ceil(target.width) : 0
    height: shown ? Math.ceil(target.height) : 0
    radius: shown ? Math.min(target.radius ?? 0, Math.floor(Math.min(target.width, target.height) / 2)) : 0
}
