import GrepCore

public extension BundleAPI.Outcome {
    var fetchOutcome: FetchOutcome<Value> {
        switch self {
        case .success(let value): .success(value)
        case .sessionExpired: .sessionExpired
        case .rejected, .failed: .failed
        case .cancelled: .cancelled
        }
    }
}

public extension SavedSearchAPI.Outcome {
    var fetchOutcome: FetchOutcome<Value> {
        switch self {
        case .success(let value): .success(value)
        case .sessionExpired: .sessionExpired
        case .notFound, .rejected, .failed: .failed
        case .cancelled: .cancelled
        }
    }
}

public extension ConnectionsAPI.Outcome {
    var fetchOutcome: FetchOutcome<Value> {
        switch self {
        case .success(let value): .success(value)
        case .sessionExpired: .sessionExpired
        case .notFound, .failed: .failed
        case .cancelled: .cancelled
        }
    }
}
