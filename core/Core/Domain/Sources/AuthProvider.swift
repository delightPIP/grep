/// 로그인 방식. ACC-001 값: Google, GitHub 둘뿐이다.
public enum AuthProvider: String, Equatable, Sendable, CaseIterable {
    case google
    case github
}
