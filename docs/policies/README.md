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
| DSK | 데스크톱 | [desktop/](desktop/README.md) |
| ACC | 계정 | [account/](account/README.md) |
| ARC | 자료 | [archive/](archive/README.md) |
| MOB | 모바일 | [mobile/](mobile/README.md) |

기능 영역이 생기면 이 표에 행을 추가하고 같은 이름의 폴더를 만든다.

## 정책 목록

| 번호 | 제목 | 상태 | 영역 |
|---|---|---|---|
| [COM-001](common/COM-001-same-link-detection.md) | 같은 링크나 같은 파일을 다시 저장하면 새로 만들지 않고 기존 자료를 알린다 | 확정 | 공통 |
| [COM-002](common/COM-002-external-llm-data.md) | 자료 내용은 허용 제공사의 외부 LLM API로만 보내고, 프로젝트 기간에는 팀이 만든 자료만 넣어 무료 플랜을 쓴다 | 검토 중 (개발자 확인 대기) | 공통 |
| [COM-003](common/COM-003-desktop-clipboard-link-prompt.md) | 데스크톱 앱은 복사한 링크를 사용자가 켰을 때만 알리고, 묻기 전에는 저장하지 않는다 | 검토 중 (개발자 확인 대기) | 공통 |
| [COM-004](common/COM-004-accepted-file-formats.md) | 저장할 수 있는 파일은 PDF, md, txt, docx와 PNG, JPEG, WebP, HEIC 이미지다 | 검토 중 (개발자 확인 대기) | 공통 |
| [COM-005](common/COM-005-free-tier-only.md) | 그렙은 돈이 드는 서비스를 쓰지 않고 무료 플랜·무료 한도 안에서만 돈다 | 검토 중 (개발자 확인 대기) | 공통 |
| [COM-006](common/COM-006-per-user-isolation.md) | 한 사용자의 자료는 그 사용자만 보고, 다른 사용자의 자료에 닿는 길을 두지 않는다 | 검토 중 (개발자 확인 대기) | 공통 |
| [DSK-001](desktop/DSK-001-resident-mole.md) | 데스크톱 두더지는 화면 오른쪽 아래에 상주하고, 사용자가 숨기거나 끌 수 있다 | 검토 중 (개발자 확인 대기) | 데스크톱 |
| [DSK-002](desktop/DSK-002-drop-to-save.md) | 데스크톱 두더지에 끌어다 놓으면 묻지 않고 저장한다 | 검토 중 (개발자 확인 대기) | 데스크톱 |
| [DSK-003](desktop/DSK-003-quick-window-shortcut.md) | 빠른 창은 두더지를 누르거나 전역 단축키로 열고 닫는다 | 검토 중 (개발자 확인 대기) | 데스크톱 |
| [ACC-001](account/ACC-001-social-login-required.md) | Google 또는 GitHub로 로그인해야 그렙을 쓸 수 있다 | 확정 | 계정 |
| [ACC-002](account/ACC-002-devices-and-connections.md) | 기기 수는 제한하지 않고, 모든 기기 로그아웃과 AI 도구 연결별 끊기를 제공한다 | 확정 | 계정 |
| [ARC-001](archive/ARC-001-item-number.md) | 자료마다 사용자별 고유 번호를 붙이고, 모든 명령이 그 번호 하나로 자료를 가리킨다 | 확정 | 자료 |
| [ARC-002](archive/ARC-002-auto-tags.md) | 태그는 서버가 자동으로만 붙이고, 사용자는 보고 `#태그`로 찾거나 지울 수 있다 | 검토 중 (개발자 확인 대기) | 자료 |
| [ARC-003](archive/ARC-003-bundles-as-folders.md) | 폴더는 따로 두지 않고, 한 단계짜리 묶음이 폴더 역할을 한다 | 확정 | 자료 |
| [ARC-004](archive/ARC-004-ai-generated-label.md) | AI가 만든 요약과 태그는 화면, 넘길 글, AI 도구 연결 어디서나 AI 생성물로 구분해 보여 준다 | 확정 | 자료 |
| [ARC-005](archive/ARC-005-save-vs-processing.md) | 저장 성공과 AI 처리 성공은 따로 다루고, 처리에 실패해도 저장한 자료는 남는다 | 확정 | 자료 |
| [ARC-006](archive/ARC-006-link-fetch-scope.md) | 서버는 공개 웹 페이지만 열어 본문을 가져오고, 로그인·유료벽·접근 제한을 우회하지 않는다 | 확정 | 자료 |
| [ARC-007](archive/ARC-007-archive-auto-groups.md) | 보관함은 자동 묶음과 사용자 묶음, 저장한 찾기로만 자료를 보여 주고, 따로 폴더를 두지 않는다 | 확정 | 자료 |
| [ARC-008](archive/ARC-008-trash-30-days.md) | 지운 자료는 휴지통에 30일 두고, 그동안 되살릴 수 있다 | 검토 중 (개발자 확인 대기) | 자료 |
| [ARC-009](archive/ARC-009-ai-connection-read-scope.md) | AI 도구 연결은 검색에 요약을, 읽기에 본문 텍스트를 돌려주고 원본 파일은 주지 않는다 | 검토 중 (개발자 확인 대기) | 자료 |
| [ARC-010](archive/ARC-010-sample-items.md) | 첫 화면의 샘플 8건은 실제 자료로 저장하고 버리기로 치운다 | 검토 중 (개발자 확인 대기) | 자료 |
| [MOB-001](mobile/MOB-001-bottom-tabs.md) | 모바일 화면은 하단 탭 세 개(터미널 · 보관함 · 설정)로 오가고, 설정은 탭으로 둔다 | 확정 | 모바일 |
