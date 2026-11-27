import FeatureTerminalInterface
import GrepCore

/// 넘길 글 API(api/openapi.yaml `createHandoff`). 응답 해석까지만 한다.
enum HandoffAPI {
    enum Outcome: Equatable {
        case composed(HandoffResult)
        /// 번호 중 하나라도 없거나 휴지통에 있다. 서버는 아무것도 만들지 않았다(ARC-001 규칙 10).
        case notFound(numbers: [Int])
        case sessionExpired
        case failed(CommandFailure)
        case cancelled
    }

    private static let path = "/handoff"
    private static let notFoundStatus = 404
    private static let successStatuses = 200..<300

    private struct RequestBody: Encodable {
        let numbers: [Int]
    }

    private struct Body: Decodable {
        struct Item: Decodable {
            let number: Int
            let title: String
        }

        let text: String
        let charCount: Int
        let items: [Item]
        let missingSummaryCount: Int
    }

    private struct NotFoundBody: Decodable {
        let numbers: [Int]
    }

    /// `numbers`의 순서대로 넘길 글을 받는다. 글과 글자 수는 서버가 준 그대로 쓴다(AC-13).
    @MainActor
    static func compose(numbers: [Int], transport: any HTTPTransport, accessToken: String) async -> Outcome {
        let response: HTTPResponse
        switch await ItemsAPI.post(
            path, body: RequestBody(numbers: numbers), headers: [:], transport: transport, accessToken: accessToken
        ) {
        case .success(let received): response = received
        case .failure(.cancelled): return .cancelled
        case .failure(.unreachable): return .failed(.disconnected)
        case .failure(.timedOut): return .failed(.timedOut)
        }
        if ItemsAPI.isSessionExpired(response) { return .sessionExpired }
        if response.status == notFoundStatus,
           let missing = ItemsAPI.decode(NotFoundBody.self, from: response.body)?.numbers, !missing.isEmpty {
            return .notFound(numbers: missing)
        }
        guard successStatuses.contains(response.status),
              let body = ItemsAPI.decode(Body.self, from: response.body) else {
            return .failed(.serverError)
        }
        return .composed(HandoffResult(
            items: body.items.map { ItemRef(number: $0.number, title: $0.title) },
            charCount: body.charCount,
            missingSummaryCount: body.missingSummaryCount,
            text: body.text
        ))
    }
}
