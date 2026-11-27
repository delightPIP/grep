import FeatureTerminalInterface
import GrepCore

/// 휴지통 API(api/openapi.yaml `trashItems`·`restoreItems`). 응답 해석까지만 한다.
enum TrashAPI {
    enum MoveOutcome: Equatable {
        case moved([ItemRef])
        case notFound(numbers: [Int])
        case sessionExpired
        case failed(CommandFailure)
        case cancelled
    }

    private static let trashPath = "/items/trash"
    private static let restorePath = "/items/restore"
    private static let notFoundStatus = 404
    private static let successStatuses = 200..<300

    private struct NumbersBody: Encodable {
        let numbers: [Int]
    }

    private struct ItemRefListBody: Decodable {
        struct Item: Decodable {
            let number: Int
            let title: String
        }

        let items: [Item]
    }

    private struct NotFoundBody: Decodable {
        let numbers: [Int]
    }

    @MainActor
    static func trash(numbers: [Int], transport: any HTTPTransport, accessToken: String) async -> MoveOutcome {
        await move(path: trashPath, numbers: numbers, transport: transport, accessToken: accessToken)
    }

    @MainActor
    static func restore(numbers: [Int], transport: any HTTPTransport, accessToken: String) async -> MoveOutcome {
        await move(path: restorePath, numbers: numbers, transport: transport, accessToken: accessToken)
    }

    @MainActor
    private static func move(
        path: String,
        numbers: [Int],
        transport: any HTTPTransport,
        accessToken: String
    ) async -> MoveOutcome {
        let response: HTTPResponse
        switch await ItemsAPI.post(
            path, body: NumbersBody(numbers: numbers), headers: [:], transport: transport, accessToken: accessToken
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
              let body = ItemsAPI.decode(ItemRefListBody.self, from: response.body) else {
            return .failed(.serverError)
        }
        return .moved(body.items.map { ItemRef(number: $0.number, title: $0.title) })
    }
}
