pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.modules.compat

Scope {
    id: root

    required property Component lockSurface
    property alias context: lockContext

    // Scroll port: the lock wallpaper used to be decoded from scratch (full 4K, uncached) on
    // every lock, so the lock surface stayed transparent - black on wlroots - until it loaded.
    // Decode it at screen size, cache it, and keep a hidden reference loaded while unlocked so
    // the lock surface gets it from the pixmap cache on its first frame.
    readonly property string lockWallpaperPath: {
        const p = Config.options.background.wallpaperPath;
        return /\.(mp4|webm|mkv|avi|mov)$/i.test(p) ? Config.options.background.thumbnailPath : p;
    }
    function lockWallpaperSize(screen) {
        const s = screen ?? Quickshell.screens[0];
        return s ? Qt.size(s.width, s.height) : Qt.size(1920, 1080);
    }
    Image {
        visible: false
        source: root.lockWallpaperPath
        sourceSize: root.lockWallpaperSize(null)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
    }
    property Component sessionLockSurface: WlSessionLockSurface {
        id: sessionLockSurface
        color: "transparent"

        // Scroll port: upstream leaves the lock surface transparent and lifts the Background
        // layer to Overlay, which Hyprland draws behind a lock. wlroots/Scroll only shows
        // lock surfaces (black elsewhere), so draw the blurred wallpaper here instead.
        Item {
            id: lockWallpaperBox
            anchors.fill: parent
            Image {
                id: lockWallpaper
                anchors.fill: parent
                source: root.lockWallpaperPath
                sourceSize: root.lockWallpaperSize(sessionLockSurface.screen)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                visible: !Config.options.lock.blur.enable
            }
            GaussianBlur {
                anchors.fill: parent
                visible: Config.options.lock.blur.enable
                source: lockWallpaper
                scale: Config.options.lock.blur.extraZoom
                radius: Config.options.lock.blur.radius
                samples: radius * 2 + 1
            }
            Rectangle {
                anchors.fill: parent
                visible: Config.options.lock.blur.enable
                color: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.7)
            }
            // Upstream shows the Background clock widget (centered) through the lock; draw a
            // simple one here since the Background layer is hidden while locked on Scroll.
            Column {
                visible: Config.options.lock.centerClock
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -parent.height * 0.08
                spacing: 4
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: DateTime.time
                    color: Appearance.colors.colOnLayer0
                    font.family: Config.options.background.widgets.clock.digital.font.family
                    font.pixelSize: Config.options.background.widgets.clock.digital.font.size * 1.3
                    font.weight: Config.options.background.widgets.clock.digital.font.weight
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: DateTime.longDate
                    color: Appearance.colors.colOnLayer0
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.huge
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: Config.options.lock.showLockedText
                    text: Translation.tr("Locked")
                    color: Appearance.colors.colSubtext
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.normal
                }
            }
        }

        Loader {
            active: GlobalStates.screenLocked
            anchors.fill: parent
            opacity: active ? 1 : 0
            Behavior on opacity {
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }
            sourceComponent: root.lockSurface
        }
    }

    Process {
        id: unlockKeyringProc
        onExited: (exitCode, exitStatus) => {
            KeyringStorage.fetchKeyringData();
        }
    }
    function unlockKeyring() {
        unlockKeyringProc.exec({
            environment: ({
                "UNLOCK_PASSWORD": lockContext.currentText
            }),
            command: ["bash", "-c", Quickshell.shellPath("scripts/keyring/unlock.sh")]
        })
    }

    // This stores all the information shared between the lock surfaces on each screen.
    // https://github.com/quickshell-mirror/quickshell-examples/tree/master/lockscreen
    LockContext {
        id: lockContext

        Connections {
            target: GlobalStates
            function onScreenLockedChanged() {
                if (GlobalStates.screenLocked) {
                    lockContext.reset();
                    lockContext.tryFingerUnlock();
                }
            }
        }

        onUnlocked: (targetAction) => {
            // Perform the target action if it's not just unlocking
            if (targetAction == LockContext.ActionEnum.Poweroff) {
                Session.poweroff();
                return;
            } else if (targetAction == LockContext.ActionEnum.Reboot) {
                Session.reboot();
                return;
            }

            // Unlock the keyring if configured to do so
            if (Config.options.lock.security.unlockKeyring) root.unlockKeyring(); // Async

            // Unlock the screen before exiting, or the compositor will display a
            // fallback lock you can't interact with.
            GlobalStates.screenLocked = false;

            // Reset
            lockContext.reset();

            // Post-unlock actions
            if (lockContext.alsoInhibitIdle) {
                lockContext.alsoInhibitIdle = false;
                Idle.toggleInhibit(true);
            }
        }
    }

    WlSessionLock {
        id: lock
        locked: GlobalStates.screenLocked
        surface: root.sessionLockSurface
    }

    function lock() {
        if (Config.options.lock.useHyprlock) {
            Quickshell.execDetached(["bash", "-c", "pidof hyprlock || hyprlock"]);
            return;
        }
        GlobalStates.screenLocked = true;
    }

    IpcHandler {
        target: "lock"

        function activate(): void {
            root.lock();
        }
        function focus(): void {
            lockContext.shouldReFocus();
        }
    }

    GlobalShortcut {
        name: "lock"
        description: "Locks the screen"

        onPressed: {
            root.lock()
        }
    }

    GlobalShortcut {
        name: "lockFocus"
        description: "Re-focuses the lock screen. This is because Hyprland after waking up for whatever reason"
            + "decides to keyboard-unfocus the lock screen"

        onPressed: {
            lockContext.shouldReFocus();
        }
    }

    function initIfReady() {
        if (!Config.ready || !Persistent.ready) return;
        if (Config.options.lock.launchOnStartup && Persistent.isNewHyprlandInstance) {
            root.lock();
        } else {
            KeyringStorage.fetchKeyringData();
        }
    }
    Connections {
        target: Config
        function onReadyChanged() {
            root.initIfReady();
        }
    }
    Connections {
        target: Persistent
        function onReadyChanged() {
            root.initIfReady();
        }
    }
}
