import GrepDomain

/// 자동 묶음의 갈래(ARC-007).
public enum AutoGroup: String, Equatable, Sendable, CaseIterable {
    case format
    case source
    case date
    case tag
}

/// 자동 묶음 한 줄. `value`는 갈래마다 다르다.
/// format: link·text·image·file / source: 호스트 또는 `direct` / date: today·week·month·earlier / tag: 태그 낱말.
public struct AutoGroupEntry: Equatable, Sendable {
    public let group: AutoGroup
    public let value: String
    public let count: Int

    public init(group: AutoGroup, value: String, count: Int) {
        self.group = group
        self.value = value
        self.count = count
    }
}

/// 보관함 목록을 무엇으로 거르는지.
public enum ArchiveFilter: Equatable, Sendable {
    case all
    case auto(group: AutoGroup, value: String)
    case bundle(name: String)
    case savedSearch(query: String)
}
