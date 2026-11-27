import GrepCore
import JavaScriptKit

/// JS가 구현한 파일 포트(`web/ports/file-port.ts`의 `FilePort`)를 코어의 `FilePort`로 잇는다.
/// 끌어다 놓은 `File`은 JS가 쥐고 있다. 여기서는 이름표(id)만 오간다.
@MainActor
final class JSFilePort: FilePort {
    private static let uploadedKind = "uploaded"
    private static let readKind = "read"

    private let port: JSObject

    init(port: JSObject) {
        self.port = port
    }

    /// 계약과 다른 값이 오거나 프로미스가 거절되면 `연결 끊김`으로 본다.
    /// 올리는 중에 Task가 취소돼도 요청은 끊지 않는다(JS 쪽 시간 제한까지 간다). 끝난 뒤 취소로 알린다.
    func upload(_ fileID: String, to uploadURL: String) async throws(FileUploadError) {
        let failure: FileUploadError? = await JSPromiseValue.await(
            port.upload!(fileID, uploadURL),
            rejected: .unreachable
        ) { value in
            guard let result = value.object else { return .unreachable }
            if result.kind.string == Self.uploadedKind { return nil }
            return result.error.string.flatMap(FileUploadError.init(bridgeName:)) ?? .unreachable
        }
        if Task.isCancelled { throw .cancelled }
        if let failure { throw failure }
    }

    /// 계약과 다른 값이 오거나 프로미스가 거절되면 파일이 없는 것으로 본다.
    func readText(_ fileID: String) async throws(FileUploadError) -> String {
        let result: Result<String, FileUploadError> = await JSPromiseValue.await(
            port.readText!(fileID),
            rejected: .failure(.missingFile)
        ) { value in
            guard let result = value.object else { return .failure(.missingFile) }
            if result.kind.string == Self.readKind, let text = result.text.string { return .success(text) }
            return .failure(result.error.string.flatMap(FileUploadError.init(bridgeName:)) ?? .missingFile)
        }
        if Task.isCancelled { throw .cancelled }
        return try result.get()
    }

    func release(_ fileID: String) {
        _ = port.release!(fileID)
    }
}
