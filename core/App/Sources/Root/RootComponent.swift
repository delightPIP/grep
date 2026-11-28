import FeatureLoggedIn
import FeatureLoggedInInterface
import FeatureLoggedOut
import FeatureLoggedOutInterface
import FeatureTerminal
import FeatureTerminalInterface
import GrepCore
import RIBs

/// 피처 Dependency를 모두 채운다.
final class RootComponent: EmptyComponent, LoggedOutDependency, LoggedInDependency, TerminalDependency {
    let authService: any AuthService
    let httpTransport: any HTTPTransport
    let clipboard: any ClipboardPort
    let files: any FilePort
    let historyStore: any HistoryStore
    let sleeper: any Sleeper
    let deviceTime: DeviceTime

    init(platform: PlatformServices) {
        authService = platform.authService
        httpTransport = platform.httpTransport
        clipboard = platform.clipboard
        files = platform.files
        historyStore = platform.historyStore
        sleeper = platform.sleeper
        deviceTime = platform.deviceTime
        super.init()
    }
}
