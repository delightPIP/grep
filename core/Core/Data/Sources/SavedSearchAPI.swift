#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

import GrepCore

/// 찾아두기 API(api/openapi.yaml `listSavedSearches`·`saveSearch`·`deleteSavedSearch`). 응답 해석까지만 한다.
public enum SavedSearchAPI {
    public enum Outcome<Value: Equatable>: Equatable {
        case success(Value)
        /// 404. 지울 저장한 찾기가 없다.
        case notFound
        /// 400. 검색어가 규칙(1~40자)에 맞지 않는다.
        case rejected
        case sessionExpired
        case failed(CommandFailure)
        case cancelled
    }

    public struct Saved: Equatable {
        public let query: String
        public let count: Int
        /// 200(이미 찾아둠). 201이면 false.
        public let already: Bool
    }

    private static let path = "/saved-searches"
    private static let createdStatus = 201
    private static let badRequestStatus = 400
    private static let notFoundStatus = 404
    private static let successStatuses = 200..<300

    private struct QueryBody: Encodable {
        public let query: String
    }

    private struct ListBody: Decodable {
        public let searches: [SavedSearchEntry]
    }

    @MainActor
    public static func list(transport: any HTTPTransport, accessToken: String) async -> Outcome<[SavedSearchEntry]> {
        let result = await send(HTTPRequest(method: .get, path: path), transport: transport, accessToken: accessToken)
        return outcome(of: result) { _, body in ItemsAPI.decode(ListBody.self, from: body)?.searches }
    }

    @MainActor
    public static func save(query: String, transport: any HTTPTransport, accessToken: String) async -> Outcome<Saved> {
        let body = String(decoding: (try? JSONEncoder().encode(QueryBody(query: query))) ?? Data(), as: UTF8.self)
        let request = HTTPRequest(method: .put, path: path, headers: ["Content-Type": "application/json"], body: body)
        let result = await send(request, transport: transport, accessToken: accessToken)
        return outcome(of: result) { status, body in
            ItemsAPI.decode(SavedSearchEntry.self, from: body).map {
                Saved(query: $0.query, count: $0.count, already: status != createdStatus)
            }
        }
    }

    @MainActor
    public static func delete(query: String, transport: any HTTPTransport, accessToken: String) async -> Outcome<Bool> {
        let request = HTTPRequest(method: .delete, path: "\(path)?query=\(BrowseAPI.percentEncoded(query))")
        let result = await send(request, transport: transport, accessToken: accessToken)
        return outcome(of: result) { _, _ in true }
    }

    @MainActor
    private static func send(
        _ request: HTTPRequest,
        transport: any HTTPTransport,
        accessToken: String
    ) async -> Result<HTTPResponse, HTTPTransportError> {
        let authorized = HTTPRequest(
            method: request.method,
            path: request.path,
            headers: request.headers.merging(["Authorization": "Bearer \(accessToken)"]) { own, _ in own },
            body: request.body
        )
        do {
            return .success(try await transport.send(authorized))
        } catch {
            return .failure(error)
        }
    }

    private static func outcome<Value>(
        of result: Result<HTTPResponse, HTTPTransportError>,
        decode: (Int, [UInt8]) -> Value?
    ) -> Outcome<Value> {
        let response: HTTPResponse
        switch result {
        case .success(let received): response = received
        case .failure(.cancelled): return .cancelled
        case .failure(.unreachable): return .failed(.disconnected)
        case .failure(.timedOut): return .failed(.timedOut)
        }
        if ItemsAPI.isSessionExpired(response) { return .sessionExpired }
        if response.status == notFoundStatus { return .notFound }
        if response.status == badRequestStatus { return .rejected }
        guard successStatuses.contains(response.status), let value = decode(response.status, response.body) else {
            return .failed(.serverError)
        }
        return .success(value)
    }
}
