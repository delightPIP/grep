import GrepDomain


// MARK: 땅굴 두더지(#175, 디자인 시스템 9절)

extension TerminalViewState.Line {
    /// 이 줄이 찍힐 때 두더지가 할 동작. 없으면 nil.
    /// 찾기 결과는 찾기, 새 저장은 저장, 복사 성공은 넘기기, `✗` 줄은 틀림이다.
    public var moleAction: Mole.Action? {
        switch self {
        case .searchResult, .noResults:
            .seek
        case .saved:
            .save
        case .handedOff:
            .handoff
        case .unknownCommand, .missingArgument, .missingTag, .saveFailed, .notFound, .invalidNumber,
             .handoffFailed, .commandFailed, .bundleNotFound, .notInBundle, .bundleNameInvalid, .oneNumberOnly,
             .savedSearchPeriod, .savedSearchTooLong, .savedSearchNotFound, .connectionNotFound:
            .error
        case .prompt, .alreadySaved, .inTrash, .recentList, .picked, .handoffConfirm, .cancelled, .welcome,
             .guide, .about, .reconnected, .dropConfirm, .dropped, .revived, .binList, .binEmptyConfirm,
             .binEmptied, .revised, .tagsRemoved, .samplesSaved, .unpicked, .pickCleared,
             .signOutEverywhereConfirm, .bundleList, .bundleAdded, .bundleView, .bundleUnpicked,
             .bundleDeleteConfirm, .bundleDeleted, .folderHint, .itemDetail, .searchSaved, .savedSearchList,
             .savedSearchDeleteConfirm, .savedSearchDeleted, .connectionList, .disconnectConfirm,
             .disconnected, .connectionEnded, .importPrompt, .importProgress, .importFinished, .importSuggest:
            nil
        }
    }
}

extension TerminalViewState {
    /// 새로 찍는 줄 가운데 마지막 동작으로 두더지를 바꾼다. 같은 동작이어도 `seq`를 늘려 뷰가 다시 틀게 한다.
    /// 동작이 없는 줄만 찍으면 그대로 둔다.
    public func movingMole(for added: [Line]) -> TerminalViewState {
        guard let action = added.lazy.compactMap(\.moleAction).last else { return self }
        var next = self
        next.mole = Mole(action: action, seq: (mole?.seq ?? 0) + 1)
        return next
    }
}
