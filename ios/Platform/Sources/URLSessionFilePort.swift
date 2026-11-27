import Foundation
import GrepCore

/// `URLSession` PUT으로 서명 URL에 파일을 올리는 파일 포트(COM-004).
/// 바이트는 이 포트가 `id`로 들고 있고, 코어는 `id`·이름·크기만 안다.
@MainActor
public final class URLSessionFilePort: FilePort {
    public static let defaultTimeout: TimeInterval = 30

    private let session: URLSession
    private let timeout: TimeInterval
    private var stagedFiles: [String: Data] = [:]

    public init(
        session: URLSession = .shared,
        timeout: TimeInterval = URLSessionFilePort.defaultTimeout
    ) {
        self.session = session
        self.timeout = timeout
    }

    /// 끌어다 놓거나 선택한 파일 바이트를 등록하고 코어에 넘길 `id`를 돌려준다.
    @discardableResult
    public func stage(_ data: Data, id: String = UUID().uuidString) -> String {
        stagedFiles[id] = data
        return id
    }

    public func upload(_ fileID: String, to uploadURL: String) async throws(FileUploadError) {
        guard let data = stagedFiles[fileID] else { throw .missingFile }
        guard
            let url = URL(string: uploadURL),
            let scheme = url.scheme,
            ["http", "https"].contains(scheme.lowercased())
        else {
            throw .unreachable
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.timeoutInterval = timeout

        let response: URLResponse
        do {
            (_, response) = try await session.upload(for: request, from: data)
        } catch {
            if Task.isCancelled || (error as? URLError)?.code == .cancelled {
                throw .cancelled
            }
            if (error as? URLError)?.code == .timedOut {
                throw .timedOut
            }
            throw .unreachable
        }

        guard let http = response as? HTTPURLResponse else { throw .unreachable }
        guard (200..<300).contains(http.statusCode) else { throw .rejected }
    }

    public func release(_ fileID: String) {
        stagedFiles.removeValue(forKey: fileID)
    }
}
