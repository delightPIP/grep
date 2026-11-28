#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import GrepCore

/// 그렙을 열 때·모든 기기 로그아웃 때 부르는 연결 API(api/openapi.yaml `takeConnectionNotices`·`endAllConnections`).
/// 둘 다 실패해도 화면 흐름을 막지 않으므로 결과는 성공 여부만 본다.
public enum ConnectionNoticesAPI {
    private static let noticesPath = "/connections/notices"
    private static let revokeAllPath = "/connections/revoke-all"
    private static let successStatuses = 200..<300

    private struct NoticesBody: Decodable {
        public let ended: [ConnectionNotice]
    }

    /// 알릴 끊긴 연결. 받지 못하면 빈 배열(다음에 열 때 서버가 다시 준다).
    @MainActor
    public static func take(transport: any HTTPTransport, accessToken: String) async -> [ConnectionNotice] {
        guard let response = await post(noticesPath, transport: transport, accessToken: accessToken),
              successStatuses.contains(response.status),
              let body = try? JSONDecoder().decode(NoticesBody.self, from: Data(response.body)) else { return [] }
        return body.ended
    }

    /// 모든 AI 도구 연결을 끊는다(ACC-002 규칙 4). 실패해도 부른 쪽은 전역 로그아웃을 이어 간다.
    @MainActor
    public static func revokeAll(transport: any HTTPTransport, accessToken: String) async {
        _ = await post(revokeAllPath, transport: transport, accessToken: accessToken)
    }

    @MainActor
    private static func post(_ path: String, transport: any HTTPTransport, accessToken: String) async -> HTTPResponse? {
        let request = HTTPRequest(method: .post, path: path, headers: ["Authorization": "Bearer \(accessToken)"])
        return try? await transport.send(request)
    }
}
