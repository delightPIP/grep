#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

import GrepCore

/// 묶음 API(api/openapi.yaml `listBundles`·`getBundle`·`deleteBundle`·`addToBundle`·`removeFromBundle`). 응답 해석까지만 한다.
public enum BundleAPI {
    public enum Outcome<Value: Equatable>: Equatable {
        case success(Value)
        case rejected(Rejection)
        case sessionExpired
        case failed(CommandFailure)
        case cancelled
    }

    /// 서버가 거절한 이유(api `Error`).
    public enum Rejection: Equatable {
        /// 404이고 번호가 없다: 그 이름의 묶음이 없다.
        case bundleNotFound
        /// 404이고 번호가 있다: 없거나 휴지통에 있는 자료(ARC-001 규칙 10).
        case notFound(numbers: [Int])
        case invalidName(BundleNameProblem)
        case notInBundle(numbers: [Int])
    }

    public struct Page: Equatable {
        public let name: String
        public let total: Int
        public let items: [ItemSummary]
        public let nextCursor: String?
    }

    public struct Added: Equatable {
        public let name: String
        public let count: Int
        public let alreadyCount: Int
    }

    private static let bundlesPath = "/bundles"
    private static let badRequestStatus = 400
    private static let notFoundStatus = 404
    private static let successStatuses = 200..<300

    private struct NumbersBody: Encodable {
        public let numbers: [Int]
    }

    private struct ListBody: Decodable {
        public let bundles: [BundleEntry]
    }

    private struct PageBody: Decodable {
        public let name: String
        public let total: Int
        public let items: [ItemSummary]
        public let nextCursor: String?
    }

    private struct AddedBody: Decodable {
        public let name: String
        public let count: Int
        public let alreadyCount: Int
    }

    private struct CountBody: Decodable {
        public let count: Int
    }

    private struct ErrorBody: Decodable {
        public let code: String
        public let reason: String?
        public let numbers: [Int]?
    }

    @MainActor
    public static func list(transport: any HTTPTransport, accessToken: String) async -> Outcome<[BundleEntry]> {
        let result = await send(.get, bundlesPath, transport: transport, accessToken: accessToken)
        return outcome(of: result) { ItemsAPI.decode(ListBody.self, from: $0)?.bundles }
    }

    @MainActor
    public static func page(
        name: String,
        limit: Int,
        cursor: String?,
        transport: any HTTPTransport,
        accessToken: String
    ) async -> Outcome<Page> {
        let query = "limit=\(limit)" + (cursor.map { "&cursor=\(BrowseAPI.percentEncoded($0))" } ?? "")
        let result = await send(.get, "\(path(of: name))?\(query)", transport: transport, accessToken: accessToken)
        return outcome(of: result) { bytes in
            ItemsAPI.decode(PageBody.self, from: bytes).map {
                Page(name: $0.name, total: $0.total, items: $0.items, nextCursor: $0.nextCursor)
            }
        }
    }

    @MainActor
    public static func delete(name: String, transport: any HTTPTransport, accessToken: String) async -> Outcome<Bool> {
        let result = await send(.delete, path(of: name), transport: transport, accessToken: accessToken)
        return outcome(of: result) { _ in true }
    }

    @MainActor
    public static func add(
        name: String,
        numbers: [Int],
        transport: any HTTPTransport,
        accessToken: String
    ) async -> Outcome<Added> {
        let result = await ItemsAPI.post(
            "\(path(of: name))/items", body: NumbersBody(numbers: numbers), headers: [:],
            transport: transport, accessToken: accessToken
        )
        return outcome(of: result) { bytes in
            ItemsAPI.decode(AddedBody.self, from: bytes).map {
                Added(name: $0.name, count: $0.count, alreadyCount: $0.alreadyCount)
            }
        }
    }

    /// 뺀 뒤 남은 건수.
    @MainActor
    public static func remove(
        name: String,
        numbers: [Int],
        transport: any HTTPTransport,
        accessToken: String
    ) async -> Outcome<Int> {
        let result = await ItemsAPI.post(
            "\(path(of: name))/items/remove", body: NumbersBody(numbers: numbers), headers: [:],
            transport: transport, accessToken: accessToken
        )
        return outcome(of: result) { ItemsAPI.decode(CountBody.self, from: $0)?.count }
    }

    private static func path(of name: String) -> String {
        "\(bundlesPath)/\(BrowseAPI.percentEncoded(name))"
    }

    @MainActor
    private static func send(
        _ method: HTTPRequest.Method,
        _ path: String,
        transport: any HTTPTransport,
        accessToken: String
    ) async -> Result<HTTPResponse, HTTPTransportError> {
        let request = HTTPRequest(method: method, path: path, headers: ["Authorization": "Bearer \(accessToken)"])
        do {
            return .success(try await transport.send(request))
        } catch {
            return .failure(error)
        }
    }

    private static func outcome<Value>(
        of result: Result<HTTPResponse, HTTPTransportError>,
        decode: ([UInt8]) -> Value?
    ) -> Outcome<Value> {
        let response: HTTPResponse
        switch result {
        case .success(let received): response = received
        case .failure(.cancelled): return .cancelled
        case .failure(.unreachable): return .failed(.disconnected)
        case .failure(.timedOut): return .failed(.timedOut)
        }
        if ItemsAPI.isSessionExpired(response) { return .sessionExpired }
        if let rejection = rejection(of: response) { return .rejected(rejection) }
        guard successStatuses.contains(response.status), let value = decode(response.body) else {
            return .failed(.serverError)
        }
        return .success(value)
    }

    private static func rejection(of response: HTTPResponse) -> Rejection? {
        let body = ItemsAPI.decode(ErrorBody.self, from: response.body)
        switch response.status {
        case notFoundStatus:
            guard let numbers = body?.numbers, !numbers.isEmpty else { return .bundleNotFound }
            return .notFound(numbers: numbers)
        case badRequestStatus:
            switch body?.code {
            case "invalid_bundle_name":
                return .invalidName(body?.reason.flatMap(BundleNameProblem.init(rawValue:)) ?? .format)
            case "not_in_bundle":
                return body?.numbers.map { .notInBundle(numbers: $0) }
            default:
                return nil
            }
        default:
            return nil
        }
    }
}
