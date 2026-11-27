import GrepAndroidSupport
import RIBs
import RIBsAndroid

/// JNI 진입점이 부르는 RIB 트리 하나. 전체 앱(`GrepAppController`)과 피처별 단독 실행(`FeatureDemoController`)이 따른다.
@MainActor
public protocol RibController: AnyObject {
    func start()
    func screen<Screen: AndroidScreen>(id: Int64, as type: Screen.Type) -> Screen?
    func stop()
    var encodedTree: String { get }
}

/// 렌더러·등록부·루트 화면 묶음. 두 컨트롤러가 함께 쓴다.
@MainActor
struct RenderStack {
    let renderer: AndroidRenderer
    let registry = ScreenRegistry()
    let host: AndroidViewHost<HostRootScreen>

    init(sink: @escaping (String) -> Void) {
        renderer = AndroidRenderer(sink: sink)
        host = AndroidViewHost(renderer: renderer)
    }

    var context: ScreenContext { ScreenContext(renderer: renderer, registry: registry) }
}
