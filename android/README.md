# Android 앱

아직 없다. 웹 다음에 만든다(ADR-0010). 뷰를 뺀 코드는 [`core/`](../core/Package.swift)를 Swift Android SDK로 빌드해 쓴다(ADR-WEB-007).
구조는 carti-RIBs-Swift `Samples/TodoModular/Android`를 따른다.
피처마다 ui·adapter·demo 모듈로 나누고, 웹 이슈가 머지될 때마다 `feat/m<번호>-android` 브랜치로 따라간다. `.so`는 WSL Ubuntu나 Mac에서 빌드한다([ADR-0015](../docs/adr/ADR-0015-mobile-feature-modules-per-issue.md)).
