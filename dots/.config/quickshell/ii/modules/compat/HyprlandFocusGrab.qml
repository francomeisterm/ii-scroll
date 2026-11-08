pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

/**
 * Drop-in for Quickshell.Hyprland's HyprlandFocusGrab (hyprland-focus-grab-v1), which
 * Scroll doesn't have.
 *
 * While active, a transparent full-screen layer surface (Top layer) on every screen
 * catches clicks. Its input mask has holes where the grabbed windows are, so those
 * stay clickable. A click that lands on the catcher (= outside every grabbed window)
 * emits cleared(), like Hyprland does when focus leaves the grab.
 *
 * The holes are estimated from each window's anchors, margins and size, and extended
 * to the anchored screen edge. That errs on the side of a bigger hole: a click just
 * beside a popup may not dismiss it, but a click on the popup is never eaten.
 * Overlay-layer windows sit above the catcher anyway.
 */
Scope {
    id: root

    property list<var> windows: []
    property bool active: false

    signal cleared()

    // Bar exclusive zones shift non-Ignore windows; pad holes by this much on the free axis.
    readonly property int zonePad: 96

    function holeFor(win, screen) {
        if (!win || !win.visible || win.screen?.name !== screen.name)
            return null;
        const sw = screen.width, sh = screen.height;
        const w = win.width ?? win.implicitWidth ?? 0;
        const h = win.height ?? win.implicitHeight ?? 0;
        if (w <= 0 || h <= 0)
            return null;
        const a = win.anchors ?? {};
        const mg = win.margins ?? {};
        let x0, x1, y0, y1;
        if (a.left && a.right) { x0 = 0; x1 = sw; }
        else if (a.left) { x0 = 0; x1 = (mg.left ?? 0) + w + zonePad; }
        else if (a.right) { x0 = sw - w - (mg.right ?? 0) - zonePad; x1 = sw; }
        else { x0 = (sw - w) / 2 - zonePad; x1 = (sw + w) / 2 + zonePad; }
        if (a.top && a.bottom) { y0 = 0; y1 = sh; }
        else if (a.top) { y0 = 0; y1 = (mg.top ?? 0) + h + zonePad; }
        else if (a.bottom) { y0 = sh - h - (mg.bottom ?? 0) - zonePad; y1 = sh; }
        else { y0 = (sh - h) / 2 - zonePad; y1 = (sh + h) / 2 + zonePad; }
        x0 = Math.max(0, Math.round(x0)); y0 = Math.max(0, Math.round(y0));
        x1 = Math.min(sw, Math.round(x1)); y1 = Math.min(sh, Math.round(y1));
        return { x: x0, y: y0, width: x1 - x0, height: y1 - y0 };
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: catcher
            required property var modelData
            screen: modelData
            visible: root.active

            readonly property var holes: root.windows.map(w => root.holeFor(w, catcher.modelData)).filter(h => h !== null)
            function hole(i) {
                return catcher.holes[i] ?? { x: 0, y: 0, width: 0, height: 0 };
            }

            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:focusGrab"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            anchors { top: true; bottom: true; left: true; right: true }

            mask: Region {
                item: catchArea
                Region { intersection: Intersection.Subtract; x: catcher.hole(0).x; y: catcher.hole(0).y; width: catcher.hole(0).width; height: catcher.hole(0).height }
                Region { intersection: Intersection.Subtract; x: catcher.hole(1).x; y: catcher.hole(1).y; width: catcher.hole(1).width; height: catcher.hole(1).height }
                Region { intersection: Intersection.Subtract; x: catcher.hole(2).x; y: catcher.hole(2).y; width: catcher.hole(2).width; height: catcher.hole(2).height }
                Region { intersection: Intersection.Subtract; x: catcher.hole(3).x; y: catcher.hole(3).y; width: catcher.hole(3).width; height: catcher.hole(3).height }
                Region { intersection: Intersection.Subtract; x: catcher.hole(4).x; y: catcher.hole(4).y; width: catcher.hole(4).width; height: catcher.hole(4).height }
                Region { intersection: Intersection.Subtract; x: catcher.hole(5).x; y: catcher.hole(5).y; width: catcher.hole(5).width; height: catcher.hole(5).height }
            }

            MouseArea {
                id: catchArea
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onPressed: root.cleared()
            }
        }
    }
}
