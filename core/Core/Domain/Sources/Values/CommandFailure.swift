
/// 명령 실패 이유(COM-008, COM-010).
public enum CommandFailure: Equatable, Sendable {
    /// `연결 끊김`
    case disconnected
    /// `응답 없음`
    case timedOut
    /// `서버 오류`
    case serverError
    /// `클립보드 거부`(넘기기만)
    case clipboardDenied
}
