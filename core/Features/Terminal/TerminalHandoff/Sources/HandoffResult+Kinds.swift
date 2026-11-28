import GrepCore
import GrepData
import TerminalCommandKit
import TerminalDomain

extension HandoffResult {
    /// 서버는 넘긴 자료의 번호·제목만 준다. 고를 때 받은 종류·출처를 번호로 찾아 채운다(ARC-003 규칙 14).
    /// `known`에 없는 자료(`넘기기 <묶음>`)는 받은 값 그대로 둔다.
    func resolvingKinds(from known: [ItemRef]) -> HandoffResult {
        let picked = Dictionary(known.map { ($0.number, $0) }) { first, _ in first }
        return HandoffResult(
            items: items.map { item in
                picked[item.number].map { ItemRef(number: item.number, title: item.title, kind: $0.kind, source: $0.source) }
                    ?? item
            },
            bundle: bundle,
            removedCount: removedCount,
            charCount: charCount,
            missingSummaryCount: missingSummaryCount,
            text: text
        )
    }
}

extension HandoffAPI.Outcome {
    func resolvingKinds(from known: [ItemRef]) -> Self {
        guard case .composed(let result) = self else { return self }
        return .composed(result.resolvingKinds(from: known))
    }
}
