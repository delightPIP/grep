// 계약(#31 0단계). core/Features/*/Interface의 Swift ViewState·ViewAction을 TS로 옮긴 것이다.
// 순수 뷰(features/*/view.tsx)는 이 타입만 안다. 어댑터(features/*/adapter.tsx)가 BridgeJS 생성 타입을 이 타입으로 바꾼다.
// Swift 쪽과 함께만 바꾼다. 계약은 #56(데모), #93(정리·고치기·샘플·이벤트·모든 기기 로그아웃·시점)에서 고정했다.
// #93에서 더한 값은 Swift Interface에 아직 없다. M 갈래가 같은 이름으로 Swift case와 브리지를 더한다(#93 핸드오프).

export type AuthProvider = "google" | "github";

/** ACC-001 `✗ 로그인 실패: <이유>`의 세 가지. disconnected=연결 끊김, timedOut=응답 없음, denied=권한 거부 */
export type SignInFailureReason = "disconnected" | "timedOut" | "denied";

export type LoggedOutNotice =
  | { kind: "cancelled" }
  | { kind: "failed"; reason: SignInFailureReason }
  | { kind: "expired" }
  | { kind: "signedOut" }
  /** `로그아웃 모든기기` 뒤(ACC-002). */
  | { kind: "signedOutEverywhere" };

/** 로그인 화면(W1·W2·W3·W10). 문구는 뷰가 ACC-001 사용자 문구 원문으로 만든다. */
export type LoggedOutState = {
  notice: LoggedOutNotice | null;
  /** 로그인 창이 열려 있다. 버튼을 눌러도 창을 하나 더 띄우지 않는다(ACC-001 규칙 9). */
  isSigningIn: boolean;
};

export type LoggedOutAction = { kind: "signInTapped"; provider: AuthProvider };

/** 데모 범위 명령(commands 2절). core `CommandName`. */
export type CommandName =
  | "keep"
  | "recent"
  | "seek"
  | "pick"
  | "handoff"
  | "guide"
  | "about"
  | "signOut"
  /** #93: `고치기`(revise), `버리기`(drop), `되살리기`(revive), `휴지통`(bin). `휴지통 비우기`는 bin, `로그아웃 모든기기`는 signOut의 인자다 */
  | "revise"
  | "drop"
  | "revive"
  | "bin";

/** ARC-005 처리 상태 다섯 가지. */
export type ItemStatus = "received" | "processing" | "ready" | "blocked" | "failed";

/**
 * `! 본문 못 가져옴: <이유>`. ARC-005 세 가지, COM-004 규칙 6 두 가지.
 * 이 파일의 값은 Swift case 이름(camelCase)이다. API 값(`login_required`)은 코어가 읽고, 브리지가 case 이름으로 넘긴다.
 */
export type BlockedReason = "loginRequired" | "accessDenied" | "disallowedURL" | "encrypted" | "noText";

/** 목록 한 줄의 값(api/openapi.yaml `ItemSummary`). 자료는 번호로만 가리킨다(ARC-001). */
export type ItemSummary = {
  number: number;
  kind: "link" | "text" | "file";
  title: string;
  source: string | null;
  status: ItemStatus;
  blockedReason: BlockedReason | null;
  listSummary: string | null;
  /** ARC-004 규칙 5 */
  summarySource: "ai" | "user" | null;
  /** ARC-004 규칙 8 */
  partialNote: string | null;
  /** `#` 없이. 목록은 앞 3개만(ARC-002 규칙 4) */
  tags: string[];
  /** 찾기에서 일치한 곳. 요약 줄 끝에 흐리게. 찾기가 아니면 null */
  matchedIn: "title" | "source" | "summary" | "body" | "imageText" | "tag" | null;
  /** RFC 3339. 한국 시간으로 바꾸는 것은 뷰가 한다(ARC-004 규칙 7) */
  savedAt: string;
};

export type ItemRef = { number: number; title: string };

/** 휴지통 한 줄(api `TrashItem`). daysLeft는 `30일 남음`(ARC-008 규칙 10). */
export type TrashEntry = { item: ItemSummary; trashedAt: string; daysLeft: number };

/**
 * 시점(F22). label은 친 낱말 그대로(`지난달`), from·to는 한국 시간 경계의 RFC 3339(반열린 구간).
 * 뷰는 `4건 · 지난달 (10/1~10/31)` 머리 줄을 만든다. 여러 주에 걸치면 주 구분 줄을 넣는다.
 */
export type Period = { label: string; from: string; to: string };

/** `고치기 <번호>` 편집 중인 자료(화면 W24). 출력 안 두 칸, Enter 저장·Esc 취소. */
export type Revising = { number: number; title: string; summary: string };

/** `찾기` 조건. 태그는 `#` 없이. text는 친 검색어 그대로(`· 0건: "<text>"`). */
export type SearchQuery = { text: string; words: string; tags: string[] };

export type HandoffResult = {
  items: ItemRef[];
  /** 줄바꿈 포함 글자 수 */
  charCount: number;
  missingSummaryCount: number;
  /** 넘긴 글 전체. `펼치기`로 보인다 */
  text: string;
};

/** 저장 실패 이유. 앞 셋은 ARC-005 `✗ 저장 안 됨: <이유>`, 뒤 둘은 COM-004 문구. */
export type SaveFailure =
  | { kind: "disconnected" }
  | { kind: "timedOut" }
  | { kind: "serverError" }
  | { kind: "unsupportedFormat"; fileExtension: string }
  | { kind: "tooLarge"; fileName: string; bytes: number };

/** 저장에 실패한 뒤 다시 넣는 길(ARC-005 규칙 2). core `SaveRecovery`. */
export type SaveRecovery =
  /** 넣으려던 줄을 입력줄에 되돌렸다. `  입력은 남겨 둠` */
  | { kind: "inputKept" }
  /** 그새 친 새 글이 있어 입력줄을 덮지 않았다. 다음 줄 `→ 다시: <command>` */
  | { kind: "retry"; command: string }
  /** 끌어다 놓은 파일. ` (<name>)` */
  | { kind: "file"; name: string };

/** 명령 실패 이유(COM-008, COM-010). clipboardDenied는 넘기기만. */
export type CommandFailure = "disconnected" | "timedOut" | "serverError" | "clipboardDenied";

/** 출력 한 줄. core `LoggedInViewState.Line`. 문구는 뷰가 정책 원문으로 만든다. */
export type TerminalLine =
  | { kind: "prompt"; text: string }
  | { kind: "unknownCommand"; name: string }
  | { kind: "missingArgument"; command: CommandName }
  | { kind: "missingTag" }
  | { kind: "saved"; item: ItemSummary }
  | { kind: "alreadySaved"; item: ItemSummary }
  | { kind: "inTrash"; number: number }
  | { kind: "saveFailed"; reason: SaveFailure; recovery: SaveRecovery }
  | { kind: "recentList"; items: ItemSummary[]; hasMore: boolean; period?: Period | null }
  | { kind: "searchResult"; query: SearchQuery; total: number; items: ItemSummary[]; hasMore: boolean; period?: Period | null }
  | { kind: "noResults"; query: SearchQuery; recent: ItemSummary[] }
  | { kind: "picked"; items: ItemRef[] }
  | { kind: "notFound"; numbers: number[] }
  | { kind: "invalidNumber"; input: string }
  | { kind: "handedOff"; result: HandoffResult }
  | { kind: "handoffFailed"; reason: CommandFailure; preview: string | null }
  | { kind: "commandFailed"; command: CommandName; reason: CommandFailure; retry: string }
  | { kind: "handoffConfirm"; total: number }
  | { kind: "cancelled" }
  | { kind: "welcome" }
  | { kind: "guide" }
  | { kind: "about"; command: CommandName }
  | { kind: "reconnected" }
  // #93 정리(ARC-008). 확인 줄의 답은 COM-007(실행 낱말 `버리기`·`비우기` 하나만 실행)
  | { kind: "dropConfirm"; total: number }
  | { kind: "dropped"; items: ItemRef[] }
  | { kind: "revived"; items: ItemRef[] }
  | { kind: "binList"; total: number; items: TrashEntry[]; hasMore: boolean }
  | { kind: "binEmptyConfirm"; total: number }
  | { kind: "binEmptied"; count: number }
  // #93 고치기(ARC-002·004)
  | { kind: "revised"; item: ItemSummary }
  | { kind: "tagsRemoved"; item: ItemSummary; tags: string[] }
  // #93 샘플(ARC-010 규칙 4): 받은 범위와 치우는 법, 이어서 `최근`과 같은 목록
  | { kind: "samplesSaved"; firstNumber: number; lastNumber: number; items: ItemSummary[] }
  // #108 고르기 빼기·비우기
  /** remaining: 뺀 뒤 남은 선택 수(1 이상). 0이 되면 unpicked 대신 pickCleared가 온다(#108, 통합 승인) */
  | { kind: "unpicked"; items: ItemRef[]; remaining: number }
  | { kind: "pickCleared"; count: number }
  // #111 로그아웃 모든기기(ACC-002 규칙 4): 확인 뒤 Supabase 전역 로그아웃. 다른 기기는 접근 토큰 만료 때(최대 1시간)
  | { kind: "signOutEverywhereConfirm" };

/** 터미널 화면. */
export type LoggedInState = {
  /** 상태줄 `자료 N`. 서버에서 받기 전이면 null. */
  itemCount: number | null;
  lines: TerminalLine[];
  /** 입력줄. 로그인 만료 뒤 다시 로그인하면 되살린 값이 들어온다(ACC-001 규칙 7). */
  input: string;
  /** 고른 자료, 고른 순서. 상태줄 `선택 N`, 입력줄 위 선택 줄, 목록 행의 `▸`. */
  selection: ItemRef[];
  /** 상태줄 `요약 생성 중 N`. 0이면 숨긴다. */
  processingCount: number;
  /** 상태줄 `연결 끊김`(COM-010). */
  isOffline: boolean;
  /** #93 `고치기` 편집 중이면 그 자료. 없으면 null(또는 아직 Swift가 보내지 않으면 없음). */
  revising?: Revising | null;
};

/** 끌어다 놓은 파일. 바이트는 FilePort가 id로 올린다. */
export type DroppedFile = { id: string; name: string; size: number };

export type LoggedInAction =
  | { kind: "inputChanged"; text: string }
  | { kind: "submitted"; text: string }
  | { kind: "pasted"; text: string }
  | { kind: "filesDropped"; files: DroppedFile[] }
  | { kind: "moreRequested" }
  // #93
  /** 0건 첫 화면의 `→ 샘플 8건으로 해 보기`. 누르면 바로 저장한다(ARC-010 규칙 2) */
  | { kind: "samplesRequested" }
  | { kind: "reviseSubmitted"; number: number; title: string; summary: string }
  | { kind: "reviseCancelled" };
