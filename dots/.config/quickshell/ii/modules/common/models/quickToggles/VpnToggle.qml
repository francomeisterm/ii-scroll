import QtQuick
import qs.services
import qs.modules.common

// NetworkManager VPN (default: Config.options.vpn.connection). Idea from caelestia-shell.
QuickToggleModel {
    name: Translation.tr("VPN")
    available: Vpn.available
    toggled: Vpn.connected
    icon: Vpn.connected ? "vpn_lock" : "vpn_key"
    statusText: Vpn.busy ? Translation.tr("Connecting…")
        : Vpn.connected ? Vpn.activeName
        : (Vpn.targetName || Translation.tr("No VPN"))
    tooltipText: Vpn.connected ? Translation.tr("Disconnect %1").arg(Vpn.activeName)
        : Translation.tr("Connect %1").arg(Vpn.targetName)
    mainAction: () => Vpn.toggle()
}
