import FeatureTerminalAndroid

/// 터미널 화면 브리지(#79 2단계 전체 구현 전 최소 스텁).
public protocol TerminalViewBridge {
    func render(itemCount: Int32, isOffline: Bool)
}

public final class TerminalScreenHandle: Sendable {
    private let screenID: Int64

    public init(screenID: Int64) {
        self.screenID = screenID
    }

    public func attach(view: any TerminalViewBridge) {
        nonisolated(unsafe) let view = view
        MainActor.assumeIsolated {
            screen?.attach { state in
                view.render(itemCount: Int32(state.itemCount ?? -1), isOffline: state.isOffline)
            }
        }
    }

    public func detach() {
        MainActor.assumeIsolated { screen?.detach() }
    }

    public func submitCommand(text: String) {
        MainActor.assumeIsolated { screen?.send(.submitted(text)) }
    }

    @MainActor private var screen: TerminalAndroidScreen? {
        controller?.screen(id: screenID, as: TerminalAndroidScreen.self)
    }
}
