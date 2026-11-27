/// 이 기기에 터미널 기록(출력·치던 글·선택)을 남긴다(COM-009). 플랫폼이 구현한다(웹: localStorage).
/// 기록의 모양은 코어가 정해 문자열로 넘긴다. 플랫폼은 읽고 쓰기만 한다.
@MainActor
public protocol HistoryStore: AnyObject {
    /// 남긴 기록. 없거나 읽지 못하면 nil.
    func load() -> HistoryRecord?
    func save(_ record: HistoryRecord)
    /// 로그아웃·다른 계정 로그인 때 지운다(COM-009 규칙 3·5).
    func clear()
}

public struct HistoryRecord: Equatable, Sendable {
    /// 기록을 남긴 계정(접근 토큰의 `sub`). 다른 계정이면 되살리지 않는다.
    public let subject: String
    /// 코어가 만든 기록 본문(JSON). 플랫폼은 해석하지 않는다.
    public let payload: String

    public init(subject: String, payload: String) {
        self.subject = subject
        self.payload = payload
    }
}
