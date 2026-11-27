import GrepAndroidSupport

public protocol PlaceholderViewBridge {
    func render(title: String, actionTitle: String)
}

public final class PlaceholderScreenHandle: Sendable {
    private let screenID: Int64

    public init(screenID: Int64) {
        self.screenID = screenID
    }

    public func attach(view: any PlaceholderViewBridge) {
        nonisolated(unsafe) let view = view
        MainActor.assumeIsolated {
            screen?.attach { view.render(title: $0.title, actionTitle: $0.actionTitle) }
        }
    }

    public func detach() {
        MainActor.assumeIsolated { screen?.detach() }
    }

    public func actionTapped() {
        MainActor.assumeIsolated { screen?.tapAction() }
    }

    @MainActor private var screen: PlaceholderScreen? {
        controller?.screen(id: screenID, as: PlaceholderScreen.self)
    }
}
