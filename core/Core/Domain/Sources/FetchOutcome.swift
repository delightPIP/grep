/// 화면 칸 하나를 채우는 조회 결과. 실패 이유를 화면에 나누어 보이지 않는 곳(보관함·설정)에서 쓴다.
public enum FetchOutcome<Value: Equatable>: Equatable {
    case success(Value)
    case sessionExpired
    case failed
    case cancelled

    public func map<Other>(_ transform: (Value) -> Other) -> FetchOutcome<Other> {
        switch self {
        case .success(let value): .success(transform(value))
        case .sessionExpired: .sessionExpired
        case .failed: .failed
        case .cancelled: .cancelled
        }
    }
}
