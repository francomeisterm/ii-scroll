pragma Singleton

import QtQuick
import qs.modules.common
import Quickshell
import Quickshell.Io
import qs.modules.compat

/**
 * Simple hyprsunset service with automatic mode.
 * In theory we don't need this because hyprsunset has a config file, but it somehow doesn't work.
 * It should also be possible to control it via hyprctl, but it doesn't work consistently either so we're just killing and launching.
 */
Singleton {
    id: root
    signal gammaChangeAttempt()

    readonly property real gammaLowerLimit: 25

    property string from: Config.options?.light?.night?.from ?? "19:00" 
    property string to: Config.options?.light?.night?.to ?? "06:30"
    property bool automatic: Config.options?.light?.night?.automatic && (Config?.ready ?? true)
    property int colorTemperature: Config.options?.light?.night?.colorTemperature ?? 5000
    property int defaultColorTemperature: 6000
    property int gamma: 100
    property bool shouldBeOn
    property bool firstEvaluation: true
    property bool temperatureActive: false

    property int fromHour: Number(from.split(":")[0])
    property int fromMinute: Number(from.split(":")[1])
    property int toHour: Number(to.split(":")[0])
    property int toMinute: Number(to.split(":")[1])

    property int clockHour: DateTime.clock.hours
    property int clockMinute: DateTime.clock.minutes

    property var manualActive
    property int manualActiveHour
    property int manualActiveMinute

    onClockMinuteChanged: reEvaluate()
    onAutomaticChanged: {
        root.manualActive = undefined;
        root.firstEvaluation = true;
        reEvaluate();
    }

    function inBetween(t, from, to) {
        if (from < to) {
            return (t >= from && t <= to);
        } else {
            // Wrapped around midnight
            return (t >= from || t <= to);
        }
    }

    function reEvaluate() {
        const t = clockHour * 60 + clockMinute;
        const from = fromHour * 60 + fromMinute;
        const to = toHour * 60 + toMinute;
        const manualActive = manualActiveHour * 60 + manualActiveMinute;

        if (root.manualActive !== undefined && (inBetween(from, manualActive, t) || inBetween(to, manualActive, t))) {
            root.manualActive = undefined;
        }
        root.shouldBeOn = inBetween(t, from, to);
        if (firstEvaluation) {
            firstEvaluation = false;
            root.ensureState();
        }
    }

    onShouldBeOnChanged: ensureState()
    function ensureState() {
        // console.log("[Hyprsunset] Ensuring state:", root.shouldBeOn, "Automatic mode:", root.automatic);
        if (!root.automatic || root.manualActive !== undefined)
            return;
        if (root.shouldBeOn) {
            root.enableTemperature();
        } else {
            root.disableTemperature();
        }
    }

    // ---- Scroll port: gammastep (wlr-gamma-control) instead of hyprsunset ----
    // One long-running `gammastep -O` process holds the temperature/brightness; the
    // gamma ramp is dropped as soon as it exits, so "off" = not running.
    // Note: untested on the HDR output (Scroll's patched wlroots), same as DMS's night light.

    readonly property bool needsGammastep: root.temperatureActive || root.gamma < 100
    readonly property int effectiveTemperature: root.temperatureActive ? root.colorTemperature : 6500

    Process {
        id: gammastepProc
        running: root.needsGammastep
        command: ["gammastep", "-m", "wayland", "-P", "-O", `${root.effectiveTemperature}`, "-b", `${(root.gamma / 100).toFixed(2)}`]
        onExited: (code, status) => {
            if (root.needsGammastep && code !== 0)
                console.warn(`[Hyprsunset] gammastep exited with ${code} (is it installed?)`);
        }
    }

    function restartGammastep() {
        if (!root.needsGammastep)
            return;
        gammastepProc.running = false;
        restartTimer.restart();
    }

    Timer {
        id: restartTimer
        interval: 50
        onTriggered: gammastepProc.running = root.needsGammastep
    }

    onEffectiveTemperatureChanged: restartGammastep()

    function startHyprsunset() {}

    function load() {
        root.ensureState();
    }

    Timer {
        id: updateHyprsunset
        interval: 100
        repeat: false
        onTriggered: {
            root.ensureState();
            root.setGamma(root.gamma);
        }
    }

    function enableTemperature() {
        root.temperatureActive = true;
    }

    function disableTemperature() {
        root.temperatureActive = false;
    }

    function setGamma(gamma) {
        root.gamma = Math.max(root.gammaLowerLimit, Math.min(100, gamma));
        root.gammaChangeAttempt();
        root.restartGammastep();
    }

    function fetchState() {}

    function toggleTemperature(active = undefined) {
        if (root.manualActive === undefined) {
            root.manualActive = root.temperatureActive;
            root.manualActiveHour = root.clockHour;
            root.manualActiveMinute = root.clockMinute;
        }

        root.manualActive = active !== undefined ? active : !root.manualActive;
        if (root.manualActive) {
            root.enableTemperature();
        } else {
            root.disableTemperature();
        }
    }

    // Change temp: colorTemperature is bound to the config, effectiveTemperature follows
}
