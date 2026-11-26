# 서비스 정책

그렙이 보장해야 하는 동작, 값, 사용자 문구의 유일한 근거(SSOT)다. 코드·디자인·명세가 정책과 다르면 정책을 먼저 고치거나 코드를 고친다.

## 번호 체계

- 번호는 `<영역 접두어>-<세 자리 번호>`이고, 영역마다 001부터 발급한다. 한 번 쓴 번호는 재사용하지 않는다.
- 정책 하나는 영역 폴더 안의 파일 하나다: `<영역>/<접두어>-<번호>-<영문-슬러그>.md`
- 새 정책은 [정책 틀](../templates/policy.md)을 복사해 쓰고, 아래 "정책 목록" 표에 한 줄을 추가한다.
- 추가·수정·폐기 절차는 `docs:policy-manager` 스킬을 따른다.

## 영역과 접두어

| 접두어 | 영역 | 폴더 |
|---|---|---|
| COM | 공통 | [common/](common/README.md) |
| ACC | 계정 | [account/](account/README.md) |
| ARC | 자료 | [archive/](archive/README.md) |

기능 영역이 생기면 이 표에 행을 추가하고 같은 이름의 폴더를 만든다.

## 정책 목록

| 번호 | 제목 | 상태 | 영역 |
|---|---|---|---|
| [COM-001](common/COM-001-same-link-detection.md) | 같은 링크나 같은 파일을 다시 저장하면 새로 만들지 않고 기존 자료를 알린다 | 확정 | 공통 |
| [COM-002](common/COM-002-external-llm-data.md) | 자료 내용은 학습에 쓰지 않는 조건의 유료 외부 LLM API로만 보낸다 | 확정 | 공통 |
| [ACC-001](account/ACC-001-social-login-required.md) | Google 또는 GitHub로 로그인해야 그렙을 쓸 수 있다 | 확정 | 계정 |
| [ACC-002](account/ACC-002-devices-and-connections.md) | 기기 수는 제한하지 않고, 모든 기기 로그아웃과 AI 도구 연결별 끊기를 제공한다 | 확정 | 계정 |
| [ARC-001](archive/ARC-001-item-number.md) | 자료마다 사용자별 고유 번호를 붙이고, 모든 명령이 그 번호 하나로 자료를 가리킨다 | 확정 | 자료 |
| [ARC-002](archive/ARC-002-auto-tags.md) | 태그는 서버가 자동으로만 붙이고, 사용자는 보고 `#태그`로 찾을 수 있다 | 확정 | 자료 |
| [ARC-003](archive/ARC-003-bundles-as-folders.md) | 폴더는 따로 두지 않고, 한 단계짜리 묶음이 폴더 역할을 한다 | 확정 | 자료 |
| [ARC-004](archive/ARC-004-ai-generated-label.md) | AI가 만든 요약과 태그는 화면, 넘길 글, AI 도구 연결 어디서나 AI 생성물로 구분해 보여 준다 | 확정 | 자료 |
| [ARC-005](archive/ARC-005-save-vs-processing.md) | 저장 성공과 AI 처리 성공은 따로 다루고, 처리에 실패해도 저장한 자료는 남는다 | 확정 | 자료 |
| [ARC-006](archive/ARC-006-link-fetch-scope.md) | 서버는 공개 웹 페이지만 열어 본문을 가져오고, 로그인·유료벽·접근 제한을 우회하지 않는다 | 확정 | 자료 |
