// 터미널 화면(배치는 view.tsx가 감싼다). 순수 뷰: 받은 상태만 그리고, 입력은 onInputChange·onSubmit·onPaste·onFilesDrop으로만 알린다.
// 배치는 시안 Main·Errors·Logout ③ 아트보드, 출력 비우기(로그아웃·다른 계정 로그인, COM-009)는 코어가 lines로 내려준다.
import {
  Fragment,
  createContext,
  useContext,
  useEffect,
  useRef,
  useState,
  type ClipboardEvent,
  type DragEvent,
  type KeyboardEvent,
  type ReactNode,
} from "react";
import type {
  BlockedReason,
  BundleEntry,
  CommandFailure,
  CommandName,
  ConnectionEntry,
  HandoffResult,
  ItemDetail,
  ItemRef,
  ItemSummary,
  LoggedInState,
  MoleCue,
  Period,
  Revising,
  SaveFailure,
  SaveRecovery,
  SavedSearchEntry,
  SearchQuery,
  TerminalLine,
  TrashEntry,
} from "../../support/view-state";
import { Burrow, type MoleAction } from "../../ui/burrow";
import type { PickedRef } from "./contract";
import { pickWords } from "./pick-word";
import { Banner, DockInput, Line, Prompt, StatusBar, Window, type StatusItem } from "../../ui/grep";

export type TerminalScreenProps = Omit<LoggedInState, "selection"> & {
  /** 고른 자료. #179 kind·source가 오면 선택 줄에 종류 낱말로 쓴다. */
  selection: PickedRef[];
  onInputChange: (text: string) => void;
  onSubmit: (text: string) => void;
  /** 입력줄이 빈 채로 붙여 넣었다. 붙여 넣기만 해도 저장한다(commands 3절 담기). */
  onPaste: (text: string) => void;
  /** 화면에 파일을 끌어다 놓았다. */
  onFilesDrop: (files: File[]) => void;
  /**
   * 목록 맨 아래 `→ 더 보기`를 눌렀다(core `moreRequested`).
   * shortcut: 선택 속성. 어댑터가 `handle.moreRequested`로 이으면(#60 클라이언트 갈래) 필수로 바꾼다.
   */
  onMoreRequested?: () => void;
  /**
   * `고치기` 편집 칸에서 Enter(core `reviseSubmitted`), Esc(core `reviseCancelled`).
   * shortcut: 선택 속성. 어댑터가 `handle.reviseSubmitted`·`handle.reviseCancelled`로 이으면(M 갈래) 필수로 바꾼다.
   */
  onReviseSubmit?: (number: number, title: string, summary: string) => void;
  onReviseCancel?: () => void;
  /**
   * 0건 첫 화면의 `→ 샘플 8건으로 해 보기`를 눌렀다(core `samplesRequested`). 누르면 바로 저장한다(ARC-010 규칙 2).
   * shortcut: 선택 속성. 어댑터가 `handle.samplesRequested`로 이으면(M 갈래) 필수로 바꾼다.
   */
  onSamplesRequest?: () => void;
};

const HELP_HINT = { key: "?", label: "도움말" };
/** ARC-002 규칙 4 */
const LIST_TAG_LIMIT = 3;
/** ARC-004 규칙 7: 저장 시각은 한국 시간. 표기는 ARC-011 `2026-11-26 14:03`과 같게. */
const SAVED_AT_FORMAT = new Intl.DateTimeFormat("en-CA", {
  timeZone: "Asia/Seoul",
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
  hour: "2-digit",
  minute: "2-digit",
  hourCycle: "h23",
});

/** 화면에 찍는 명령 이름(commands 2절). */
const COMMAND_LABEL: Record<CommandName, string> = {
  keep: "담기",
  recent: "최근",
  seek: "찾기",
  pick: "고르기",
  handoff: "넘기기",
  guide: "도움말",
  about: "설명",
  signOut: "로그아웃",
  revise: "고치기",
  drop: "버리기",
  revive: "되살리기",
  bin: "휴지통",
  pack: "묶음",
  peek: "열기",
  gather: "찾아두기",
  bring: "가져오기",
  plug: "연결",
};

/** COM-010·COM-008 이유 낱말. */
const COMMAND_FAILURE_LABEL: Record<CommandFailure, string> = {
  disconnected: "연결 끊김",
  timedOut: "응답 없음",
  serverError: "서버 오류",
  clipboardDenied: "클립보드 거부",
};
/** commands 6절 글 저장: `<첫 줄, 24자까지>` */
const TEXT_TITLE_LIMIT = 24;
const BYTES_PER_MB = 1024 * 1024;

/** ARC-001 사용자 문구의 예 */
const PICK_EXAMPLE = "고르기 131 140";

/**
 * 출력 안의 명령 칩·자료 번호가 쓰는 것(commands 6절 출력 원칙).
 * insert: 누르면 그 명령을 입력줄에 찍기만 한다(엔터로 실행). selected: 목록 행 `▸` 표시용 고른 번호.
 */
/** requestSamples: 화면 칩 `샘플 8건으로 해 보기`. 명령 칩과 달리 입력줄을 거치지 않는다. */
export type TerminalChips = { insert: (command: string) => void; selected: ReadonlySet<number>; requestSamples?: () => void };
export const ChipContext = createContext<TerminalChips>({ insert: () => {}, selected: new Set() });

/** 명령 칩. 누르면 입력줄에 찍힌다. 화면 칩(`더 보기`·`펼치기`)과 달리 바로 실행하지 않는다. */
export function CommandChip({ command, children }: { command: string; children?: ReactNode }) {
  const { insert } = useContext(ChipContext);
  return (
    <button type="button" className="gt-chip" onClick={() => insert(command)}>
      {children ?? command}
    </button>
  );
}

/** 자료 번호 칸. 누르면 `고르기 <번호>`가 입력줄에 찍히고, 고른 자료면 앞에 `▸`(commands 6절). */
export function NumberCell({ number }: { number: number }) {
  const { insert, selected } = useContext(ChipContext);
  return (
    <span className="gt-row-num">
      {selected.has(number) && <span aria-label="선택됨">▸</span>}
      <button type="button" className="gt-num-chip" onClick={() => insert(`고르기 ${number}`)}>
        {number}
      </button>
    </span>
  );
}

/** 명령 한 번 = 블록 하나(디자인 시스템 1절 원칙 2). 입력줄(prompt)마다 새 블록을 연다. */
function toBlocks(lines: TerminalLine[]): TerminalLine[][] {
  const blocks: TerminalLine[][] = [];
  for (const line of lines) {
    if (line.kind === "prompt" || blocks.length === 0) blocks.push([line]);
    else blocks[blocks.length - 1].push(line);
  }
  return blocks;
}

/** 창 제목은 마지막에 친 명령 이름, 아무것도 안 쳤으면 `처음`(시안 Main·Logout ③④). */
function windowTitle(lines: TerminalLine[]): string {
  const prompts = lines.filter((line) => line.kind === "prompt");
  const last = prompts[prompts.length - 1];
  return last?.text.trim().split(/\s+/)[0] || "처음";
}

/** 기호 칸 없는 줄. 자료 한 줄과 `→` 다음 행동, 흐린 `· 요약 생성 중`. */
export function Plain({ dim = false, children }: { dim?: boolean; children: ReactNode }) {
  return (
    <div className={dim ? "gt-line gt-hint" : "gt-line"}>
      <span className="gt-line-text">{children}</span>
    </div>
  );
}

function withSource(item: ItemSummary): string {
  return item.source ? `${item.title} (${item.source})` : item.title;
}

function textTitle(title: string): string {
  return Array.from(title.split("\n")[0]).slice(0, TEXT_TITLE_LIMIT).join("").trimEnd();
}

function megabytes(bytes: number): string {
  return `${Math.round((bytes / BYTES_PER_MB) * 10) / 10}MB`;
}

const isProcessing = (item: ItemSummary) => item.status === "received" || item.status === "processing";

/** ARC-005 이유 낱말과 COM-004 파일 문구. */
function failureText(reason: SaveFailure): string {
  switch (reason.kind) {
    case "disconnected":
      return "연결 끊김";
    case "timedOut":
      return "응답 없음";
    case "serverError":
      return "서버 오류";
    case "unsupportedFormat":
      return `받지 않는 형식 (.${reason.fileExtension})`;
    case "tooLarge":
      return `20MB 넘음 (${reason.fileName} · ${megabytes(reason.bytes)})`;
  }
}

/** ARC-005 규칙 2. 크기·형식 거절은 COM-004 문구에 이미 무엇인지 들어 있어 파일 이름을 붙이지 않는다. */
function recoverySuffix(reason: SaveFailure, recovery: SaveRecovery): string {
  if (recovery.kind === "inputKept") return "  입력은 남겨 둠";
  if (recovery.kind === "file" && (reason.kind === "disconnected" || reason.kind === "timedOut" || reason.kind === "serverError")) {
    return ` (${recovery.name})`;
  }
  return "";
}

function SavedLines({ item }: { item: ItemSummary }) {
  return (
    <>
      <Line tone="ok">
        {item.kind === "text" ? `저장됨 (글)  ${textTitle(item.title)}` : `저장됨  ${withSource(item)}`}
      </Line>
      {isProcessing(item) && <Plain dim>· 요약 생성 중</Plain>}
    </>
  );
}

function AlreadySavedLines({ item }: { item: ItemSummary }) {
  return (
    <>
      <Line tone="warn">이미 저장됨 → {item.number}번 (새로 만들지 않음)</Line>
      <ListRow item={item} />
      <Plain>
        {"→ "}
        <CommandChip command={`고르기 ${item.number}`} />
      </Plain>
    </>
  );
}

function SaveFailedLines({ reason, recovery }: { reason: SaveFailure; recovery: SaveRecovery }) {
  return (
    <>
      <Line tone="error">{`저장 안 됨: ${failureText(reason)}${recoverySuffix(reason, recovery)}`}</Line>
      {recovery.kind === "retry" && <Plain>→ 다시: {recovery.command}</Plain>}
    </>
  );
}

function savedAtText(savedAt: string): string {
  const part = Object.fromEntries(SAVED_AT_FORMAT.formatToParts(new Date(savedAt)).map((p) => [p.type, p.value]));
  return `${part.year}-${part.month}-${part.day} ${part.hour}:${part.minute}`;
}

/** 요약 자리. ARC-005 처리 상태마다 꼬리표, 끝난 자료는 흐린 요약(목록에는 이름표 없음, ARC-004 예외). */
function rowSummary(item: ItemSummary): string | null {
  if (isProcessing(item)) return "· 요약 생성 중";
  // shortcut: `고치기`는 데모 범위 명령이 아니어서 칩(입력줄에 찍기) 대신 글자로만 둔다. 고치기가 들어오면 칩으로.
  if (item.status === "blocked") return `! 본문 못 가져옴 → 고치기 ${item.number}`;
  if (item.status === "failed") return "! 요약 못 만듦  제목·출처만 넘김";
  if (item.listSummary === null) return null;
  return item.partialNote ? `${item.listSummary} (${item.partialNote})` : item.listSummary;
}

/**
 * 찾기 일치 위치(commands 6절 목록 꼬리표). 행에 이미 보이는 곳(제목·출처·요약·태그)은 붙이지 않는다.
 * shortcut: 정책 문구는 `이미지 속 글자` 하나뿐이다. `본문` 표시는 정책에 문구가 생기면 더한다.
 */
const MATCH_LABEL: Partial<Record<NonNullable<ItemSummary["matchedIn"]>, string>> = {
  imageText: "이미지 속 글자",
};

const rowTone = (item: ItemSummary) =>
  item.status === "blocked" || item.status === "failed" ? "gt-warn" : "gt-hint";

/** 목록 제목. 누르면 `열기 <번호>`가 입력줄에 찍힌다(ARC-011 규칙 4). */
function TitleCell({ item }: { item: ItemSummary }) {
  const { insert } = useContext(ChipContext);
  return (
    <button type="button" className="gt-num-chip gt-row-title" onClick={() => insert(`열기 ${item.number}`)}>
      {item.kind === "text" ? textTitle(item.title) : item.title}
    </button>
  );
}

export function ListRow({ item }: { item: ItemSummary }) {
  const tags = item.tags.slice(0, LIST_TAG_LIMIT);
  const summary = rowSummary(item);
  const match = item.matchedIn === null ? undefined : MATCH_LABEL[item.matchedIn];
  return (
    <>
      <div className="gt-line gt-row">
        <NumberCell number={item.number} />
        <TitleCell item={item} />
        {item.source && <span className="gt-row-meta">{item.source}</span>}
        <span className="gt-row-meta">{savedAtText(item.savedAt)}</span>
      </div>
      {(summary !== null || match !== undefined || tags.length > 0) && (
        <div className={`gt-line gt-row-sub ${rowTone(item)}`}>
          {summary !== null && <span>{summary}</span>}
          {match !== undefined && <span className="gt-row-match">{`· ${match}`}</span>}
          {tags.length > 0 && <span className="gt-row-tags">{tags.map((tag) => `#${tag}`).join(" ")}</span>}
        </div>
      )}
    </>
  );
}

/** commands 6절 더 보기. 다음 쪽은 코어가 받는다. */
export function MoreChip({ onMoreRequested }: { onMoreRequested?: () => void }) {
  return (
    <Plain>
      {"→ "}
      <button type="button" className="gt-chip" onClick={onMoreRequested}>
        더 보기
      </button>
    </Plain>
  );
}

/**
 * 시점(F22) 날짜 계산. 한국 시간은 일광 절약 시간이 없어 UTC+9 고정이므로, 9시간을 더한 UTC 날짜를 한국 날짜로 쓴다.
 * 날짜는 1970-01-01부터 센 한국 날짜 번호로 다룬다.
 */
const KST_OFFSET_MS = 9 * 60 * 60 * 1000;
const DAY_MS = 24 * 60 * 60 * 1000;
const DAYS_PER_WEEK = 7;

const kstDay = (ms: number) => Math.floor((ms + KST_OFFSET_MS) / DAY_MS);
/** 주는 월요일에 시작한다(commands 3절 시점). */
function weekStart(day: number): number {
  const sundayBased = new Date(day * DAY_MS).getUTCDay();
  return day - ((sundayBased + DAYS_PER_WEEK - 1) % DAYS_PER_WEEK);
}
function monthDay(day: number): string {
  const date = new Date(day * DAY_MS);
  return `${date.getUTCMonth() + 1}/${date.getUTCDate()}`;
}

/** 기간의 첫날과 마지막 날. to는 반열린 구간 끝이라 1ms 앞이 마지막 날이다. */
function periodDays(period: Period): { first: number; last: number } {
  return { first: kstDay(Date.parse(period.from)), last: kstDay(Date.parse(period.to) - 1) };
}

/** 기간이 여러 주에 걸치면 주 구분선을 넣는다(user-flow 5절 3번). */
function spansWeeks(period: Period): boolean {
  const { first, last } = periodDays(period);
  return weekStart(first) !== weekStart(last);
}

/** 주 구분선 `── 10/26~11/1 ──`. 기간 끝에서 자르지 않고 월~일 한 주를 보인다(시안 TimeSearch ②). */
function WeekDivider({ start }: { start: number }) {
  return <Plain dim>{`── ${monthDay(start)}~${monthDay(start + DAYS_PER_WEEK - 1)} ──`}</Plain>;
}

type ListLinesProps = { items: ItemSummary[]; hasMore: boolean; onMoreRequested?: () => void; period?: Period | null };

function ListLines({ items, hasMore, onMoreRequested, period }: ListLinesProps) {
  const divided = period != null && spansWeeks(period);
  const weekOf = (item: ItemSummary) => weekStart(kstDay(Date.parse(item.savedAt)));
  return (
    <>
      {items.map((item, index) => {
        const week = weekOf(item);
        const newWeek = divided && (index === 0 || weekOf(items[index - 1]) !== week);
        return (
          <Fragment key={item.number}>
            {newWeek && <WeekDivider start={week} />}
            <ListRow item={item} />
          </Fragment>
        );
      })}
      {hasMore && <MoreChip onMoreRequested={onMoreRequested} />}
    </>
  );
}

/** 찾기 머리줄 `4건`, 다음 쪽이 남으면 `23건 중 10건`. 머리 숫자는 보인 행 수와 맞춘다(commands 6절 더 보기). */
function searchHeader(total: number, shown: number): string {
  return shown < total ? `${total}건 중 ${shown}건` : `${total}건`;
}

/** 시점이 붙으면 머리 뒤에 ` · 지난달 (10/1~10/31)`(commands 6절 시점을 붙인 결과). */
function listHeader(total: number, shown: number, period: Period | null | undefined): string {
  const count = searchHeader(total, shown);
  if (period == null) return count;
  const { first, last } = periodDays(period);
  return `${count} · ${period.label} (${monthDay(first)}~${monthDay(last)})`;
}

type SearchResultLinesProps = {
  total: number;
  items: ItemSummary[];
  hasMore: boolean;
  onMoreRequested?: () => void;
  period?: Period | null;
  /** 결과 맨 아래 `→ 찾아두기 <검색어>` 칩의 검색어(ARC-012 규칙 9). 두지 않으면 null·없음 */
  saveQuery?: string | null;
};

function SearchResultLines({ total, items, hasMore, onMoreRequested, period, saveQuery }: SearchResultLinesProps) {
  return (
    <>
      <Plain>{listHeader(total, items.length, period)}</Plain>
      <ListLines items={items} hasMore={hasMore} onMoreRequested={onMoreRequested} period={period} />
      {saveQuery != null && (
        <Plain>
          {"→ "}
          <CommandChip command={`찾아두기 ${saveQuery}`} />
        </Plain>
      )}
    </>
  );
}

/**
 * ARC-012 규칙 9: 찾기 결과의 `찾아두기 <검색어>` 칩. 이미 찾아둔 검색어(isSavedSearch, 찾아두기 바로 뒤 결과)와
 * 시점이 붙은 찾기(규칙 4, 저장하지 않음)에는 두지 않는다.
 */
function saveQueryFor(line: Extract<TerminalLine, { kind: "searchResult" }>, savedInBlock: boolean): string | null {
  if (line.isSavedSearch === true || savedInBlock || line.period != null) return null;
  return line.query.text;
}

/** 가져오기 한 번에 받는 링크 수(COM-005, 발표 전 임시값). */
const IMPORT_LIMIT = 200;

type ImportFinishedLinesProps = { saved: number; skipped: number; failed: number; overLimit: number; failedUrls: string[] };

/**
 * commands 6절 가져오기 끝. 실패 링크는 줄마다(시안 Import ③).
 * overLimit 문구는 정책에 없어 개발 제안을 통합 세션이 승인했다(#127). commands.md에는 통합 PR에서 적는다.
 */
function ImportFinishedLines({ saved, skipped, failed, overLimit, failedUrls }: ImportFinishedLinesProps) {
  return (
    <>
      <Line tone="ok">{`저장 ${saved}건 · 건너뜀 ${skipped}건 (이미 저장됨) · 실패 ${failed}건`}</Line>
      {failedUrls.map((url) => (
        <Plain key={url} dim>{`  실패: ${url}`}</Plain>
      ))}
      {overLimit > 0 && (
        <Line tone="warn">
          {`${IMPORT_LIMIT}건 넘어 안 가져옴 ${overLimit}건  → 나눠서 다시: `}
          <CommandChip command="가져오기" />
        </Line>
      )}
    </>
  );
}

/** ARC-012 사용자 문구 찾아두기 결과. 결과 목록은 searchResult 줄이 이어서 그린다. */
function SearchSavedLines({ query, total, already }: { query: string; total: number; already: boolean }) {
  if (already) return <Line tone="warn">{`이미 찾아둠: ${query}`}</Line>;
  return (
    <>
      <Line tone="ok">{`찾아둠: ${query}  ${total}건`}</Line>
      <Line tone="info">{total === 0 ? "맞는 자료가 저장되면 모임" : "보관함 저장한 찾기에 있음"}</Line>
    </>
  );
}

/** ARC-012 규칙 6 찾아둔 목록. 순서는 서버가 만든 순서 최신부터 준다. 검색어를 누르면 `찾아두기 <검색어>`가 찍힌다. */
function SavedSearchListLines({ searches }: { searches: SavedSearchEntry[] }) {
  if (searches.length === 0) {
    return (
      <>
        <Line tone="info">찾아둔 것 없음</Line>
        <Plain>
          {"→ "}
          <CommandChip command="찾아두기 ">찾아두기 &lt;검색어&gt;</CommandChip>
        </Plain>
      </>
    );
  }
  return (
    <>
      <Plain>{`${searches.length}개 찾아둠`}</Plain>
      {searches.map((search) => (
        <NameCountRow key={search.query} name={search.query} count={search.count} command={`찾아두기 ${search.query}`} />
      ))}
    </>
  );
}

/** 0건 뒤 최근 자료는 검색 결과처럼 읽히지 않게 머리줄을 단다(commands 6절, ARC-002 사용자 문구). */
/**
 * commands 5절 없는 명령. 가까운 명령(F17)이 있으면 고친 입력을 묻고, 없으면 도움말로 안내한다.
 * 제안 칩은 다른 명령 칩처럼 입력줄에 찍기만 한다. 엔터 한 번으로 제안을 실행하는 것은 코어가 맡는다(commands 5절 입력 받아 주기).
 */
function UnknownCommandLines({ name, suggestion }: { name: string; suggestion: string | null }) {
  return (
    <>
      <Line tone="error">
        <b>없는 명령:</b> {name}
      </Line>
      <Plain>
        {"→ "}
        {suggestion === null ? (
          <>
            {"명령 목록: "}
            <CommandChip command="도움말" />
          </>
        ) : (
          <>
            <CommandChip command={suggestion} />?
          </>
        )}
      </Plain>
    </>
  );
}

/** 시점 낱말을 뺀 검색어(`결제 #위젯`). 시점이 붙은 찾기에서 query.text는 시점까지 친 그대로라 다시 만든다. */
const queryWithoutPeriod = (query: SearchQuery) => [query.words, ...query.tags.map((tag) => `#${tag}`)].filter(Boolean).join(" ");

type NoResultsLinesProps = { query: SearchQuery; recent: ItemSummary[]; period?: Period | null; related?: ItemSummary[] | null };

/**
 * 0건 뒤 목록. 뜻이 가까운 자료(#128, ADR-BCK-016)가 있으면 최근 저장 대신 그것을 보인다. 문구는 통합 세션 확정(사용자 승인).
 * 시점이 붙은 0건이어도 같고, `→ 기간 없이` 줄은 그 위에 그대로 둔다.
 */
function NoResultsList({ recent, related }: { recent: ItemSummary[]; related: ItemSummary[] }) {
  if (related.length > 0) {
    return (
      <>
        <Line tone="info">{`뜻이 가까운 자료 ${related.length}건 (낱말은 다름)`}</Line>
        <ListLines items={related} hasMore={false} />
      </>
    );
  }
  return (
    <>
      {recent.length > 0 && <Line tone="info">{`최근 저장 ${recent.length}건 (검색 결과 아님)`}</Line>}
      <ListLines items={recent} hasMore={false} />
    </>
  );
}

function NoResultsLines({ query, recent, period, related }: NoResultsLinesProps) {
  const bare = queryWithoutPeriod(query);
  return (
    <>
      {period == null ? (
        <Line tone="info">{`0건: "${query.text}"`}</Line>
      ) : (
        // commands 6절 시점을 붙인 결과: `· 0건: "결제" (지난달)` 뒤에 `→ 기간 없이: 찾기 결제`.
        <>
          <Line tone="info">{`0건: "${bare}" (${period.label})`}</Line>
          <Plain>
            {"→ 기간 없이: "}
            <CommandChip command={`찾기 ${bare}`} />
          </Plain>
        </>
      )}
      <NoResultsList recent={recent} related={related ?? []} />
    </>
  );
}

function CommandFailedLines({ command, reason, retry }: { command: CommandName; reason: CommandFailure; retry: string }) {
  return (
    <>
      <Line tone="error">{`${COMMAND_LABEL[command]} 안 됨: ${COMMAND_FAILURE_LABEL[reason]}`}</Line>
      <Plain>→ 다시: {retry}</Plain>
    </>
  );
}

const titles = (items: ItemRef[]) => items.map((ref) => ref.title).join(" · ");

/** commands 6절 고르기. */
function PickedLines({ items }: { items: ItemRef[] }) {
  return (
    <>
      <Line tone="ok">{`선택 ${items.length}건  ${titles(items)}`}</Line>
      <Plain>
        {"→ "}
        <CommandChip command="넘기기" />
        {" 또는 "}
        <CommandChip command="묶음 ">묶음 &lt;이름&gt;</CommandChip>
      </Plain>
    </>
  );
}

const charCountText = (count: number) => `${count.toLocaleString("ko-KR")}자`;

/** 넘긴 자료마다 `<번호>  <제목>` 한 줄. */
function ItemRefRows({ items }: { items: ItemRef[] }) {
  return (
    <>
      {items.map((ref) => (
        <div key={ref.number} className="gt-line gt-row">
          <NumberCell number={ref.number} />
          <span>{ref.title}</span>
        </div>
      ))}
    </>
  );
}

/**
 * 넘긴 글 전체. 터미널 글꼴이 아닌 읽기 글꼴로 줄바꿈을 그대로 보인다(시안 Handoff).
 * selectAll: 클립보드 거부 때 전체를 선택해 둔다(COM-008 규칙 6). 입력줄에 초점이 있으면 복사 키가 입력줄을 복사하므로 미리보기로 초점을 옮긴다.
 */
function Preview({ text, selectAll = false }: { text: string; selectAll?: boolean }) {
  const ref = useRef<HTMLPreElement>(null);
  useEffect(() => {
    const preview = ref.current;
    if (!selectAll || preview === null) return;
    preview.focus();
    window.getSelection()?.selectAllChildren(preview);
  }, [selectAll]);
  return (
    <pre ref={ref} className="gt-preview" tabIndex={selectAll ? -1 : undefined}>
      {text}
    </pre>
  );
}

/** COM-008 값: 6건부터 묻고, 11건부터 `앞10`을 더한다. */
const HANDOFF_DIRECT_LIMIT = 5;
const HANDOFF_FIRST_LIMIT = 10;

/** COM-008 확인 질문. 답 낱말은 명령 칩처럼 입력줄에 찍기만 한다(엔터로 답, COM-007). */
function HandoffConfirmLines({ total }: { total: number }) {
  return (
    <>
      <Line tone="warn">{`${total}건: 바로 복사 안 함 (${HANDOFF_DIRECT_LIMIT}건 초과)`}</Line>
      <Plain>
        {"→ "}
        {total > HANDOFF_FIRST_LIMIT && (
          <>
            <CommandChip command={`앞${HANDOFF_FIRST_LIMIT}`} />
            {`: 앞 ${HANDOFF_FIRST_LIMIT}건만 · `}
          </>
        )}
        <CommandChip command="전부" />
        {`: ${total}건 전부 · 취소: 그 외 입력`}
      </Plain>
    </>
  );
}

/** COM-007 확인 답. 실행 낱말은 칩으로 입력줄에 찍기만 한다(엔터로 답). */
function ConfirmAnswer({ word }: { word: string }) {
  return (
    <Plain>
      {"→ 실행: "}
      <CommandChip command={word} />
      {" 다시 입력 · 취소: 그 외 입력"}
    </Plain>
  );
}

/** ARC-008 2건 이상 버리기 확인. */
function DropConfirmLines({ total }: { total: number }) {
  return (
    <>
      <Line tone="warn">{`버리기? ${total}건 (휴지통으로)`}</Line>
      <ConfirmAnswer word="버리기" />
    </>
  );
}

/** ARC-008 휴지통 비우기 확인. */
function BinEmptyConfirmLines({ total }: { total: number }) {
  return (
    <>
      <Line tone="warn">{`비우기? ${total}건 (되돌릴 수 없음)`}</Line>
      <ConfirmAnswer word="비우기" />
    </>
  );
}

/** ACC-002 모든 기기 로그아웃 확인. 끊길 AI 도구 연결이 있으면 `· AI 도구 연결 N개`, 없거나 모르면 그 칸을 뺀다. */
function SignOutEverywhereConfirmLines({ connectionCount }: { connectionCount: number | null }) {
  const connections = connectionCount !== null && connectionCount > 0 ? ` · AI 도구 연결 ${connectionCount}개` : "";
  return (
    <>
      <Line tone="warn">{`로그아웃? 모든 기기${connections} (다른 기기는 최대 1시간 뒤)`}</Line>
      <ConfirmAnswer word="로그아웃" />
    </>
  );
}

/** 연결 목록 날짜 `11/20`. 한국 날짜다(ARC-004 규칙 7). */
const connectionDay = (iso: string) => monthDay(kstDay(Date.parse(iso)));

/** ACC-002 규칙 7·10 `연결`: 연결 주소 안내 두 줄, 그 아래 연결 목록. 읽은 적 없는 연결은 `읽음` 칸을 뺀다. */
function ConnectionListLines({ mcpUrl, connections }: { mcpUrl: string; connections: ConnectionEntry[] }) {
  return (
    <>
      <Line tone="info">{`연결 주소  ${mcpUrl}`}</Line>
      <Plain dim>{"  AI 도구의 연결(MCP) 설정에 이 주소를 넣고 그렙 계정으로 로그인. 연결한 도구는 검색·읽기만 가능"}</Plain>
      {connections.length === 0 ? (
        <Line tone="info">연결 0개</Line>
      ) : (
        <>
          <Plain>{`${connections.length}개 연결`}</Plain>
          {connections.map((connection) => (
            <div key={connection.number} className="gt-line gt-name-row">
              <span className="gt-row-num">{connection.number}</span>
              <span>{connection.client}</span>
              <span className="gt-hint">{`연결 ${connectionDay(connection.connectedAt)}`}</span>
              {connection.lastReadAt !== null && <span className="gt-hint">{`읽음 ${connectionDay(connection.lastReadAt)}`}</span>}
            </div>
          ))}
          <Plain>
            {"→ "}
            <CommandChip command="연결 끊기 ">연결 끊기 &lt;번호&gt;</CommandChip>
          </Plain>
        </>
      )}
    </>
  );
}

/** ACC-002 규칙 11 연결이 끝난 이유. revoked 낱말은 정책에 없어 계약 설명(다른 기기에서 끊음·모든 기기 로그아웃)에서 줄였다. */
const CONNECTION_END_REASON = { expired: "로그인 만료", revoked: "다른 기기에서 끊음" } as const;

/** 휴지통 행. 시각 칸에 영구 삭제까지 남은 날(ARC-008 규칙 10). */
function TrashRow({ entry: { item, daysLeft } }: { entry: TrashEntry }) {
  return (
    <div className="gt-line gt-row">
      <NumberCell number={item.number} />
      <span>{item.kind === "text" ? textTitle(item.title) : item.title}</span>
      {item.source && <span className="gt-row-meta">{item.source}</span>}
      <span className="gt-row-meta">{`${daysLeft}일 남음`}</span>
    </div>
  );
}

/** 빈 휴지통(`휴지통` 목록 0건, 빈 휴지통 비우기). 문구는 정책에 없어 통합 세션 요청을 따른다. */
function EmptyBinLine() {
  return <Line tone="info">휴지통 비어 있음</Line>;
}

type BinListLinesProps = { total: number; items: TrashEntry[]; hasMore: boolean; onMoreRequested?: () => void };

/** `휴지통` 목록(ARC-008 규칙 5, 시안 Trash ③). 순서는 서버가 지운 날 최신순으로 준다. */
function BinListLines({ total, items, hasMore, onMoreRequested }: BinListLinesProps) {
  if (total === 0) return <EmptyBinLine />;
  return (
    <>
      <Plain>{searchHeader(total, items.length)}</Plain>
      {items.map((entry) => (
        <TrashRow key={entry.item.number} entry={entry} />
      ))}
      {hasMore && <MoreChip onMoreRequested={onMoreRequested} />}
      <Plain>
        {"→ "}
        <CommandChip command="되살리기 ">되살리기</CommandChip>
        {" 또는 "}
        <CommandChip command="휴지통 비우기" />
      </Plain>
    </>
  );
}

/** 이름 목록 한 줄 `<이름>  N건`(묶음·찾아둔 것). 이름을 누르면 그 명령이 찍힌다(commands 6절 출력 원칙). */
function NameCountRow({ name, count, command }: { name: string; count: number; command: string }) {
  return (
    <div className="gt-line gt-name-row">
      <CommandChip command={command}>{name}</CommandChip>
      <span className="gt-hint">{`${count}건`}</span>
    </div>
  );
}

/** ARC-003 규칙 3 묶음 목록. 순서는 서버가 최근에 바뀐 순으로 준다. 없으면 차례로 할 일을 줄을 나눠 안내한다. */
function BundleListLines({ bundles }: { bundles: BundleEntry[] }) {
  if (bundles.length === 0) {
    return (
      <>
        <Line tone="info">묶음 0개</Line>
        <Plain>
          {"→ "}
          <CommandChip command="고르기 ">고르기 &lt;번호&gt;</CommandChip>
        </Plain>
        <Plain>
          {"→ "}
          <CommandChip command="묶음 ">묶음 &lt;이름&gt;</CommandChip>
        </Plain>
      </>
    );
  }
  return (
    <>
      <Plain>{`${bundles.length}개 묶음`}</Plain>
      {bundles.map((bundle) => (
        <NameCountRow key={bundle.name} name={bundle.name} count={bundle.count} command={`묶음 ${bundle.name}`} />
      ))}
    </>
  );
}

/** ARC-003 넣기. count는 넣은 뒤 묶음 건수다. */
function BundleAddedLines({ name, count, alreadyCount }: { name: string; count: number; alreadyCount: number }) {
  const already = alreadyCount > 0 ? ` (이미 있음 ${alreadyCount}건)` : "";
  return (
    <>
      <Line tone="ok">{`묶음 ${name}: ${count}건${already}`}</Line>
      <Plain>
        {"→ 다음부터: "}
        <CommandChip command={`넘기기 ${name}`} />
      </Plain>
    </>
  );
}

type BundleViewLinesProps = { name: string; total: number; items: ItemSummary[]; hasMore: boolean; onMoreRequested?: () => void };

/** ARC-003 규칙 5 묶음 안 자료(번호 큰 순). 다음 쪽이 남으면 머리 숫자를 보인 행 수와 맞춘다(commands 6절 더 보기). */
function BundleViewLines({ name, total, items, hasMore, onMoreRequested }: BundleViewLinesProps) {
  return (
    <>
      <Plain>{`묶음 ${name}  ${searchHeader(total, items.length)}`}</Plain>
      <ListLines items={items} hasMore={hasMore} onMoreRequested={onMoreRequested} />
    </>
  );
}

/** ARC-003 규칙 8 묶음 지우기 확인. */
function BundleDeleteConfirmLines({ name, itemCount }: { name: string; itemCount: number }) {
  return (
    <>
      <Line tone="warn">{`지우기? 묶음 ${name} (자료 ${itemCount}건은 남음)`}</Line>
      <ConfirmAnswer word="지우기" />
    </>
  );
}

/** ARC-003 사용자 문구 이름 규칙 위반·금지 이름. */
const BUNDLE_NAME_RULE = {
  format: "묶음 이름: 띄어쓰기 없이 1~20자 (한글·영문·숫자·-·_)",
  reserved: "묶음 이름: 숫자만 · #시작 · 빼기 · 지우기 불가",
} as const;

/** ARC-005·COM-004 `본문 못 가져옴: <이유>`의 이유 낱말. */
const BLOCKED_REASON_LABEL: Record<BlockedReason, string> = {
  loginRequired: "로그인 필요",
  accessDenied: "접근 거부",
  disallowedURL: "열지 않는 주소",
  encrypted: "암호 걸린 PDF",
  noText: "글자 없음",
};

/** ARC-005 처리 상태 문구. 파일 이유(COM-004)에는 `제목·링크만 저장`을 붙이지 않는다. ready면 null. */
function statusText(item: ItemSummary): { tone: "hint" | "warn"; text: string } | null {
  if (isProcessing(item)) return { tone: "hint", text: "· 요약 생성 중" };
  if (item.status === "failed") return { tone: "warn", text: "! 요약 못 만듦  제목·출처만 넘김" };
  if (item.status !== "blocked" || item.blockedReason === null) return null;
  const reason = BLOCKED_REASON_LABEL[item.blockedReason];
  return {
    tone: "warn",
    text: item.kind === "link" ? `! 본문 못 가져옴: ${reason}  제목·링크만 저장` : `! 본문 못 가져옴: ${reason}`,
  };
}

/** 새 탭으로 열 주소. http·https만 링크로 만든다(`javascript:` 같은 주소를 막는다). */
function isWebUrl(url: string): boolean {
  try {
    const { protocol } = new URL(url);
    return protocol === "http:" || protocol === "https:";
  } catch {
    return false;
  }
}

/** ARC-011 규칙 6-2 출처 칸. 링크 자료는 호스트를 누르면 원래 주소를 새 탭으로 연다. */
function DetailSource({ detail }: { detail: ItemDetail }) {
  const text = detailSource(detail);
  if (detail.item.kind !== "link" || detail.url === null || !isWebUrl(detail.url)) return <>{text}</>;
  return (
    <a className="gt-chip" href={detail.url} target="_blank" rel="noopener noreferrer">
      {text}
    </a>
  );
}

/** ARC-011 규칙 6-2 출처 글. 링크는 호스트, 아니면 `직접 넣음 · <형식>`(ARC-007 형식 값). 이미지는 미리보기 URL이 있는 파일이다(계약). */
function detailSource(detail: ItemDetail): string {
  const { item } = detail;
  if (item.kind === "link") return item.source ?? "";
  if (item.kind === "text") return "직접 넣음 · 글";
  if (detail.previewUrl !== null) return "직접 넣음 · 이미지";
  return item.source ? `직접 넣음 · ${item.source.toUpperCase()}` : "직접 넣음";
}

/** 자세히 보기 한 줄. 이름표 칸과 값 칸(시안 ItemDetail). */
function DetailRow({ label, tone, children }: { label: string; tone?: "hint" | "warn"; children: ReactNode }) {
  return (
    <div className={tone ? `gt-line gt-detail-row gt-${tone}` : "gt-line gt-detail-row"}>
      <span className="gt-detail-label">{label}</span>
      <span>{children}</span>
    </div>
  );
}

/** 칩 여럿을 한 칸 띄어 잇는다. */
function ChipList({ commands }: { commands: ReadonlyArray<readonly [label: string, command: string]> }) {
  return (
    <>
      {commands.map(([label, command], index) => (
        <Fragment key={command}>
          {index > 0 && " "}
          <CommandChip command={command}>{label}</CommandChip>
        </Fragment>
      ))}
    </>
  );
}

/** ARC-011 규칙 6-8·7 본문 머리. 일부만 읽었으면 ARC-004 규칙 8 문구를 붙인다. */
function bodyHead(detail: ItemDetail): string {
  const from = detail.bodyFromImage ? "(이미지에서 읽음) " : "";
  const partial = detail.item.partialNote ? ` (${detail.item.partialNote})` : "";
  // 본문이 있으면 서버가 글자 수도 준다. 없으면 받은 본문(앞 2만 자) 길이로 대신한다.
  return `${from}${charCountText(detail.bodyLength ?? Array.from(detail.body ?? "").length)}${partial}  `;
}

/** ARC-011 규칙 6-9 원본. 이미지는 그림, 파일은 `원본 열기`(서명 URL 10분). PDF 첫 쪽 그림은 계약에 아직 없다. */
function OriginalRow({ detail }: { detail: ItemDetail }) {
  if (detail.previewUrl === null && detail.originalUrl === null) return null;
  return (
    <DetailRow label="원본">
      <span className="gt-detail-original">
        {detail.previewUrl !== null && (
          <img className="gt-detail-image" src={detail.previewUrl} alt={`${detail.item.title} 미리보기`} />
        )}
        {detail.originalUrl !== null && (
          <a className="gt-chip" href={detail.originalUrl} target="_blank" rel="noopener noreferrer">
            원본 열기
          </a>
        )}
      </span>
    </DetailRow>
  );
}

/** ARC-011 규칙 6-8 본문. 본문이 없으면 이유가 있을 때만 `· 본문 없음: <이유>`. */
/**
 * 본문이 없을 때 `· 본문 없음: <이유>`의 이유(통합 세션 규칙, #131). blocked·failed만 그리고,
 * 처리 중(상태 줄이 알림)과 ready(본문 열이 생기기 전에 처리된 자료)는 본문 줄을 그리지 않는다.
 * failed 이유 `처리 실패`는 handoff-format 3절과 같은 낱말이다(`(요약 없음: 처리 실패)`, 통합 세션 확정).
 */
function noBodyReason(item: ItemSummary): string | null {
  if (item.status === "failed") return "처리 실패";
  if (item.status === "blocked" && item.blockedReason !== null) return BLOCKED_REASON_LABEL[item.blockedReason];
  return null;
}

function DetailBody({ detail }: { detail: ItemDetail }) {
  const { item } = detail;
  const [isExpanded, setExpanded] = useState(item.kind === "text");
  if (detail.body === null) {
    const reason = noBodyReason(item);
    return reason === null ? null : <Line tone="info">{`본문 없음: ${reason}`}</Line>;
  }
  return (
    <>
      <DetailRow label="본문">
        {bodyHead(detail)}
        <button type="button" className="gt-chip" aria-expanded={isExpanded} onClick={() => setExpanded(!isExpanded)}>
          {isExpanded ? "접기" : "펼치기"}
        </button>
      </DetailRow>
      {isExpanded && <Preview text={detail.body} />}
    </>
  );
}

/**
 * ARC-011 규칙 6 자세히 보기. 값이 없는 줄은 뺀다. 터미널 출력 블록은 연 때 모습 그대로 둔다(규칙 9).
 * 글 자료는 본문이 곧 원본이라 펼쳐 둔다. `펼치기`는 화면 칩이라 누르면 바로 펼친다.
 */
export function ItemDetailLines({ detail }: { detail: ItemDetail }) {
  const { item } = detail;
  const status = statusText(item);
  const summaryLabel = item.summarySource === "user" ? "요약 (직접 고침)" : "AI 요약";
  return (
    <section className="gt-detail" aria-label="자세히 보기">
      <div className="gt-line gt-row">
        <NumberCell number={item.number} />
        <b>{item.title}</b>
      </div>
      <DetailRow label="출처">
        <DetailSource detail={detail} />
      </DetailRow>
      <DetailRow label="저장">{savedAtText(item.savedAt)}</DetailRow>
      {status !== null && (
        <DetailRow label="상태" tone={status.tone}>
          {status.text}
        </DetailRow>
      )}
      {detail.handoffSummary !== null && <DetailRow label={summaryLabel}>{detail.handoffSummary}</DetailRow>}
      {detail.allTags.length > 0 && (
        <DetailRow label="태그 (AI 추정)">
          <ChipList commands={detail.allTags.map((tag) => [`#${tag}`, `찾기 #${tag}`] as const)} />
        </DetailRow>
      )}
      <DetailRow label="묶음">
        {detail.bundles.length === 0 ? "없음" : <ChipList commands={detail.bundles.map((name) => [name, `묶음 ${name}`] as const)} />}
      </DetailRow>
      <DetailBody detail={detail} />
      <OriginalRow detail={detail} />
      <Plain>
        {"→ "}
        <CommandChip command={`고르기 ${item.number}`} />
        {" 또는 "}
        <CommandChip command="묶음 ">묶음 &lt;이름&gt;</CommandChip>
        {" 또는 "}
        <CommandChip command={`고치기 ${item.number}`} />
        {" 또는 "}
        <CommandChip command={`버리기 ${item.number}`} />
      </Plain>
    </section>
  );
}

/** COM-008 값: 직접 복사 키. 터치 기기 문구는 AI 제안(PO 확인 전). */
function copyKeyHint(): string {
  if (typeof window.matchMedia === "function" && window.matchMedia("(hover: none) and (pointer: coarse)").matches) {
    return "길게 눌러 복사";
  }
  return /mac|iphone|ipad/i.test(navigator.platform) ? "⌘C" : "Ctrl+C";
}

/** COM-008 넘기기 실패. 선택은 풀지 않는다(코어). 클립보드 거부만 펼친 미리보기와 직접 복사 키를 보인다. */
function HandoffFailedLines({ reason, preview }: { reason: CommandFailure; preview: string | null }) {
  const isDenied = reason === "clipboardDenied";
  return (
    <>
      <Line tone="error">{`복사 안 됨: ${COMMAND_FAILURE_LABEL[reason]}  선택은 남겨 둠`}</Line>
      {isDenied && preview !== null && <Preview text={preview} selectAll />}
      <Plain>
        {isDenied ? `→ 직접 복사: ${copyKeyHint()} · 다시: ` : "→ "}
        <CommandChip command="넘기기" />
      </Plain>
    </>
  );
}

/** commands 6절 넘기기, 넘길 글 형식 3절. `펼치기`는 화면 칩이라 누르면 바로 펼친다. */
function HandedOffLines({ result }: { result: HandoffResult }) {
  const [isExpanded, setExpanded] = useState(false);
  return (
    <>
      {/* ARC-003 규칙 10. 시안 Bundles ④는 복사됨 앞에 둔다. */}
      {(result.removedCount ?? 0) > 0 && <Line tone="warn">{`빠진 자료 ${result.removedCount}건 (삭제됨)`}</Line>}
      <Line tone="ok">{`복사됨  ${result.items.length}건 · ${charCountText(result.charCount)} (제목·출처·저장 시각·요약)`}</Line>
      <ItemRefRows items={result.items} />
      {result.missingSummaryCount > 0 && <Line tone="warn">{`요약 없음 ${result.missingSummaryCount}건`}</Line>}
      <Line tone="info">
        {"미리보기: "}
        <button type="button" className="gt-chip" aria-expanded={isExpanded} onClick={() => setExpanded(!isExpanded)}>
          {isExpanded ? "접기" : "펼치기"}
        </button>
      </Line>
      {isExpanded && <Preview text={result.text} />}
      <Line tone="info">클립보드에 있음 → AI 도구 입력창에 붙여 넣기</Line>
    </>
  );
}

/** 터미널 출력 맨 위의 두더지 머리. 로그인 화면과 같은 한 문장·표어다. */
function TerminalHead() {
  return <Banner lead="저장해 둔 링크·캡처·PDF를 찾아 AI 도구에 붙여 넣을 글로 복사" tagline="담기 → 찾기 → 넘기기" />;
}

/**
 * 자료가 있는 계정의 터미널 맨 위(시안 web-07). 머리 아래에 `· 자료 N건`과 `· 명령 전체: 도움말`을 둔다.
 * 건수는 지금 값이다. 받기 전이면 건수 줄을 뺀다.
 */
function TerminalIntro({ itemCount }: { itemCount: number | null }) {
  return (
    <div className="gt-head">
      <TerminalHead />
      {itemCount !== null && <Line tone="info">자료 {itemCount.toLocaleString("ko-KR")}건</Line>}
      <Line tone="info">
        {"명령 전체: "}
        <CommandChip command="도움말" />
      </Line>
    </div>
  );
}

/** commands 6절 첫 화면(자료 0건). 명령 13줄 표는 보이지 않는다. */
/** ARC-010 규칙 2: 누르면 바로 저장. 두 번 눌러도 한 번만 저장하는 것(규칙 7)은 코어·서버가 지킨다. */
function SamplesChip() {
  const { requestSamples } = useContext(ChipContext);
  return (
    <button type="button" className="gt-chip" onClick={requestSamples}>
      샘플 8건으로 해 보기
    </button>
  );
}

/** ARC-010 규칙 4: 받은 번호 범위와 치우는 법을 한 줄씩, 이어서 `최근`과 같은 목록. */
function SamplesSavedLines({ firstNumber, lastNumber, items }: { firstNumber: number; lastNumber: number; items: ItemSummary[] }) {
  const range = `${firstNumber}-${lastNumber}`;
  return (
    <>
      <Line tone="ok">{`샘플 ${lastNumber - firstNumber + 1}건 저장 (${range}번)`}</Line>
      <Line tone="info">
        {"치우려면: "}
        <CommandChip command={`버리기 ${range}`} />
      </Line>
      <ListLines items={items} hasMore={false} />
    </>
  );
}

function WelcomeLines() {
  return (
    <>
      <TerminalHead />
      <Line tone="info">자료 0건</Line>
      <Plain>
        {"→ "}
        <SamplesChip />
        {" 또는 아래에 링크 붙여 넣기"}
      </Plain>
      <Line tone="info">
        {"명령 전체: "}
        <CommandChip command="도움말" />
      </Line>
    </>
  );
}

/** commands 2절 `도움말` 화면. 명령 18줄(한글·영문·뜻): 데모 13줄 + 휴지통 3줄(ARC-008, #96) + 열기·찾아두기(#131·#134). QA F-01 */
const GUIDE_ROWS: ReadonlyArray<readonly [string, string, string]> = [
  ["담기", "keep", "자료 저장"],
  ["최근", "recent", "최근 자료 목록"],
  ["찾기", "seek", "검색"],
  ["열기", "peek", "자료 자세히 보기"],
  ["찾아두기", "gather", "검색어 저장"],
  ["고르기", "pick", "번호로 선택"],
  ["넘기기", "handoff", "AI 도구용 글 복사"],
  ["묶음", "pack", "선택에 이름 붙이기"],
  ["고치기", "revise", "제목·요약 수정"],
  ["버리기", "drop", "삭제"],
  ["되살리기", "revive", "휴지통에서 돌리기"],
  ["휴지통", "bin", "휴지통 목록"],
  ["휴지통 비우기", "bin empty", "휴지통 영구 삭제"],
  ["가져오기", "bring", "북마크 파일 가져오기"],
  ["연결", "plug", "AI 도구 연결"],
  ["로그아웃", "signout", "로그아웃"],
  ["도움말", "guide", "명령 목록"],
  ["설명", "about", "명령 설명"],
];

function GuideLines() {
  return (
    <>
      <Plain>저장: 링크·글 붙여 넣기, 파일 끌어다 놓기. 명령: 한글·영문 같음</Plain>
      {GUIDE_ROWS.map(([name, english, meaning]) => (
        <div key={name} className="gt-line gt-guide-row">
          <span className="gt-guide-name">{name}</span>
          <span className="gt-hint">{english}</span>
          <span>{meaning}</span>
        </div>
      ))}
      <Plain>
        {"→ 예: "}
        <CommandChip command="찾기 결제 | 넘기기" />
        {" · 자세히: "}
        <CommandChip command="설명 찾기" />
      </Plain>
    </>
  );
}

/** savedInBlock: 같은 블록에 찾아두기 결과(searchSaved)가 있다. 뒤따르는 찾기 결과는 이미 찾아둔 검색어다. */
type OutputLineProps = { line: TerminalLine; failed: boolean; savedInBlock: boolean; onMoreRequested?: () => void };

function OutputLine({ line, failed, savedInBlock, onMoreRequested }: OutputLineProps) {
  switch (line.kind) {
    case "prompt":
      return <Prompt cmd={line.text} failed={failed} />;
    case "unknownCommand":
      return <UnknownCommandLines name={line.name} suggestion={line.suggestion ?? null} />;
    case "missingArgument":
      // 다른 명령의 빠진 인자 문구는 그 명령의 실행 이슈에서 더한다.
      if (line.command === "keep") return <Line tone="error">저장할 것 없음  예: 담기 https://…</Line>;
      // commands 6절 "빠진 인자".
      if (line.command === "seek") return <Line tone="error">검색어 없음  예: 찾기 결제</Line>;
      // ARC-001 사용자 문구.
      // #154 `고르기 빼기`를 번호 없이 치면 빼기 예시.
      if (line.command === "pick" && line.sub === "unpick") return <Line tone="error">번호 없음  예: 고르기 빼기 131</Line>;
      if (line.command === "pick") return <Line tone="error">번호 없음  예: 고르기 131</Line>;
      // ARC-011 사용자 문구.
      if (line.command === "peek") return <Line tone="error">번호 없음  예: 열기 131</Line>;
      // ARC-012 사용자 문구.
      if (line.command === "gather") return <Line tone="error">검색어 없음  예: 찾아두기 텀블러 캠페인</Line>;
      return null;
    case "missingTag":
      // ARC-002 사용자 문구.
      return <Line tone="error">태그 없음  예: 찾기 #결제</Line>;
    case "saved":
      return <SavedLines item={line.item} />;
    case "alreadySaved":
      return <AlreadySavedLines item={line.item} />;
    case "inTrash":
      return <Line tone="warn">{`휴지통에 있음 → ${line.number}번. 되살리기 ${line.number}`}</Line>;
    case "saveFailed":
      return <SaveFailedLines reason={line.reason} recovery={line.recovery} />;
    case "importSuggest":
      // 제안만 한다. 실수로 수백 건이 들어가지 않게 가져오기는 사용자가 친다(#172).
      return (
        <Plain>
          {"→ 북마크 파일이면: "}
          <CommandChip command="가져오기" />
        </Plain>
      );
    case "recentList":
      // 시점이 없는 `최근`은 머리 줄 없이 목록만(commands 6절). 시점이 있으면 찾기와 같은 머리 줄.
      if (line.period == null) return <ListLines items={line.items} hasMore={line.hasMore} onMoreRequested={onMoreRequested} />;
      return (
        <SearchResultLines
          total={line.total ?? line.items.length}
          items={line.items}
          hasMore={line.hasMore}
          onMoreRequested={onMoreRequested}
          period={line.period}
        />
      );
    case "searchResult":
      return (
        <SearchResultLines
          total={line.total}
          items={line.items}
          hasMore={line.hasMore}
          onMoreRequested={onMoreRequested}
          period={line.period}
          saveQuery={saveQueryFor(line, savedInBlock)}
        />
      );
    case "noResults":
      return <NoResultsLines query={line.query} recent={line.recent} period={line.period} related={line.related} />;
    case "picked":
      return <PickedLines items={line.items} />;
    case "notFound":
      return <Line tone="error">{`없는 번호: ${line.numbers.join(", ")}`}</Line>;
    case "invalidNumber":
      return <Line tone="error">{`잘못된 번호: ${line.input}  예: ${PICK_EXAMPLE}`}</Line>;
    case "handedOff":
      return <HandedOffLines result={line.result} />;
    case "welcome":
      return <WelcomeLines />;
    case "guide":
      return <GuideLines />;
    case "handoffConfirm":
      return <HandoffConfirmLines total={line.total} />;
    case "cancelled":
      // COM-007 사용자 문구.
      return <Line tone="info">취소됨</Line>;
    case "handoffFailed":
      return <HandoffFailedLines reason={line.reason} preview={line.preview} />;
    case "commandFailed":
      return <CommandFailedLines command={line.command} reason={line.reason} retry={line.retry} />;
    case "reconnected":
      return <Line tone="ok">연결됨</Line>;
    case "dropped":
      // ARC-008 사용자 문구. 되살리기는 `<번호...>`를 받으므로 옮긴 번호를 모두 적는다.
      return (
        <Line tone="ok">
          {`휴지통 ${line.items.length}건 (30일 뒤 삭제, 되살리기 ${line.items.map((ref) => ref.number).join(" ")})`}
        </Line>
      );
    case "dropConfirm":
      return <DropConfirmLines total={line.total} />;
    case "binList":
      return (
        <BinListLines total={line.total} items={line.items} hasMore={line.hasMore} onMoreRequested={onMoreRequested} />
      );
    case "binEmptyConfirm":
      return <BinEmptyConfirmLines total={line.total} />;
    case "binEmptied":
      // 빈 휴지통을 비우면 `0건 영구 삭제` 대신 비어 있다고만 알린다(통합 세션 요청, 브라우저 실측).
      if (line.count === 0) return <EmptyBinLine />;
      // ARC-008 사용자 문구.
      return <Line tone="ok">{`비움  ${line.count}건 영구 삭제`}</Line>;
    case "signOutEverywhereConfirm":
      return <SignOutEverywhereConfirmLines connectionCount={line.connectionCount ?? null} />;
    // #124 AI 도구 연결(ACC-002 사용자 문구)
    case "connectionList":
      return <ConnectionListLines mcpUrl={line.mcpUrl} connections={line.connections} />;
    case "disconnectConfirm":
      return (
        <>
          <Line tone="warn">{`끊기? ${line.client} (다시 연결하려면 처음부터)`}</Line>
          <ConfirmAnswer word="끊기" />
        </>
      );
    case "disconnected":
      if (line.already) return <Line tone="warn">{`이미 끊김  ${line.client}`}</Line>;
      return <Line tone="ok">{`끊김  ${line.client}`}</Line>;
    case "connectionNotFound":
      return <Line tone="error">{`없는 연결: ${line.number}`}</Line>;
    case "connectionEnded":
      return (
        <>
          <Line tone="warn">{`연결 끊김: ${line.client} (${CONNECTION_END_REASON[line.reason]})`}</Line>
          <Plain>
            {"→ "}
            <CommandChip command="연결" />
          </Plain>
        </>
      );
    case "unpicked":
      // commands 6절 선택 빼기. 남은 수는 그 시점 값을 줄이 들고 온다(지난 줄이 나중 선택에 따라 바뀌지 않게).
      return <Line tone="ok">{`뺌  선택 ${line.remaining}건 남음`}</Line>;
    case "pickCleared":
      // commands 6절 선택 빼기 "모두 풀면 `✓ 선택 비움`". 건수는 문구에 없다.
      return <Line tone="ok">선택 비움</Line>;
    case "samplesSaved":
      return <SamplesSavedLines firstNumber={line.firstNumber} lastNumber={line.lastNumber} items={line.items} />;
    case "revised":
      return <RevisedLines item={line.item} />;
    case "tagsRemoved":
      // 시안 Edit ③(문구 제안). 지운 태그는 다시 붙지 않는다(ARC-002 규칙 2).
      return <Line tone="ok">{`태그 지움 ${line.tags.map((tag) => `#${tag}`).join(" ")} (${line.item.number}번)`}</Line>;
    case "revived":
      // ARC-008 사용자 문구.
      return <Line tone="ok">{`되살림 ${line.items.length}건`}</Line>;
    // #137 ARC-007 규칙 11: `폴더`·`mkdir` 입력은 없는 명령이 아니라 안내.
    case "folderHint":
      return (
        <Line tone="info">
          {"폴더 없음: 묶음이 폴더 역할  → "}
          <CommandChip command="고르기 ">고르기 &lt;번호&gt;</CommandChip>
          {" · "}
          <CommandChip command="묶음 ">묶음 &lt;이름&gt;</CommandChip>
        </Line>
      );
    // #127 북마크 가져오기(commands 6절). 진행은 뒤에서 이어진다(user-flow 10절)
    case "importPrompt":
      return <Line tone="info">북마크 파일을 끌어다 놓기 (브라우저에서 내보낸 HTML, 한 번에 200건)</Line>;
    case "importProgress":
      return (
        <>
          <Line tone="info">{`가져오는 중  ${line.done} / ${line.total}건`}</Line>
          <Plain dim>{"  다른 명령을 쳐도 계속됨"}</Plain>
        </>
      );
    case "importFinished":
      return (
        <ImportFinishedLines
          saved={line.saved}
          skipped={line.skipped}
          failed={line.failed}
          overLimit={line.overLimit}
          failedUrls={line.failedUrls}
        />
      );
    // #134 찾아두기(ARC-012 사용자 문구)
    case "searchSaved":
      return <SearchSavedLines query={line.query} total={line.total} already={line.already} />;
    case "savedSearchList":
      return <SavedSearchListLines searches={line.searches} />;
    case "savedSearchPeriod":
      return (
        <>
          <Line tone="error">{`시점은 찾아두지 않음: ${line.period}`}</Line>
          <Plain>
            {"→ "}
            <CommandChip command={line.suggestion} />
          </Plain>
        </>
      );
    case "savedSearchTooLong":
      return <Line tone="error">검색어 40자 초과</Line>;
    case "savedSearchDeleteConfirm":
      return (
        <>
          <Line tone="warn">{`지우기? 찾아둔 ${line.query} (자료는 남음)`}</Line>
          <ConfirmAnswer word="지우기" />
        </>
      );
    case "savedSearchDeleted":
      return <Line tone="ok">{`지움  찾아둔 ${line.query}`}</Line>;
    case "savedSearchNotFound":
      return <Line tone="error">{`찾아둔 것 없음: ${line.query}`}</Line>;
    // #131 자세히 보기(ARC-011)
    case "itemDetail":
      return <ItemDetailLines detail={line.detail} />;
    case "oneNumberOnly":
      return <Line tone="error">{`번호 하나만  예: ${COMMAND_LABEL[line.command]} 131`}</Line>;
    // #121 묶음(ARC-003 사용자 문구)
    case "bundleList":
      return <BundleListLines bundles={line.bundles} />;
    case "bundleAdded":
      return <BundleAddedLines name={line.name} count={line.count} alreadyCount={line.alreadyCount} />;
    case "bundleView":
      return (
        <BundleViewLines
          name={line.name}
          total={line.total}
          items={line.items}
          hasMore={line.hasMore}
          onMoreRequested={onMoreRequested}
        />
      );
    case "bundleNotFound":
      return (
        <Line tone="error">
          {`없는 묶음: ${line.name}  → `}
          <CommandChip command="묶음" />
        </Line>
      );
    case "bundleUnpicked":
      return <Line tone="ok">{`뺌  묶음 ${line.name}: ${line.remaining}건 남음`}</Line>;
    case "notInBundle":
      // 없는 번호(notFound)와 같게 쉼표로 잇는다.
      return <Line tone="error">{`묶음에 없음: ${line.numbers.join(", ")}`}</Line>;
    case "bundleDeleteConfirm":
      return <BundleDeleteConfirmLines name={line.name} itemCount={line.itemCount} />;
    case "bundleDeleted":
      return <Line tone="ok">{`삭제됨  묶음 ${line.name}`}</Line>;
    case "bundleNameInvalid":
      return <Line tone="error">{BUNDLE_NAME_RULE[line.reason]}</Line>;
    default:
      // 나머지 줄 종류(#56 계약)는 각 실행 이슈(#58~#68)가 정책 원문으로 그린다.
      return null;
  }
}

function Block({ lines, onMoreRequested }: { lines: TerminalLine[]; onMoreRequested?: () => void }) {
  const failed = lines.some((line) => line.kind === "unknownCommand");
  const savedInBlock = lines.some((line) => line.kind === "searchSaved");
  return (
    <div className="gt-block">
      {lines.map((line, index) => (
        <OutputLine key={index} line={line} failed={failed} savedInBlock={savedInBlock} onMoreRequested={onMoreRequested} />
      ))}
    </div>
  );
}

type ReviseFormProps = {
  revising: Revising;
  onSubmit?: (number: number, title: string, summary: string) => void;
  onCancel?: () => void;
};

/**
 * `고치기` 편집(commands 3절 고치기, 화면 W24). 모달 없이 출력 안에 제목·`요약 (직접 고침)` 두 칸을 열고 첫 칸에 초점.
 * Enter 저장, Esc 취소, Tab은 브라우저 기본대로 다음 칸. 고친 값은 저장 전까지 이 칸만 들고 있다.
 */
function ReviseForm({ revising, onSubmit, onCancel }: ReviseFormProps) {
  const [title, setTitle] = useState(revising.title);
  const [summary, setSummary] = useState(revising.summary);
  const titleRef = useRef<HTMLInputElement>(null);
  // 입력줄의 autoFocus가 뒤에 그려져 초점을 가져가므로, 그린 뒤 제목 칸으로 옮긴다.
  useEffect(() => titleRef.current?.focus(), []);

  function handleKeyDown(event: KeyboardEvent<HTMLInputElement>) {
    if (event.key === "Escape") {
      event.preventDefault();
      onCancel?.();
      return;
    }
    // 한글 조합을 끝내는 엔터는 저장이 아니다.
    if (event.key !== "Enter" || event.nativeEvent.isComposing) return;
    event.preventDefault();
    onSubmit?.(revising.number, title, summary);
  }

  return (
    <div className="gt-block gt-revise">
      <Line tone="info">{`고치기 ${revising.number}  ${revising.title}`}</Line>
      <label className="gt-field">
        <span className="gt-hint">제목</span>
        <input
          ref={titleRef}
          className="gt-field-input"
          type="text"
          autoComplete="off"
          spellCheck={false}
          value={title}
          onChange={(event) => setTitle(event.target.value)}
          onKeyDown={handleKeyDown}
        />
      </label>
      <label className="gt-field">
        <span className="gt-hint">요약 (직접 고침)</span>
        <input
          className="gt-field-input"
          type="text"
          autoComplete="off"
          spellCheck={false}
          value={summary}
          onChange={(event) => setSummary(event.target.value)}
          onKeyDown={handleKeyDown}
        />
      </label>
      <Line tone="info">Enter: 저장 · Esc: 취소 · Tab: 다음 칸</Line>
    </div>
  );
}

/** 고친 뒤. 직접 고친 요약에는 ARC-004 규칙 1 이름표를 붙인다(시안 Edit ②). */
function RevisedLines({ item }: { item: ItemSummary }) {
  return (
    <>
      <Line tone="ok">{`고침 ${item.number}번  ${item.title}`}</Line>
      {item.summarySource === "user" && item.listSummary !== null && (
        <Plain dim>{`요약 (직접 고침)  ${item.listSummary}`}</Plain>
      )}
    </>
  );
}

/** 끌어 오는 중 안내(commands 6절, COM-004). */
function DropGuide() {
  return (
    <div className="gt-drop" aria-live="polite">
      <div className="gt-drop-title">놓으면 저장</div>
      <div className="gt-hint">링크 · 글 · 이미지 · PDF · md · docx</div>
    </div>
  );
}

/** 입력줄 바로 위 `선택 3  PDF 25 · 글 12 · example.com 3`(commands 6절 고르기, ARC-003 규칙 14). 선택이 없으면 없다. */
function SelectionLine({ selection }: { selection: PickedRef[] }) {
  if (selection.length === 0) return null;
  return <div className="gt-selection">{`선택 ${selection.length}  ${pickWords(selection)}`}</div>;
}

/** 상태줄 `자료 131 · 선택 2 · 요약 생성 중 1 · 연결 끊김`(commands 6절, ARC-005, COM-010). `묶음` 칸은 그 명령 이슈에서. */
function statusItems(itemCount: number | null, selectionCount: number, processingCount: number, isOffline: boolean): StatusItem[] {
  return [
    { label: "자료", value: itemCount },
    ...(selectionCount > 0 ? [{ label: "선택", value: selectionCount }] : []),
    ...(processingCount > 0 ? [{ label: "요약 생성 중", value: processingCount }] : []),
    ...(isOffline ? [{ label: "연결 끊김", value: null }] : []),
  ];
}

/**
 * 땅굴 두더지에 틀 동작. 코어의 `mole`은 `seq`가 바뀔 때만 다시 틀고(같은 화면을 다시 그려도 반복하지 않게),
 * 끌어 오기 만세와 그침은 뷰가 직접 튼다. 누르기·눈 깜빡임은 `Burrow`가 혼자 한다.
 */
function useMoleCue(action: MoleCue["action"] | undefined, seq: number | undefined) {
  const [cue, setCue] = useState<{ action: MoleAction; key: number }>({ action: "idle", key: 0 });
  const play = (next: MoleAction) => setCue((prev) => ({ action: next, key: prev.key + 1 }));
  useEffect(() => {
    if (action !== undefined) play(action);
    // seq가 바뀔 때만 다시 튼다.
  }, [seq]);
  return { ...cue, play };
}

const carriesFiles =(event: DragEvent) => Array.from(event.dataTransfer?.types ?? []).includes("Files");

export function TerminalScreen({
  itemCount,
  lines,
  input,
  selection,
  processingCount,
  isOffline,
  onInputChange,
  onSubmit,
  onPaste,
  onFilesDrop,
  onMoreRequested,
  revising,
  onReviseSubmit,
  onReviseCancel,
  onSamplesRequest,
  mole,
}: TerminalScreenProps) {
  const [isDragging, setDragging] = useState(false);
  const moleCue = useMoleCue(mole?.action, mole?.seq);
  const inputRef = useRef<HTMLInputElement>(null);
  const isRevising = Boolean(revising);
  const wasRevising = useRef(isRevising);
  // 고치기 칸이 닫히면(저장·취소) 초점이 갈 곳이 없어지므로 입력줄로 돌려놓는다. 닫힐 때만 옮긴다(미리보기 선택 등을 빼앗지 않게).
  useEffect(() => {
    if (wasRevising.current && !isRevising) inputRef.current?.focus();
    wasRevising.current = isRevising;
  }, [isRevising]);
  // 명령 칩·번호는 입력줄에 찍기만 한다(commands 6절, 2026-11-26 PO 결정). 눌린 버튼에 초점이 남으면 엔터가 버튼을 다시 누르므로 입력줄로 돌려보낸다.
  const chips: TerminalChips = {
    insert: (command) => {
      onInputChange(command);
      inputRef.current?.focus();
    },
    selected: new Set(selection.map((ref) => ref.number)),
    requestSamples: onSamplesRequest,
  };

  function handlePaste(event: ClipboardEvent) {
    // 명령을 치던 중이면 보통 붙여 넣기다(검색어 등).
    if (input !== "") return;
    const text = event.clipboardData.getData("text");
    if (text.trim() === "") return;
    event.preventDefault();
    onPaste(text);
  }

  function handleDragOver(event: DragEvent) {
    if (!carriesFiles(event)) return;
    // 기본 동작(브라우저가 파일을 여는 것)을 막아야 drop이 온다.
    event.preventDefault();
    if (!isDragging) moleCue.play("dragover");
    setDragging(true);
  }

  function handleDragLeave(event: DragEvent) {
    // 화면 안의 자식으로 옮겨 가는 것은 떠난 것이 아니다.
    if (event.relatedTarget instanceof Node && event.currentTarget.contains(event.relatedTarget)) return;
    moleCue.play("idle");
    setDragging(false);
  }

  function handleDrop(event: DragEvent) {
    if (!carriesFiles(event)) return;
    event.preventDefault();
    // 저장은 코어가 `mole`로 넘긴다. 그 전까지 만세를 그친다.
    moleCue.play("idle");
    setDragging(false);
    const files = Array.from(event.dataTransfer.files);
    if (files.length > 0) onFilesDrop(files);
  }

  return (
    <div
      className="gt-terminal"
      onPaste={handlePaste}
      onDragEnter={handleDragOver}
      onDragOver={handleDragOver}
      onDragLeave={handleDragLeave}
      onDrop={handleDrop}
    >
      <Window
        title={windowTitle(lines)}
        status={<StatusBar items={statusItems(itemCount, selection.length, processingCount, isOffline)} hint={HELP_HINT} />}
      >
        <ChipContext.Provider value={chips}>
          {/* 첫 화면 줄은 머리를 스스로 그린다. 그 줄이 없으면(자료가 있는 계정) 출력 맨 위에 머리와 자료 건수를 둔다. 출력과 함께 말려 올라간다. */}
          {lines[0]?.kind !== "welcome" && <TerminalIntro itemCount={itemCount} />}
          {toBlocks(lines).map((block, index) => (
            <Block key={index} lines={block} onMoreRequested={onMoreRequested} />
          ))}
          {revising && (
            <ReviseForm key={revising.number} revising={revising} onSubmit={onReviseSubmit} onCancel={onReviseCancel} />
          )}
        </ChipContext.Provider>
        <SelectionLine selection={selection} />
        <DockInput
          inputRef={inputRef}
          value={input}
          placeholder="링크 붙여 넣기 또는 명령"
          onChange={onInputChange}
          onSubmit={onSubmit}
          above={<Burrow action={moleCue.action} actionKey={moleCue.key} label="그렙 두더지. 누르면 땅속으로 들어갔다 나온다" />}
        />
      </Window>
      {isDragging && <DropGuide />}
    </div>
  );
}
