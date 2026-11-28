#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import GrepCore

/// `GET /me`를 보내고 응답을 해석한다(api/openapi.yaml `getMe`).
public enum MeAPI {
    public enum Outcome: Equatable {
        case loaded(itemCount: Int)
        /// 401 `session_expired`. 세션이 30일 미사용이거나 90일을 넘었다(ACC-001 값).
        case sessionExpired
        /// 그 밖의 실패. 응답 없음, 다른 상태 코드, 계약과 다른 본문.
        case failed
        case cancelled
    }

    private static let path = "/me"
    private static let okStatus = 200
    private static let unauthorizedStatus = 401
    private static let sessionExpiredCode = "session_expired"

    private struct MeBody: Decodable {
        public let itemCount: Int
    }

    private struct ErrorBody: Decodable {
        public let code: String
    }

    @MainActor
    public static func load(transport: any HTTPTransport, accessToken: String) async -> Outcome {
        let request = HTTPRequest(method: .get, path: path, headers: ["Authorization": "Bearer \(accessToken)"])
        let response: HTTPResponse
        do {
            response = try await transport.send(request)
        } catch {
            return error == .cancelled ? .cancelled : .failed
        }
        switch response.status {
        case okStatus:
            guard let me = decode(MeBody.self, from: response.body) else { return .failed }
            return .loaded(itemCount: me.itemCount)
        case unauthorizedStatus:
            return decode(ErrorBody.self, from: response.body)?.code == sessionExpiredCode ? .sessionExpired : .failed
        default:
            return .failed
        }
    }

    private static func decode<T: Decodable>(_ type: T.Type, from body: [UInt8]) -> T? {
        try? JSONDecoder().decode(type, from: Data(body))
    }
}
