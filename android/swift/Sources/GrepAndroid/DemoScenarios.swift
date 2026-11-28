/// 단독 실행 앱이 띄울 수 있는 피처. Kotlin demo 모듈이 이 문자열로 고른다.
public enum DemoFeature: String, CaseIterable, Sendable {
    case loggedOut
    case terminal
}

/// 단독 실행 앱에서 로그인 화면 시나리오를 고르기 위한 설정.
public enum DemoLoggedOutScenario: String, CaseIterable, Sendable {
    case initial
    case expired
    case signedOut
    case failDisconnected
    case failTimedOut
    case failDenied
    case cancelled
}

/// 단독 실행 앱에서 터미널 화면 시나리오를 고르기 위한 설정(iOS `TerminalExampleApp`과 1:1 대응).
public enum DemoTerminalScenario: String, CaseIterable, Sendable {
    case welcome
    case saved
    case alreadySaved
    case processing
    case recentAndSearch
    case noResults
    case picked
    case handedOff
    case handoffConfirm
    case handoffDenied
    case guide
    case expired
    /// #93~#111 정리·고치기·샘플·고르기 빼기·모든 기기 로그아웃 줄.
    case cleanupLines
    /// 계약 2 묶음·찾아두기 줄.
    case bundleLines
    /// 계약 2 자세히 보기·연결·가져오기 줄.
    case detailLines
}
