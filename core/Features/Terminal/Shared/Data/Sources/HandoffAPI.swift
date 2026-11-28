
import GrepCore
import TerminalDomain
import GrepData

/// 넘길 글 API(api/openapi.yaml `createHandoff`). 응답 해석까지만 한다.
public enum HandoffAPI {
    public enum Outcome: Equatable {
        case composed(HandoffResult)
        /// 번호 중 하나라도 없거나 휴지통에 있다. 서버는 아무것도 만들지 않았다(ARC-001 규칙 10).
        case notFound(numbers: [Int])
        /// `넘기기 <묶음>`의 묶음이 없다(404, 번호 없음).
        case bundleNotFound
        case sessionExpired
        case failed(CommandFailure)
        case cancelled
    }

    private static let path = "/handoff"
    private static let notFoundStatus = 404
    private static let successStatuses = 200..<300

    /// `numbers`와 `bundle` 중 하나만 준다. nil인 칸은 보내지 않는다.
    private struct RequestBody: Encodable {
        public var numbers: [Int]?
        public var bundle: String?
    }

    private struct Body: Decodable {
        public struct Item: Decodable {
            public let number: Int
            public let title: String
        }

        public let text: String
        public let charCount: Int
        public let items: [Item]
        public let missingSummaryCount: Int
        public let bundle: String?
        public let removedCount: Int?
    }

    private struct NotFoundBody: Decodable {
        public let numbers: [Int]?
    }

    /// `numbers`의 순서대로 넘길 글을 받는다. 글과 글자 수는 서버가 준 그대로 쓴다(AC-13).
    @MainActor
    public static func compose(numbers: [Int], transport: any HTTPTransport, accessToken: String) async -> Outcome {
        await compose(RequestBody(numbers: numbers), transport: transport, accessToken: accessToken)
    }

    /// 묶음 자료를 번호 큰 순으로 넘긴다. 빠진 자료 수는 `removedCount`(ARC-003 규칙 10).
    @MainActor
    public static func compose(bundle: String, transport: any HTTPTransport, accessToken: String) async -> Outcome {
        await compose(RequestBody(bundle: bundle), transport: transport, accessToken: accessToken)
    }

    @MainActor
    private static func compose(_ body: RequestBody, transport: any HTTPTransport, accessToken: String) async -> Outcome {
        let response: HTTPResponse
        switch await ItemsAPI.post(path, body: body, headers: [:], transport: transport, accessToken: accessToken) {
        case .success(let received): response = received
        case .failure(.cancelled): return .cancelled
        case .failure(.unreachable): return .failed(.disconnected)
        case .failure(.timedOut): return .failed(.timedOut)
        }
        if ItemsAPI.isSessionExpired(response) { return .sessionExpired }
        if response.status == notFoundStatus {
            let missing = ItemsAPI.decode(NotFoundBody.self, from: response.body)?.numbers ?? []
            if !missing.isEmpty { return .notFound(numbers: missing) }
            if body.bundle != nil { return .bundleNotFound }
        }
        guard successStatuses.contains(response.status),
              let body = ItemsAPI.decode(Body.self, from: response.body) else {
            return .failed(.serverError)
        }
        return .composed(HandoffResult(
            items: body.items.map { ItemRef(number: $0.number, title: $0.title) },
            bundle: body.bundle,
            removedCount: body.removedCount ?? 0,
            charCount: body.charCount,
            missingSummaryCount: body.missingSummaryCount,
            text: body.text
        ))
    }
}
