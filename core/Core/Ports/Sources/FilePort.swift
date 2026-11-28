/// 끌어다 놓은 파일 하나. 바이트는 플랫폼이 들고 있고 코어는 `id`로만 가리킨다.
public struct DroppedFile: Equatable, Sendable {
    /// 플랫폼이 붙인 이 드롭 안에서의 이름표.
    public let id: String
    public let name: String
    /// 바이트.
    public let size: Int

    public init(id: String, name: String, size: Int) {
        self.id = id
        self.name = name
        self.size = size
    }
}

/// 끌어다 놓은 파일을 서명 URL로 올린다(`POST /uploads`의 `uploadUrl`, ADR-BCK-002 결정 2).
/// 플랫폼이 구현한다(웹: fetch PUT). 형식 판정과 해시는 서버가 한다(COM-004 규칙 2, COM-001).
@MainActor
public protocol FilePort: AnyObject {
    /// 올렸으면 그대로 끝난다. 상태 코드가 2xx가 아니면 `.unreachable`이 아니라 `.rejected`다.
    func upload(_ fileID: String, to uploadURL: String) async throws(FileUploadError)
    /// 이 드롭의 파일을 더 쓰지 않는다. 플랫폼은 잡고 있던 바이트를 놓는다.
    func release(_ fileID: String)
    /// 파일을 UTF-8 글로 읽는다. 북마크 가져오기(F8)가 HTML을 서버에 글로 보낼 때 쓴다.
    func readText(_ fileID: String) async throws(FileUploadError) -> String
}

extension FilePort {
    /// 아직 읽기를 구현하지 않은 플랫폼은 가져오기를 `서버 오류`로 알린다.
    public func readText(_ fileID: String) async throws(FileUploadError) -> String {
        throw .missingFile
    }
}

public enum FileUploadError: Error, Equatable, Sendable {
    case cancelled
    /// COM-010 `연결 끊김`
    case unreachable
    /// COM-010 `응답 없음`
    case timedOut
    /// 저장소가 받지 않았다(서명 만료 등). `서버 오류`로 알린다.
    case rejected
    /// 플랫폼이 그 파일을 더 갖고 있지 않다.
    case missingFile
}
