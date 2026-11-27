import GrepAndroid

/// 프로세스에 하나뿐인 RIB 트리. `JNI.swift`의 `nativeStart`·`nativeStartDemo`가 만들고 `nativeStop`이 내린다.
@MainActor var controller: (any RibController)?

/// Kotlin이 `nativeStart` 전에 넣어 두는 플랫폼 포트들.
@MainActor var httpTransport: AndroidHTTPTransport?
@MainActor var authService: AndroidAuthService?
@MainActor var clipboardPort: AndroidClipboardPort?
@MainActor var filePort: AndroidFilePort?
@MainActor var historyStore: AndroidHistoryStore?
