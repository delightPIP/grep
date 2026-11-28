import FeatureArchiveInterface
import FeatureSettingsInterface
import FeatureTerminalInterface
import JavaScriptKit
import RIBs

/// 로그인한 화면의 세 RIB(터미널·보관함·설정) 상태를 모아 웹 뷰 하나(`LoggedInViewBridge`)에 넘긴다.
/// 웹 뷰 계약(`web/support/view-state.ts`의 `LoggedInState`)은 탭 상태를 터미널 상태와 한 객체로 받는다.
@MainActor
final class LoggedInComposer {
    private var terminal = TerminalViewState()
    private var archive: ArchiveState?
    private var settings: SettingsState?
    private var render: ((JSObject) -> Void)?
    /// 지금 붙은 탭 뷰. 각 RIB의 Router가 쥐고 있어 약하게 든다.
    private weak var archiveView: WebArchiveView?
    private weak var settingsView: WebSettingsView?

    /// 새 터미널 화면이 붙었다(로그인할 때마다). 전 세션의 탭 상태를 버린다.
    func attach(render: @escaping (JSObject) -> Void) {
        archive = nil
        settings = nil
        self.render = render
    }

    func showTerminal(_ state: TerminalViewState) {
        terminal = state
        flush()
    }

    func makeArchiveView() -> any ArchiveViewContract {
        let view = WebArchiveView(composer: self)
        archiveView = view
        return view
    }

    func makeSettingsView() -> any SettingsViewContract {
        let view = WebSettingsView(composer: self)
        settingsView = view
        return view
    }

    func sendArchive(_ action: ArchiveViewAction) {
        archiveView?.listener?.handle(action)
    }

    func sendSettings(_ action: SettingsViewAction) {
        settingsView?.listener?.handle(action)
    }

    fileprivate func showArchive(_ state: ArchiveState?) {
        archive = state
        flush()
    }

    fileprivate func showSettings(_ state: SettingsState?) {
        settings = state
        flush()
    }

    private func flush() {
        render?(terminal.bridgeValue(archive: archive, settings: settings))
    }
}

/// 보관함 RIB의 뷰. 자기 DOM을 갖지 않고 상태를 `LoggedInComposer`에 넘긴다.
@MainActor
final class WebArchiveView: ArchiveViewContract {
    weak var listener: (any ArchivePresentableListener)?
    private weak var composer: LoggedInComposer?

    init(composer: LoggedInComposer) {
        self.composer = composer
    }

    func render(_ state: ArchiveState?) { composer?.showArchive(state) }
}

/// 설정 RIB의 뷰. 자기 DOM을 갖지 않고 상태를 `LoggedInComposer`에 넘긴다.
@MainActor
final class WebSettingsView: SettingsViewContract {
    weak var listener: (any SettingsPresentableListener)?
    private weak var composer: LoggedInComposer?

    init(composer: LoggedInComposer) {
        self.composer = composer
    }

    func render(_ state: SettingsState?) { composer?.showSettings(state) }
}
