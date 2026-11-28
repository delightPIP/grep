import RIBs

extension Interactor {
    /// 활성 구간에 묶인 Task를 띄운다. 비활성화되면 취소된다.
    /// 활성 구간 밖에서 부르는 것은 코어의 버그라 실패시킨다(carti-RIBs-Swift 샘플과 같다).
    @discardableResult
    public func startTask(_ operation: @escaping @MainActor () async -> Void) -> Task<Void, Never> {
        do {
            return try task(operation)
        } catch {
            preconditionFailure("\(type(of: self)) started a task outside its active scope: \(error)")
        }
    }
}
