#if os(Android)
import Android
import GrepAndroid
import GrepAppRoot
import GrepCore
import RIBsAndroid

// Kotlin `com.unwrap.grep.core.SwiftBridge`(`:bridge` 모듈)와 짝을 이루는 JNI 진입점.
// 화면 상태·입력 및 플랫폼 포트는 swift-java 핸들(`*Handle.swift`)로 오간다.
// 문자열은 모두 UTF-8 byte[]로 주고받는다. 모든 진입점은 Android 메인 스레드에서 불린다고 가정한다.

public typealias Env = UnsafeMutablePointer<JNIEnv?>

private let bridgeClassName = "com/unwrap/grep/core/SwiftBridge"

@MainActor private var renderTarget: RenderTarget?
nonisolated(unsafe) private var javaVM: UnsafeMutablePointer<JavaVM?>?

private struct RenderTarget: @unchecked Sendable {
    let bridgeClass: jclass
    let onRender: jmethodID
}

@_cdecl("JNI_OnLoad")
public func JNI_OnLoad(vm: UnsafeMutablePointer<JavaVM?>, reserved: UnsafeMutableRawPointer?) -> jint {
    javaVM = vm
    return jint(JNI_VERSION_1_6)
}

@_cdecl("Java_com_unwrap_grep_core_SwiftBridge_nativeAttachMainLooper")
public func nativeAttachMainLooper(env: Env, thiz: jobject) -> jboolean {
    MainActor.assumeIsolated { AndroidMainLooper.attach() } ? jboolean(JNI_TRUE) : jboolean(JNI_FALSE)
}

@_cdecl("Java_com_unwrap_grep_core_SwiftBridge_nativeIsMainQueueDraining")
public func nativeIsMainQueueDraining(env: Env, thiz: jobject) -> jboolean {
    MainActor.assumeIsolated { AndroidMainLooper.isMainQueueDraining } ? jboolean(JNI_TRUE) : jboolean(JNI_FALSE)
}

@_cdecl("Java_com_unwrap_grep_core_SwiftBridge_nativeStart")
public func nativeStart(env: Env, thiz: jobject) {
    start(env) {
        guard let authService, let httpTransport, let clipboardPort, let filePort, let historyStore else {
            preconditionFailure("All platform ports must be installed before SwiftBridge.start")
        }
        let platform = PlatformServices(
            authService: authService,
            httpTransport: httpTransport,
            clipboard: clipboardPort,
            files: filePort,
            historyStore: historyStore
        )
        return GrepAppController(platform: platform, sink: sendToKotlin)
    }
}

/// 피처 하나만 띄운다. `feature`는 `DemoFeature`, `scenario`는 `DemoLoggedOutScenario`의 원시값(UTF-8).
@_cdecl("Java_com_unwrap_grep_core_SwiftBridge_nativeStartDemo")
public func nativeStartDemo(env: Env, thiz: jobject, feature: jbyteArray, scenario: jbyteArray?) {
    let name = string(env, from: feature)
    let scenarioName = scenario.map { string(env, from: $0) }
    guard let demo = DemoFeature(rawValue: name) else { preconditionFailure("Unknown demo feature: \(name)") }
    let demoScenario = scenarioName.flatMap(DemoLoggedOutScenario.init(rawValue:)) ?? .initial
    start(env) {
        FeatureDemoController(
            feature: demo,
            scenario: demoScenario,
            sink: sendToKotlin
        )
    }
}

private func start(_ env: Env, makeController: @MainActor () -> any RibController) {
    let target = makeRenderTarget(env)
    MainActor.assumeIsolated {
        precondition(controller == nil, "SwiftBridge.start called twice without stop")
        renderTarget = target
        let app = makeController()
        controller = app
        app.start()
    }
}

@_cdecl("Java_com_unwrap_grep_core_SwiftBridge_nativeStop")
public func nativeStop(env: Env, thiz: jobject) {
    let target = MainActor.assumeIsolated { () -> RenderTarget? in
        controller?.stop()
        controller = nil
        defer { renderTarget = nil }
        return renderTarget
    }
    if let target { env.pointee!.pointee.DeleteGlobalRef(env, target.bridgeClass) }
}

// MARK: - Kotlin 호출

private func makeRenderTarget(_ env: Env) -> RenderTarget {
    let jni = env.pointee!.pointee
    guard let localClass = jni.FindClass(env, bridgeClassName) else {
        preconditionFailure("JNI class not found: \(bridgeClassName)")
    }
    defer { jni.DeleteLocalRef(env, localClass) }
    guard let method = jni.GetStaticMethodID(env, localClass, "onRender", "([B)V"),
          let globalClass = jni.NewGlobalRef(env, localClass)
    else { preconditionFailure("JNI method not found: \(bridgeClassName).onRender([B)V") }
    return RenderTarget(bridgeClass: globalClass, onRender: method)
}

@MainActor
private func sendToKotlin(_ tree: String) {
    guard let target = renderTarget, let env = currentEnv() else { return }
    guard let bytes = byteArray(env, from: tree) else { return }
    defer { env.pointee!.pointee.DeleteLocalRef(env, bytes) }
    var argument = jvalue(l: bytes)
    env.pointee!.pointee.CallStaticVoidMethodA(env, target.bridgeClass, target.onRender, &argument)
    if env.pointee!.pointee.ExceptionCheck(env) == jboolean(JNI_TRUE) {
        env.pointee!.pointee.ExceptionDescribe(env)
        preconditionFailure("SwiftBridge.onRender threw")
    }
}

private func currentEnv() -> Env? {
    guard let vm = javaVM else { return nil }
    var raw: UnsafeMutableRawPointer?
    guard vm.pointee!.pointee.GetEnv(vm, &raw, jint(JNI_VERSION_1_6)) == JNI_OK, let raw else { return nil }
    return raw.assumingMemoryBound(to: JNIEnv?.self)
}

// MARK: - UTF-8 변환

private func string(_ env: Env, from array: jbyteArray) -> String {
    let jni = env.pointee!.pointee
    let count = Int(jni.GetArrayLength(env, array))
    var bytes = [UInt8](repeating: 0, count: count)
    bytes.withUnsafeMutableBufferPointer { buffer in
        buffer.baseAddress.map {
            jni.GetByteArrayRegion(env, array, 0, jsize(count), UnsafeMutableRawPointer($0).assumingMemoryBound(to: jbyte.self))
        }
    }
    return String(decoding: bytes, as: UTF8.self)
}

private func byteArray(_ env: Env, from text: String) -> jbyteArray? {
    let jni = env.pointee!.pointee
    let bytes = Array(text.utf8)
    guard let array = jni.NewByteArray(env, jsize(bytes.count)) else { return nil }
    bytes.withUnsafeBufferPointer { buffer in
        buffer.baseAddress.map {
            jni.SetByteArrayRegion(env, array, 0, jsize(bytes.count), UnsafeRawPointer($0).assumingMemoryBound(to: jbyte.self))
        }
    }
    return array
}
#endif
