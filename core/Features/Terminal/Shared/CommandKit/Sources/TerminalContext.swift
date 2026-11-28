import GrepCore
import TerminalDomain

/// `더 보기`로 이어 받을 목록이 어디서 왔는지.
public enum TerminalListSource: Equatable, Sendable {
    case recent(limit: Int, period: Period?)
    case search(SearchQuery, period: Period?)
    case bin
    case bundle(String)
}

/// 목록 한 쪽의 크기(COM-008·ARC-003·ARC-008 값).
public enum TerminalPageSize {
    public static let bin = 20
    public static let bundle = 10
}

/// 명령 모듈이 터미널 RIB에서 쓰는 것. `TerminalInteractor`가 구현한다.
/// 화면 상태, 친 줄 찍기·토큰 받기, 만료, 목록 쪽 넘기기, 부모 알림을 맡긴다.
@MainActor
public protocol TerminalContext: AnyObject {
    var viewState: TerminalViewState { get }
    /// 사용자가 넣은 입력의 차례. 늦게 온 응답이 그 뒤 입력을 답으로 삼지 않게 한다.
    var inputSequence: Int { get }
    var authService: any AuthService { get }
    /// 서버에 닿았는지를 `연결 끊김` 표시에 넣는 전송(COM-010).
    var httpTransport: any HTTPTransport { get }
    /// 표시에 넣지 않는 전송(측정 이벤트, #105).
    var rawTransport: any HTTPTransport { get }
    var clipboard: any ClipboardPort { get }
    var files: any FilePort { get }
    var sleeper: any Sleeper { get }

    /// 상태가 바뀌었을 때만 그린다.
    func update(_ next: TerminalViewState)
    /// 친 줄을 찍고 입력줄을 비운 뒤 접근 토큰으로 `request`를 돌린다. 토큰이 없으면 친 줄을 되돌리고 만료를 알린다.
    func run(typed: String, _ request: @escaping @MainActor (_ accessToken: String) async -> Void)
    /// 터미널이 활성인 동안만 도는 작업을 띄운다.
    func launch(_ operation: @escaping @MainActor () async -> Void)
    /// 사용자가 그새 다른 글을 치고 있으면 덮어쓰지 않는다.
    func restoreInput(_ text: String)
    func expire()
    func expire(restoring typed: String)
    func notifyItemsChanged()
    func notifyConnectionsChanged()
    /// 목록 줄을 찍는다. 다음 쪽이 있으면 `더 보기`가 이어 받는다.
    func showList(_ line: TerminalViewState.Line, nextCursor: String?, source: TerminalListSource, typed: String)
    /// `· 0건` 줄과 함께 보일 최근 자료를 받아 찍는다.
    func showNoResults(
        for query: SearchQuery, period: Period?, related: [ItemSummary], typed: String, accessToken: String
    ) async
    /// 찾기 결과를 넘기기로 잇는다(`찾기 … | 넘기기`, `찾아두기 … | 넘기기`).
    func searchThenHandOff(_ query: SearchQuery, period: Period?, typed: String, sequence: Int, accessToken: String) async
    /// 붙여 넣기·파일 놓기처럼 엔터 없이 들어온 입력. 입력 차례를 늘리고 기다리던 확인을 버린다.
    func beginUserInput()
    /// `로그아웃 모든기기` 확인이 끝났다.
    func requestSignOutEverywhere()
}

/// 확인 대기(COM-007)를 가진 명령 모듈. 다음 입력 한 번이 답이다.
@MainActor
public protocol TerminalCommand: AnyObject {
    var hasPendingAnswer: Bool { get }
    /// 기다리던 답이면 처리하고 true.
    func answer(_ text: String) -> Bool
    /// 다른 입력이 와서 기다리던 확인을 버린다.
    func cancelPendingAnswer()
}

public extension TerminalCommand {
    var hasPendingAnswer: Bool { false }
    func answer(_ text: String) -> Bool { false }
    func cancelPendingAnswer() {}
}
