# iOS 앱

뷰는 SwiftUI, 뷰를 뺀 코드는 [`core/`](../core/Package.swift)를 쓴다(ADR-WEB-007, ADR-IOS-009).
구조는 carti-RIBs-Swift `Samples/TodoModular/iOS`를 따른다.
피처마다 UI·Adapter·Example 모듈로 나누고, 웹 이슈가 머지될 때마다 `feat/m<번호>-ios` 브랜치로 따라간다([ADR-0015](../docs/adr/ADR-0015-mobile-feature-modules-per-issue.md)).

## 구조

| 위치 | 내용 |
| :--- | :--- |
| `Platform/Sources` | `URLSessionHTTPTransport`·`WebAuthService`·`PasteboardClipboardPort`·`URLSessionFilePort`·`UserDefaultsHistoryStore` |
| `Platform/Tests` | 플랫폼 포트 단위 테스트(`GrepPlatformTests`) |
| `Features/<피처>/UI` | 순수 SwiftUI 뷰. 값과 콜백만 받는다 |
| `Features/<피처>/Adapter` | 코어 `ViewContract` 구현과 팩토리 |
| `Features/<피처>/Example` | 그 피처만 띄우는 Example 앱 |
| `App/Sources` | `GrepAppRoot`와 어댑터·플랫폼 포트를 잇는 앱(`GrepIOSApp.swift`) |

## 빌드와 테스트

Xcode와 Tuist 4가 필요하다.

로그인하려면 `Config/Secrets.example.xcconfig`를 `Config/Secrets.xcconfig`로 복사해 Supabase 주소와 공개 키를 채운다(값은 `web/.env.local`과 같다). `Secrets.xcconfig`는 커밋하지 않는다. 없으면 빌드는 되지만 로그인 버튼은 `권한 거부`를 보인다.

```sh
cd ios
tuist generate --no-open
tuist test --device "iPhone 17"
```

- 전체 앱 스킴: `Grep`
- 피처 Example 스킴: `FeatureLoggedOutExample`, `FeatureTerminalExample`, `FeatureLoggedInExample` (시나리오 목록 화면 → 항목 선택 시 전체 화면 표시 + 닫기 복귀 패턴)
