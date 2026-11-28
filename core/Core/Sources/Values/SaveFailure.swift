
/// 저장 실패 이유.
public enum SaveFailure: Equatable, Sendable {
    /// `연결 끊김`(COM-010)
    case disconnected
    /// `응답 없음`(COM-010)
    case timedOut
    /// `서버 오류`
    case serverError
    /// `✗ 저장 안 됨: 받지 않는 형식 (.<확장자>)`(COM-004)
    case unsupportedFormat(fileExtension: String)
    /// `✗ 저장 안 됨: 20MB 넘음 (<파일 이름> · <크기>)`(COM-004 규칙 8). 크기는 바이트.
    case tooLarge(fileName: String, bytes: Int)
}
