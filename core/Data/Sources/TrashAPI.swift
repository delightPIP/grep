#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

import GrepCore

/// 휴지통 API(api/openapi.yaml `trashItems`·`restoreItems`·`listTrash`·`emptyTrash`). 응답 해석까지만 한다.
public enum TrashAPI {
    public enum MoveOutcome: Equatable {
        case moved([ItemRef])
        case notFound(numbers: [Int])
        case sessionExpired
        case failed(CommandFailure)
        case cancelled
    }

    public enum ListOutcome: Equatable {
        case page(total: Int, items: [TrashEntry], nextCursor: String?)
        case sessionExpired
        case failed(CommandFailure)
        case cancelled
    }

    public enum EmptyOutcome: Equatable {
        case emptied(count: Int)
        case sessionExpired
        case failed(CommandFailure)
        case cancelled
    }

    private static let trashPath = "/items/trash"
    private static let restorePath = "/items/restore"
    private static let notFoundStatus = 404
    private static let successStatuses = 200..<300
    private static let unreservedBytes = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~".utf8)

    private struct NumbersBody: Encodable {
        public let numbers: [Int]
    }

    private struct ItemRefListBody: Decodable {
        public struct Item: Decodable {
            public let number: Int
            public let title: String
        }

        public let items: [Item]
    }

    private struct NotFoundBody: Decodable {
        public let numbers: [Int]
    }

    private struct TrashPageBody: Decodable {
        public let items: [TrashEntry]
        public let total: Int
        public let nextCursor: String?
    }

    private struct CountBody: Decodable {
        public let count: Int
    }

    @MainActor
    public static func trash(numbers: [Int], transport: any HTTPTransport, accessToken: String) async -> MoveOutcome {
        await move(path: trashPath, numbers: numbers, transport: transport, accessToken: accessToken)
    }

    @MainActor
    public static func restore(numbers: [Int], transport: any HTTPTransport, accessToken: String) async -> MoveOutcome {
        await move(path: restorePath, numbers: numbers, transport: transport, accessToken: accessToken)
    }

    @MainActor
    public static func list(
        limit: Int,
        cursor: String?,
        transport: any HTTPTransport,
        accessToken: String
    ) async -> ListOutcome {
        let query = "limit=\(limit)" + (cursor.map { "&cursor=\(percentEncoded($0))" } ?? "")
        let request = HTTPRequest(
            method: .get,
            path: "\(trashPath)?\(query)",
            headers: ["Authorization": "Bearer \(accessToken)"]
        )
        let response: HTTPResponse
        do {
            response = try await transport.send(request)
        } catch {
            switch error {
            case .cancelled: return .cancelled
            case .unreachable: return .failed(.disconnected)
            case .timedOut: return .failed(.timedOut)
            }
        }
        if ItemsAPI.isSessionExpired(response) { return .sessionExpired }
        guard successStatuses.contains(response.status),
              let body = ItemsAPI.decode(TrashPageBody.self, from: response.body) else {
            return .failed(.serverError)
        }
        return .page(total: body.total, items: body.items, nextCursor: body.nextCursor)
    }

    @MainActor
    public static func empty(transport: any HTTPTransport, accessToken: String) async -> EmptyOutcome {
        let request = HTTPRequest(
            method: .delete,
            path: trashPath,
            headers: ["Authorization": "Bearer \(accessToken)"]
        )
        let response: HTTPResponse
        do {
            response = try await transport.send(request)
        } catch {
            switch error {
            case .cancelled: return .cancelled
            case .unreachable: return .failed(.disconnected)
            case .timedOut: return .failed(.timedOut)
            }
        }
        if ItemsAPI.isSessionExpired(response) { return .sessionExpired }
        guard successStatuses.contains(response.status),
              let body = ItemsAPI.decode(CountBody.self, from: response.body) else {
            return .failed(.serverError)
        }
        return .emptied(count: body.count)
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

    private static func percentEncoded(_ value: String) -> String {
        value.utf8.map { byte in
            unreservedBytes.contains(byte)
                ? String(UnicodeScalar(byte))
                : "%" + (byte < 16 ? "0" : "") + String(byte, radix: 16, uppercase: true)
        }.joined()
    }
}
