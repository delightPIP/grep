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
  | "bin"
  /** 계약 2: `묶음`(pack), `열기`(peek), `찾아두기`(gather), `가져오기`(bring), `연결`(plug) */
  | "pack"
  | "peek"
  | "gather"
  | "bring"
  | "plug";

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

/** 자세히 보기(api `ItemDetail`, ARC-011 규칙 6). 차례와 문구는 뷰가 정책대로 그린다. */
export type ItemDetail = {
  item: ItemSummary;
  /** 링크 자료의 원래 주소(추적 꼬리표를 뺀 사람용 주소, 넘길 글 출처 칸과 같은 값). 링크가 아니면 null. 출처 호스트를 누르면 새 탭으로 연다(ARC-011 규칙 6-2, 통합 승인) */
  url: string | null;
  /** 넘기기용 요약 또는 직접 고친 요약. 이름표는 item.summarySource */
  handoffSummary: string | null;
  allTags: string[];
  /** 든 묶음 이름. 비면 `묶음  없음` */
  bundles: string[];
  /** 본문 글자 수. body가 null이면 null(#131, 통합 승인) */
  bodyLength: number | null;
  /** 펼치기용 본문(앞 2만 자). null이면 `· 본문 없음: <이유>`(item.blockedReason·status) */
  body: string | null;
  bodyFromImage: boolean;
  /** 파일 원본 서명 URL(10분). `원본 열기` */
  originalUrl: string | null;
  /** 이미지 미리보기 서명 URL */
  previewUrl: string | null;
};

export type BundleEntry = { name: string; count: number };
export type SavedSearchEntry = { query: string; count: number };
/** `<번호>  <AI 도구>  연결 <날짜>  읽음 <날짜>`. 날짜는 RFC 3339, lastReadAt은 없으면 null */
export type ConnectionEntry = { number: number; client: string; connectedAt: string; lastReadAt: string | null };

/** `고치기 <번호>` 편집 중인 자료(화면 W24). 출력 안 두 칸, Enter 저장·Esc 취소. */
export type Revising = { number: number; title: string; summary: string };

/** `찾기` 조건. 태그는 `#` 없이. text는 친 검색어 그대로(`· 0건: "<text>"`). */
export type SearchQuery = { text: string; words: string; tags: string[] };

export type HandoffResult = {
  items: ItemRef[];
  /** `넘기기 <묶음>`이면 그 이름(계약 2). 아니면 없음 또는 null */
  bundle?: string | null;
  /** 묶음에서 휴지통·영구 삭제로 빠진 수 `! 빠진 자료 N건 (삭제됨)` */
  removedCount?: number;
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
  /** suggestion: 가까운 명령으로 고친 입력 전체(`찾기 결제`, F17). 없으면 null(#118, 통합 승인) */
  | { kind: "unknownCommand"; name: string; suggestion?: string | null }
  /** sub: 하위 명령에서 인자가 빠졌다. `고르기 빼기`를 번호 없이 치면 "unpick"(#154, 통합 승인). 없거나 null이면 명령 자체 */
  | { kind: "missingArgument"; command: CommandName; sub?: "unpick" | null }
  | { kind: "missingTag" }
  | { kind: "saved"; item: ItemSummary }
  | { kind: "alreadySaved"; item: ItemSummary }
  | { kind: "inTrash"; number: number }
  | { kind: "saveFailed"; reason: SaveFailure; recovery: SaveRecovery }
  /** total: 시점이 붙은 `최근`이면 그 기간 전체 건수, 시점이 없으면 null(#114, 통합 승인) */
  | { kind: "recentList"; items: ItemSummary[]; hasMore: boolean; period?: Period | null; total?: number | null }
  /** isSavedSearch: 이 검색어가 이미 찾아둔 것이면 true. `→ 찾아두기 <검색어>` 칩을 숨긴다. null·없음이면 보인다(#134, 통합 승인) */
  | {
      kind: "searchResult";
      query: SearchQuery;
      total: number;
      items: ItemSummary[];
      hasMore: boolean;
      period?: Period | null;
      isSavedSearch?: boolean | null;
    }
  /** period: 시점을 붙인 찾기가 0건이면 그 시점. `→ 기간 없이: 찾기 <검색어>`를 보인다(#114, 통합 승인) */
  /** related: 뜻이 가까운 자료(최대 3건). 1건 이상이면 최근 저장 대신 그린다. 비었거나 null·없음이면 최근 저장(#128, 통합 승인) */
  | { kind: "noResults"; query: SearchQuery; recent: ItemSummary[]; period?: Period | null; related?: ItemSummary[] | null }
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
  /** connectionCount: 끊길 AI 도구 연결 수(`· AI 도구 연결 N개`, 계약 2부터). 모르면 null */
  | { kind: "signOutEverywhereConfirm"; connectionCount?: number | null }
  // 계약 2 묶음(ARC-003 사용자 문구)
  | { kind: "bundleList"; bundles: BundleEntry[] }
  | { kind: "bundleAdded"; name: string; count: number; alreadyCount: number }
  | { kind: "bundleView"; name: string; total: number; items: ItemSummary[]; hasMore: boolean }
  | { kind: "bundleNotFound"; name: string }
  | { kind: "bundleUnpicked"; name: string; remaining: number }
  | { kind: "notInBundle"; name: string; numbers: number[] }
  | { kind: "bundleDeleteConfirm"; name: string; itemCount: number }
  | { kind: "bundleDeleted"; name: string }
  /** format = `✗ 묶음 이름: 띄어쓰기 없이 1~20자 …`, reserved = `✗ 묶음 이름: 숫자만 · #시작 · 빼기 · 지우기 불가` */
  | { kind: "bundleNameInvalid"; reason: "format" | "reserved" }
  /** `폴더`·`mkdir` 입력 안내(ARC-007 규칙 11) */
  | { kind: "folderHint" }
  // 계약 2 자세히 보기(ARC-011)
  | { kind: "itemDetail"; detail: ItemDetail }
  /** `✗ 번호 하나만  예: <명령> 131` */
  | { kind: "oneNumberOnly"; command: CommandName }
  // 계약 2 찾아두기(ARC-012 사용자 문구). 결과 목록은 searchResult 줄이 이어서 온다
  | { kind: "searchSaved"; query: string; total: number; already: boolean }
  | { kind: "savedSearchList"; searches: SavedSearchEntry[] }
  /** `✗ 시점은 찾아두지 않음: <시점>` 다음 줄 `→ 찾아두기 <검색어>` */
  | { kind: "savedSearchPeriod"; period: string; suggestion: string }
  | { kind: "savedSearchTooLong" }
  | { kind: "savedSearchDeleteConfirm"; query: string }
  | { kind: "savedSearchDeleted"; query: string }
  | { kind: "savedSearchNotFound"; query: string }
  // 계약 2 AI 도구 연결(ACC-002 사용자 문구)
  | { kind: "connectionList"; mcpUrl: string; connections: ConnectionEntry[] }
  | { kind: "disconnectConfirm"; number: number; client: string }
  | { kind: "disconnected"; client: string; already: boolean }
  | { kind: "connectionNotFound"; number: number }
  /** 그렙을 열 때 한 번(ACC-002 규칙 11) `! 연결 끊김: <AI 도구> (<이유>)` */
  | { kind: "connectionEnded"; client: string; reason: "expired" | "revoked" }
  // 계약 2 북마크 가져오기(commands 6절)
  | { kind: "importPrompt" }
  | { kind: "importProgress"; done: number; total: number }
  | { kind: "importFinished"; saved: number; skipped: number; failed: number; overLimit: number; failedUrls: string[] }
  /** #172 `✗ 받지 않는 형식: html` 다음 줄 `→ 북마크 파일이면: 가져오기`. 끌어다 놓은 `html`·`htm` 파일의 이름 */
  | { kind: "importSuggest"; fileName: string };

/** #175 땅굴 두더지의 동작. `seq`가 바뀌면 같은 동작도 다시 튼다. */
export type Mole = { action: "seek" | "save" | "handoff" | "error"; seq: number };

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
  /** #175 두더지가 지금 할 동작. 없으면 null(또는 아직 Swift가 보내지 않으면 없음). */
  mole?: Mole | null;
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
