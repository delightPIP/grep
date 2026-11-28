import GrepDomain

/// 빠진 인자 줄의 하위 명령(계약 2, #154). 값은 view-state.ts와 같다.
public enum MissingArgumentSub: String, Equatable, Sendable, Codable {
    /// `고르기 빼기`
    case unpick
}
