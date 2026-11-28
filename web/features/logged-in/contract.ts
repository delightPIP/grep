// #168 계약(통합 세션 확정)을 뷰가 먼저 쓰려고 옮겨 둔 타입.
// shortcut: 계약은 M 갈래가 `support/view-state.ts`에 넣는다. 통합 때 이 파일을 지우고 import를 view-state로 바꾼다.
import type {
  BundleEntry,
  ConnectionEntry,
  ItemRef,
  ItemSummary,
  LoggedInAction,
  LoggedInState,
  SavedSearchEntry,
} from "../../support/view-state";

export type ItemKind = ItemSummary["kind"];

/** #179 계약: 고를 때 받은 ItemSummary의 kind·source. M 갈래가 채우기 전에는 없을 수 있다. */
export type PickedRef = ItemRef & { kind?: ItemKind; source?: string | null };

/** 자동 묶음 네 기준(ARC-007 규칙 2). */
export type AutoGroup = "format" | "source" | "date" | "tag";

/**
 * value: format = link·text·image·file, source = 호스트 또는 `direct`, date = today·week·month·earlier, tag = 태그 낱말.
 * 0건은 서버가 뺀다(ARC-007 규칙 7).
 */
export type AutoGroupEntry = { group: AutoGroup; value: string; count: number };

export type ArchiveFilter =
  | { kind: "all" }
  | { kind: "auto"; group: AutoGroup; value: string }
  | { kind: "bundle"; name: string }
  | { kind: "savedSearch"; query: string };

export type ArchiveState = {
  groups: AutoGroupEntry[];
  /** 0건도 보인다(ARC-003 규칙 9) */
  bundles: BundleEntry[];
  /** 0건은 숨긴다(ARC-012) */
  savedSearches: SavedSearchEntry[];
  filter: ArchiveFilter;
  items: ItemSummary[];
  hasMore: boolean;
  status: "idle" | "loading" | "error";
};

/** `/me`에 있는 값만. */
export type AccountInfo = { authProvider: "google" | "github"; itemCount: number };

export type SettingsState = { account: AccountInfo | null; connections: ConnectionEntry[] };

export type LoggedInStateWithScreens = Omit<LoggedInState, "selection"> & {
  selection: PickedRef[];
  /** 보관함을 처음 열 때 채운다. 그 전에는 null */
  archive?: ArchiveState | null;
  settings?: SettingsState | null;
};

export type ScreenAction =
  | { kind: "archiveOpen" }
  | { kind: "archiveSelect"; filter: ArchiveFilter }
  | { kind: "archiveMore" }
  | { kind: "settingsOpen" };

export type LoggedInActionWithScreens = LoggedInAction | ScreenAction;
