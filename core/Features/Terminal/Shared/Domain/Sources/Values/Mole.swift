import GrepDomain

/// #175 땅굴 두더지의 동작. `seq`가 바뀌면 뷰가 같은 동작도 다시 튼다.
public struct Mole: Equatable, Sendable {
    public enum Action: String, Equatable, Sendable {
        /// 찾기 결과가 찍혔다.
        case seek
        /// 저장 결과가 찍혔다.
        case save
        /// 복사에 성공했다.
        case handoff
        /// `✗` 줄이 찍혔다.
        case error
    }

    public let action: Action
    public let seq: Int

    public init(action: Action, seq: Int) {
        self.action = action
        self.seq = seq
    }
}
