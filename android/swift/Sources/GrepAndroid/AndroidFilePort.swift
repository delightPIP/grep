import GrepCore

/// Kotlin이 구현하는 파일 업로드 포트 실행자.
@MainActor
public protocol AndroidFileExecutor: AnyObject {
    func startUpload(requestID: Int64, fileID: String, uploadURL: String)
    func cancelUpload(requestID: Int64)
    func release(fileID: String)
}

/// Android의 `FilePort` 어댑터.
@MainActor
public final class AndroidFilePort: FilePort {
    private typealias Completion = CheckedContinuation<Result<Void, FileUploadError>, Never>

    private let executor: any AndroidFileExecutor
    private var pending: [Int64: Completion] = [:]
    private var nextRequestID: Int64 = 1

    public init(executor: any AndroidFileExecutor) {
        self.executor = executor
    }

    public func upload(_ fileID: String, to uploadURL: String) async throws(FileUploadError) {
        let requestID = nextRequestID
        nextRequestID += 1
        let result = await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: Completion) in
                guard !Task.isCancelled else {
                    continuation.resume(returning: .failure(.cancelled))
                    return
                }
                pending[requestID] = continuation
                executor.startUpload(requestID: requestID, fileID: fileID, uploadURL: uploadURL)
            }
        } onCancel: {
            Task { @MainActor in self.cancel(requestID) }
        }
        try result.get()
    }

    public func release(_ fileID: String) {
        executor.release(fileID: fileID)
    }

    public func completeUpload(requestID: Int64) {
        pending.removeValue(forKey: requestID)?.resume(returning: .success(()))
    }

    public func failUpload(requestID: Int64, reason: String) {
        let error: FileUploadError = switch reason {
        case "cancelled": .cancelled
        case "timedOut": .timedOut
        case "rejected": .rejected
        case "missingFile": .missingFile
        default: .unreachable
        }
        pending.removeValue(forKey: requestID)?.resume(returning: .failure(error))
    }

    private func cancel(_ requestID: Int64) {
        guard let continuation = pending.removeValue(forKey: requestID) else { return }
        executor.cancelUpload(requestID: requestID)
        continuation.resume(returning: .failure(.cancelled))
    }
}
