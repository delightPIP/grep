### ADR-0015 iOS·Android 앱은 공유 코어의 피처마다 UI·Adapter·Example 모듈로 만들고, 웹 이슈가 끝날 때마다 짧은 브랜치로 따라간다
- 상태: 채택
- 날짜: 2026-11-27
- 영역: 공통

> **요약** 공유 코어의 `LoggedIn`을 컨테이너로 두고 터미널을 `Terminal` 피처로 떼어 낸다. iOS는 Tuist와 SwiftUI로, Android는 Gradle과 Compose로 만들며, Android는 공유 코어를 Swift Android SDK로 `.so`로 빌드해 swift-java로 부른다. 두 플랫폼 모두 피처마다 UI(값과 콜백만 받는 화면), Adapter(코어 뷰 계약 구현), Example(피처 하나만 띄우는 앱) 세 모듈로 나눈다. 웹 이슈가 머지될 때마다 그 피처의 모바일 화면을 이슈별 짧은 브랜치로 만든다.

#### 배경

웹은 이슈 하나씩(#56·#57·#60) 머지되고 있다. 사용자는 웹 다음 이슈를 진행하는 동안 다른 세션(Windows의 Antigravity, Mac)에서 이미 끝낸 이슈의 iOS·Android 화면을 그리기를 원한다. 그런데 `ios/`·`android/`에는 README만 있고 구조가 정해지지 않았다(ADR-0010 결정 5). 또 공유 코어의 터미널 로직이 `LoggedIn` 한 파일(`LoggedIn.swift` 508줄)에 들어 있어, 모바일의 하단 탭(터미널·보관함·설정)처럼 컨테이너 안에 터미널을 넣는 화면을 만들 수 없다.

Android용 `.so`는 Windows 호스트에서 교차 빌드할 수 없다. 이 PC의 WSL Ubuntu에 Swift 6.4.2, Swift Android SDK, NDK r30을 설치해 두었다(2026-11-27).

#### 결정

1. 공유 코어에서 `LoggedIn`은 컨테이너 RIB으로 두고, 터미널(블록 목록·입력줄·칩·확인 대기)은 `Terminal` 피처(Interface·Sources·Testing·Tests)로 옮긴다. 웹 브리지가 보내는 줄 이름(`Line` 종류)은 바꾸지 않는다.
2. iOS는 Tuist와 SwiftUI로 만든다. 피처마다 `Features/<피처>/UI`(순수 SwiftUI, 값과 콜백만), `Adapter`(코어 `ViewContract` 구현과 화면 팩토리), `Example`(그 피처만 띄우는 앱) 세 모듈을 둔다.
3. Android는 Gradle과 Compose로 만든다. 공유 코어는 Swift Android SDK로 `.so`를 빌드하고 swift-java로 Kotlin에서 부른다. 피처마다 `feature/<피처>/ui`, `adapter`, `demo`를 둔다. 빌드 값은 carti-RIBs-Swift `Samples/TodoModular/Android`를 따른다.
4. `.so`는 WSL Ubuntu 또는 Mac에서 빌드한다. 코드는 Windows(Antigravity)에서 고쳐도 된다.
5. 웹 이슈 #N이 머지되면 `feat/m<N>-ios`, `feat/m<N>-android` 브랜치를 `origin/main`에서 따로 만들어, 그 이슈 화면만 그리고 PR로 머지한다. 오래 사는 플랫폼 브랜치는 두지 않는다. 첫 번째는 앞서 머지된 화면을 모은 `m0`이다.
6. 폴더는 ADR-0010대로 `ios/`·`android/`에 둔다. `client/` 아래로 옮기는 것은 데모 뒤에 따로 정한다.

#### 고려한 대안

| 대안 | 기각 이유 |
| :--- | :--- |
| `LoggedIn`을 그대로 두고 모바일에서 화면 전체를 한 피처로 그리기 | 하단 탭·레일처럼 터미널을 다른 화면과 나란히 두는 구성을 만들 수 없고, `LoggedIn.swift`가 찾기·넘기기를 더하면 계속 커진다 |
| 플랫폼마다 오래 사는 브랜치(`ios`, `android`)를 두고 계속 끌고 가기 | 코어와 계약이 main에서 바뀔 때마다 멀어지고, 마지막에 큰 병합이 남는다 |
| Kotlin Multiplatform으로 공유 코어를 다시 만들기 | 코어가 이미 Swift이고 웹이 그 코어를 Wasm으로 쓴다(ADR-WEB-007). 로직을 두 벌 유지해야 한다 |
| Android에서 JNI 바인딩을 손으로 쓰기 | 뷰 계약이 늘 때마다 손으로 맞춰야 한다. swift-java는 carti-RIBs-Swift 예제에서 이미 동작이 확인됐다 |
| React Native로 모바일을 만들어 웹 뷰를 재사용 | Swift 코어를 모바일에서 다시 Wasm이나 별도 브리지로 감싸야 하고, 네이티브 공유 확장(ADR-IOS-009)과 맞지 않는다 |

#### 결과

- 얻는 것: 웹·iOS·Android가 같은 `Terminal` 상태와 동작을 쓴다. 피처마다 Example 앱으로 그 화면만 띄워 볼 수 있다. 모바일 작업이 웹 다음 이슈를 막지 않는다.
- 비용: 공유 코어를 한 번 나누는 리팩터링이 먼저 필요하고, 그동안 코어를 건드리는 웹 이슈 갈래는 기다린다. Android 빌드에 WSL 또는 Mac이 필요하다. Tuist·Gradle·swift-java 세 빌드 도구를 따로 관리한다.

#### 관련

ADR-0010, ADR-WEB-007, ADR-IOS-009, 이슈 #56·#57·#60
