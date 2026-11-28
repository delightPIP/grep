#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FeatureTerminalInterface
import GrepCore

/// 자료 API(api/openapi.yaml `saveItem`). 응답 해석까지만 하고 화면은 모른다.
enum ItemsAPI {
    enum SaveRequest: Equatable {
        case link(url: String)
        case text(String)
        /// `POST /uploads`로 받은 자리에 올린 파일.
        case file(uploadID: String)
    }

    enum UploadOutcome: Equatable {
        /// 이 URL로 바이트를 올린 뒤 `uploadID`로 저장한다.
        case created(uploadID: String, uploadURL: String)
        case sessionExpired
        case failed(SaveFailure)
        case cancelled
    }

    enum SaveOutcome: Equatable {
        case saved(ItemSummary)
        /// COM-001: 같은 자료가 있어 새로 만들지 않았다.
        case duplicate(ItemSummary)
        /// COM-001 규칙 7: 같은 자료가 휴지통에 있다.
        case inTrash(ItemSummary)
        case sessionExpired
        case failed(SaveFailure)
        case cancelled
    }

    private static let path = "/items"
    private static let uploadsPath = "/uploads"
    private static let unauthorizedStatus = 401
    private static let tooLargeStatus = 413
    private static let unsupportedFormatStatus = 415
    private static let successStatuses = 200..<300
    private static let sessionExpiredCode = "session_expired"

    private struct SaveBody: Encodable {
        let kind: String
        let url: String?
        let text: String?
        let uploadId: String?
    }

    private struct CreateUploadBody: Encodable {
        let fileName: String
        let size: Int
    }

    private struct UploadBody: Decodable {
        let uploadId: String
        let uploadUrl: String
    }

    private struct SaveResultBody: Decodable {
        enum Result: String, Decodable {
            case saved
            case duplicate
            case inTrash
        }

        let result: Result
        let item: ItemSummary
    }

    /// api/openapi.yaml `Error`. 413은 `fileName`·`bytes`, 415는 `fileExtension`을 함께 준다.
    private struct ErrorBody: Decodable {
        let code: String
        let fileName: String?
        let bytes: Int?
        let fileExtension: String?
    }

    @MainActor
    static func save(
        _ save: SaveRequest,
        transport: any HTTPTransport,
        accessToken: String,
        idempotencyKey: UUID
    ) async -> SaveOutcome {
        let headers = ["Idempotency-Key": idempotencyKey.uuidString.lowercased()]
        switch await post(path, body: saveBody(save), headers: headers, transport: transport, accessToken: accessToken) {
        case .success(let response): return outcome(of: response)
        case .failure(.cancelled): return .cancelled
        case .failure(let error): return .failed(failure(of: error))
        }
    }

    /// 파일 업로드 자리를 받는다. 여기서는 크기만 거른다(형식은 저장 때 판정).
    @MainActor
    static func createUpload(
        fileName: String,
        size: Int,
        transport: any HTTPTransport,
        accessToken: String
    ) async -> UploadOutcome {
        let body = CreateUploadBody(fileName: fileName, size: size)
        let response: HTTPResponse
        switch await post(uploadsPath, body: body, headers: [:], transport: transport, accessToken: accessToken) {
        case .success(let received): response = received
        case .failure(.cancelled): return .cancelled
        case .failure(let error): return .failed(failure(of: error))
        }
        if isSessionExpired(response) { return .sessionExpired }
        guard successStatuses.contains(response.status),
              let upload = decode(UploadBody.self, from: response.body) else {
            return .failed(rejection(of: response))
        }
        return .created(uploadID: upload.uploadId, uploadURL: upload.uploadUrl)
    }

    @MainActor
    static func post(
        _ path: String,
        body: some Encodable,
        headers: [String: String],
        transport: any HTTPTransport,
        accessToken: String
    ) async -> Result<HTTPResponse, HTTPTransportError> {
        let request = HTTPRequest(
            method: .post,
            path: path,
            headers: headers.merging([
                "Authorization": "Bearer \(accessToken)",
                "Content-Type": "application/json",
            ]) { own, _ in own },
            body: encode(body)
        )
        do {
            return .success(try await transport.send(request))
        } catch {
            return .failure(error)
        }
    }

    private static func failure(of error: HTTPTransportError) -> SaveFailure {
        switch error {
        case .unreachable: .disconnected
        case .timedOut: .timedOut
        // 취소는 부르는 쪽이 먼저 거른다.
        case .cancelled: .serverError
        }
    }

    private static func outcome(of response: HTTPResponse) -> SaveOutcome {
        if isSessionExpired(response) { return .sessionExpired }
        guard successStatuses.contains(response.status),
              let body = decode(SaveResultBody.self, from: response.body) else {
            return .failed(rejection(of: response))
        }
        switch body.result {
        case .saved: return .saved(body.item)
        case .duplicate: return .duplicate(body.item)
        case .inTrash: return .inTrash(body.item)
        }
    }

    static func isSessionExpired(_ response: HTTPResponse) -> Bool {
        response.status == unauthorizedStatus
            && decode(ErrorBody.self, from: response.body)?.code == sessionExpiredCode
    }

    /// 2xx 밖의 응답. 파일 크기·형식 거절(COM-004)만 이유를 살리고 나머지는 `서버 오류`다.
    private static func rejection(of response: HTTPResponse) -> SaveFailure {
        let error = decode(ErrorBody.self, from: response.body)
        switch response.status {
        case tooLargeStatus:
            if let fileName = error?.fileName, let bytes = error?.bytes {
                return .tooLarge(fileName: fileName, bytes: bytes)
            }
        case unsupportedFormatStatus:
            if let fileExtension = error?.fileExtension {
                return .unsupportedFormat(fileExtension: fileExtension)
            }
        default:
            break
        }
        return .serverError
    }

    private static func saveBody(_ save: SaveRequest) -> SaveBody {
        switch save {
        case .link(let url): SaveBody(kind: "link", url: url, text: nil, uploadId: nil)
        case .text(let text): SaveBody(kind: "text", url: nil, text: text, uploadId: nil)
        case .file(let uploadID): SaveBody(kind: "file", url: nil, text: nil, uploadId: uploadID)
        }
    }

    private static func encode(_ body: some Encodable) -> String {
        // 고정 모양의 구조체라 인코딩은 실패하지 않는다.
        let data = (try? JSONEncoder().encode(body)) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }

    static func decode<T: Decodable>(_ type: T.Type, from body: [UInt8]) -> T? {
        try? JSONDecoder().decode(type, from: Data(body))
    }
}
