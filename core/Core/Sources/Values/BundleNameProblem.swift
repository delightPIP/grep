
/// `✗ 묶음 이름: …` 이유(ARC-003).
public enum BundleNameProblem: String, Equatable, Sendable, Codable {
    /// `✗ 묶음 이름: 띄어쓰기 없이 1~20자 …`
    case format
    /// `✗ 묶음 이름: 숫자만 · #시작 · 빼기 · 지우기 불가`
    case reserved
}
