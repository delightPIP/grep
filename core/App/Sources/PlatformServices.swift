import FeatureLoggedIn
import FeatureLoggedInInterface
import FeatureLoggedOut
import FeatureLoggedOutInterface
import FeatureTerminal
import FeatureTerminalInterface
import GrepCore
import RIBs

/// 플랫폼이 구현해 넘기는 것 전부.
@MainActor
public struct PlatformServices {
    public let authService: any AuthService
    public let httpTransport: any HTTPTransport
    public let clipboard: any ClipboardPort
    public let files: any FilePort
    public let historyStore: any HistoryStore
    public let sleeper: any Sleeper
    /// 보관함 날짜 묶음을 나눌 기기 시간대(ARC-007 값).
    public let deviceTime: DeviceTime

    public init(
        authService: any AuthService,
        httpTransport: any HTTPTransport,
        clipboard: any ClipboardPort,
        files: any FilePort,
        historyStore: any HistoryStore,
        sleeper: any Sleeper = TaskSleeper(),
        deviceTime: DeviceTime = .system
    ) {
        self.authService = authService
        self.httpTransport = httpTransport
        self.clipboard = clipboard
        self.files = files
        self.historyStore = historyStore
        self.sleeper = sleeper
        self.deviceTime = deviceTime
    }
}
