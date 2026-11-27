# Android 앱

아직 없다. 웹 다음에 만든다(ADR-0010). 뷰를 뺀 코드는 [`core/`](../core/Package.swift)를 Swift Android SDK로 빌드해 쓴다(ADR-WEB-007).
구조는 carti-RIBs-Swift `Samples/TodoModular/Android`를 따른다.
피처마다 ui·adapter·demo 모듈로 나누고, 웹 이슈가 머지될 때마다 `feat/m<번호>-android` 브랜치로 따라간다. `.so`는 WSL Ubuntu나 Mac에서 빌드한다([ADR-0015](../docs/adr/ADR-0015-mobile-feature-modules-per-issue.md)).
피처 `demo` 앱은 하단 시나리오 바 대신 **시나리오 목록 화면 → 항목 선택 시 전체 화면으로 피처 표시 + 닫기(뒤로 가기) 복귀** 패턴을 따른다(iOS `Example` 앱과 통일).
