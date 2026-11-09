import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

Process {
    id: root

    signal done(string path, int width, int height);
    signal failed(int httpCode);
    required property string filePath;
    required property string sourceUrl;
    property string downloadUserAgent: Config.options?.networking.userAgent ?? ""
    // When set, send this Referer, don't follow redirects, and only keep the
    // file if it is really an image (hotlink redirects return HTML).
    property string referer: ""
    
    function processFilePath() {
        return StringUtils.shellSingleQuoteEscape(FileUtils.trimFileProtocol(filePath));
    }

    function processSourceUrl() {
        return StringUtils.shellSingleQuoteEscape(sourceUrl);
    }

    function curlUserAgentArg() {
        if (!downloadUserAgent) {
            return "";
        }
        return ` -H 'User-Agent: ${StringUtils.shellSingleQuoteEscape(downloadUserAgent)}'`;
    }

    running: true
    command: referer ? ["bash", "-c",
        `f='${processFilePath()}'; mkdir -p "$(dirname "$f")"; `
        + `if [ -f "$f" ]; then file "$f"; exit 0; fi; `
        + `code=$(curl -sS --max-time 20 -o "$f.part" -w '%{http_code}' -e '${StringUtils.shellSingleQuoteEscape(referer)}'${curlUserAgentArg()} '${processSourceUrl()}'); `
        + `if [ "$code" = 200 ] && file -b --mime-type "$f.part" | grep -q '^image/'; then mv "$f.part" "$f"; file "$f"; `
        + `else rm -f "$f.part"; echo "HTTPFAIL $code"; fi`
    ] : ["bash", "-c", 
        `mkdir -p $(dirname '${processFilePath()}'); [ -f '${processFilePath()}' ] || curl -sSL '${processSourceUrl()}'${curlUserAgentArg()} -o '${processFilePath()}' && file '${processFilePath()}'`
    ]
    stdout: StdioCollector {
        id: imageSizeOutputCollector
        onStreamFinished: {
            const output = imageSizeOutputCollector.text.trim();
            const fail = output.match(/^HTTPFAIL (\d*)/);
            if (fail) {
                root.failed(Number(fail[1]) || 0);
                return;
            }
            const match = output.match(/(\d+)\s*x\s*(\d+)/);

            if (match) {
                const width = Number(match[1]);
                const height = Number(match[2]);
                root.done(root.filePath, width, height);
            }
        }
    }
}
