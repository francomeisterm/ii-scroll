import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.utils
import qs.modules.common.widgets
import QtQml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import qs.modules.compat

Button {
    id: root
    property var imageData
    property string provider: ""
    readonly property var providerInfo: Booru.providers[root.provider] ?? {}
    // Providers whose image host needs a Referer: load from cache, fetch via throttled curl
    readonly property bool throttledFetch: !!root.providerInfo.imageReferer
    // High quality = the ~850px sample (or the original if it's a still image and
    // there's no sample); videos/animations fall back to the static thumbnail.
    readonly property string throttledSourceUrl: {
        if (!root.providerInfo.highQualityPreview) return root.imageData.preview_url ?? root.imageData.sample_url
        const ext = (root.imageData.file_ext ?? "").toLowerCase()
        const stillImage = ["jpg", "jpeg", "png", "webp"].includes(ext)
        if (root.imageData.sample_url && (root.imageData.sample_url !== root.imageData.file_url || stillImage))
            return root.imageData.sample_url
        return root.imageData.preview_url
    }
    readonly property string cachedThumbPath: `${root.previewDownloadPath}/${root.provider}/${root.imageData.md5 || root.imageData.id}_${root.providerInfo.highQualityPreview ? "hq" : "thumb"}.${root.throttledSourceUrl.split('.').pop().split('?')[0]}`
    property var fetchToken: ({ cancelled: false })
    property bool fetchQueued: false
    property int fetchAttempts: 0
    function queueFetch() {
        if (root.fetchQueued || root.fetchAttempts >= 3) return
        root.fetchQueued = true
        root.fetchAttempts++
        Booru.enqueueThrottledFetch(root.fetchToken, () => {
            root.fetchQueued = false
            throttledDownloader.running = true
        })
    }
    Component.onDestruction: root.fetchToken.cancelled = true
    property var rowHeight
    property bool manualDownload: false
    property string previewDownloadPath
    property string downloadPath
    property string nsfwPath
    property string fileName: decodeURIComponent((imageData.file_url).substring((imageData.file_url).lastIndexOf('/') + 1))
    property string filePath: `${root.previewDownloadPath}/${root.fileName}`
    property int maxTagStringLineLength: 50
    property real imageRadius: Appearance.rounding.small

    property bool showActions: false
    ImageDownloaderProcess {
        id: imageDownloader
        running: root.manualDownload
        filePath: root.filePath
        sourceUrl: root.imageData.preview_url ?? root.imageData.sample_url
        onDone: (path, width, height) => {
            imageObject.source = ""
            imageObject.source = path
            if (!modelData.width || !modelData.height) {
                modelData.width = width
                modelData.height = height
                modelData.aspect_ratio = width / height
            }
        }
    }

    ImageDownloaderProcess {
        id: throttledDownloader
        running: false
        filePath: root.cachedThumbPath
        sourceUrl: root.throttledSourceUrl
        referer: root.providerInfo.imageReferer ?? ""
        downloadUserAgent: root.providerInfo.imageUserAgent ?? ""
        onDone: (path, width, height) => {
            imageObject.source = ""
            imageObject.source = "file://" + FileUtils.trimFileProtocol(path)
        }
        onFailed: (httpCode) => {
            console.log("[Booru] Thumbnail fetch failed (HTTP " + httpCode + ")")
            if (httpCode === 429) {
                Booru.reportRateLimited()
                root.queueFetch()
            }
        }
    }

    StyledToolTip {
        text: `${StringUtils.wordWrap(root.imageData.tags, root.maxTagStringLineLength)}`
    }

    padding: 0
    implicitWidth: root.rowHeight * modelData.aspect_ratio
    implicitHeight: root.rowHeight

    background: Rectangle {
        implicitWidth: root.rowHeight * modelData.aspect_ratio
        implicitHeight: root.rowHeight
        radius: imageRadius
        color: Appearance.colors.colLayer2
    }

    contentItem: Item {
        anchors.fill: parent

        StyledImage {
            id: imageObject
            anchors.fill: parent
            width: root.rowHeight * modelData.aspect_ratio
            height: root.rowHeight
            fillMode: Image.PreserveAspectFit
            source: root.throttledFetch ? "file://" + FileUtils.trimFileProtocol(root.cachedThumbPath) : modelData.preview_url
            onStatusChanged: {
                // Not cached yet (or unreadable) -> fetch through the throttled queue
                if (root.throttledFetch && status === Image.Error) root.queueFetch()
            }

            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: root.rowHeight * modelData.aspect_ratio
                    height: root.rowHeight
                    radius: imageRadius
                }
            }
        }

        RippleButton {
            id: menuButton
            anchors.top: parent.top
            anchors.right: parent.right
            property real buttonSize: 30
            anchors.margins: Math.max(root.imageRadius - buttonSize / 2, 8)
            implicitHeight: buttonSize
            implicitWidth: buttonSize

            buttonRadius: Appearance.rounding.full
            colBackground: ColorUtils.transparentize(Appearance.m3colors.m3surface, 0.3)
            colBackgroundHover: ColorUtils.transparentize(ColorUtils.mix(Appearance.m3colors.m3surface, Appearance.m3colors.m3onSurface, 0.8), 0.2)
            colRipple: ColorUtils.transparentize(ColorUtils.mix(Appearance.m3colors.m3surface, Appearance.m3colors.m3onSurface, 0.6), 0.1)

            contentItem: MaterialSymbol {
                horizontalAlignment: Text.AlignHCenter
                iconSize: Appearance.font.pixelSize.large
                color: Appearance.m3colors.m3onSurface
                text: "more_vert"
            }

            onClicked: {
                root.showActions = !root.showActions
            }
        }

        Loader {
            id: contextMenuLoader
            active: root.showActions
            anchors.top: menuButton.bottom
            anchors.right: parent.right
            anchors.margins: 8

            sourceComponent: Item {
                width: contextMenu.width
                height: contextMenu.height

                StyledRectangularShadow {
                    target: contextMenu
                }
                Rectangle {
                    id: contextMenu
                    anchors.centerIn: parent
                    opacity: root.showActions ? 1 : 0
                    visible: opacity > 0
                    radius: Appearance.rounding.small
                    color: Appearance.m3colors.m3surfaceContainer
                    implicitHeight: contextMenuColumnLayout.implicitHeight + radius * 2
                    implicitWidth: contextMenuColumnLayout.implicitWidth

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }

                    ColumnLayout {
                        id: contextMenuColumnLayout
                        anchors.centerIn: parent
                        spacing: 0

                        MenuButton {
                            id: openFileLinkButton
                            Layout.fillWidth: true
                            buttonText: Translation.tr("Open file link")
                            onClicked: {
                                root.showActions = false
                                Hyprland.dispatch("hl.config({cursor = {no_warps = true}})")
                                Qt.openUrlExternally(root.imageData.file_url)
                                Hyprland.dispatch("hl.config({cursor = {no_warps = false}})")
                            }
                        }
                        MenuButton {
                            id: sourceButton
                            visible: root.imageData.source && root.imageData.source.length > 0
                            Layout.fillWidth: true
                            buttonText: Translation.tr("Go to source (%1)").arg(StringUtils.getDomain(root.imageData.source))
                            enabled: root.imageData.source && root.imageData.source.length > 0
                            onClicked: {
                                root.showActions = false
                                Hyprland.dispatch("hl.config({cursor = {no_warps = true}})")
                                Qt.openUrlExternally(root.imageData.source)
                                Hyprland.dispatch("hl.config({cursor = {no_warps = false}})")
                            }
                        }
                        MenuButton {
                            id: downloadButton
                            Layout.fillWidth: true
                            buttonText: Translation.tr("Download")
                            onClicked: {
                                root.showActions = false;
                                const targetPath = root.imageData.is_nsfw ? root.nsfwPath : root.downloadPath;
                                const userAgent = root.throttledFetch ? (root.providerInfo.imageUserAgent ?? "") : (Config.options?.networking?.userAgent ?? "")
                                const userAgentHeader = (userAgent ? ` -H 'User-Agent: ${StringUtils.shellSingleQuoteEscape(userAgent)}'` : "")
                                    + (root.throttledFetch ? ` -e '${StringUtils.shellSingleQuoteEscape(root.providerInfo.imageReferer)}'` : "")
                                Quickshell.execDetached(["bash", "-c", 
                                    `mkdir -p '${targetPath}' && curl '${StringUtils.shellSingleQuoteEscape(root.imageData.file_url)}'${userAgentHeader} -o '${targetPath}/${root.fileName}' && notify-send '${Translation.tr("Download complete")}' '${root.downloadPath}/${root.fileName}' -a 'Shell'`
                                ])
                            }
                        }
                    }
                }
            }
        }
    }
}