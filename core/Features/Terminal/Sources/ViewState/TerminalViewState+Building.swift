#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FeatureTerminalInterface
import GrepCore
import RIBs

extension TerminalViewState {
    func with(input: String) -> TerminalViewState {
        var next = self
        next.input = input
        return next
    }

    func with(itemCount: Int?) -> TerminalViewState {
        var next = self
        next.itemCount = itemCount
        return next
    }

    func with(processingCount: Int) -> TerminalViewState {
        var next = self
        next.processingCount = processingCount
        return next
    }

    func with(isOffline: Bool) -> TerminalViewState {
        var next = self
        next.isOffline = isOffline
        return next
    }

    func with(selection: [ItemRef]) -> TerminalViewState {
        var next = self
        next.selection = selection
        return next
    }

    func with(revising: Revising?) -> TerminalViewState {
        var next = self
        next.revising = revising
        return next
    }

    /// 줄을 찍는다. 찍는 줄에 두더지 동작이 있으면 함께 넣는다(#175).
    func appending(lines added: [Line]) -> TerminalViewState {
        var next = movingMole(for: added)
        next.lines += added
        return next
    }
}
