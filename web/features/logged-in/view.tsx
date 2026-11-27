// 터미널 화면. 순수 뷰: 받은 상태만 그리고, 입력은 onInputChange·onSubmit·onPaste·onFilesDrop으로만 알린다.
// 배치는 시안 Main·Errors·Logout ③ 아트보드, 출력 비우기(로그아웃·다른 계정 로그인, COM-009)는 코어가 lines로 내려준다.
import { createContext, useContext, useRef, useState, type ClipboardEvent, type DragEvent, type ReactNode } from "react";
import type {
  CommandFailure,
  CommandName,
  ItemRef,
  ItemSummary,
  LoggedInState,
  SaveFailure,
  SaveRecovery,
  SearchQuery,
  TerminalLine,
} from "../../support/view-state";
import { DockInput, Line, Prompt, StatusBar, Window, type StatusItem } from "../../ui/grep";

export type LoggedInViewProps = LoggedInState & {
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
type TerminalChips = { insert: (command: string) => void; selected: ReadonlySet<number> };
const ChipContext = createContext<TerminalChips>({ insert: () => {}, selected: new Set() });

/** 명령 칩. 누르면 입력줄에 찍힌다. 화면 칩(`더 보기`·`펼치기`)과 달리 바로 실행하지 않는다. */
function CommandChip({ command, children }: { command: string; children?: ReactNode }) {
  const { insert } = useContext(ChipContext);
  return (
    <button type="button" className="gt-chip" onClick={() => insert(command)}>
      {children ?? command}
    </button>
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
function Plain({ dim = false, children }: { dim?: boolean; children: ReactNode }) {
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

function ListRow({ item }: { item: ItemSummary }) {
  const tags = item.tags.slice(0, LIST_TAG_LIMIT);
  const summary = rowSummary(item);
  const match = item.matchedIn === null ? undefined : MATCH_LABEL[item.matchedIn];
  const { insert, selected } = useContext(ChipContext);
  return (
    <>
      <div className="gt-line gt-row">
        <span className="gt-row-num">
          {selected.has(item.number) && <span aria-label="선택됨">▸</span>}
          {/* 번호를 누르면 `고르기 <번호>`가 입력줄에 찍힌다(commands 6절). */}
          <button type="button" className="gt-num-chip" onClick={() => insert(`고르기 ${item.number}`)}>
            {item.number}
          </button>
        </span>
        <span>{item.kind === "text" ? textTitle(item.title) : item.title}</span>
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

function ListLines({ items, hasMore, onMoreRequested }: { items: ItemSummary[]; hasMore: boolean; onMoreRequested?: () => void }) {
  return (
    <>
      {items.map((item) => (
        <ListRow key={item.number} item={item} />
      ))}
      {hasMore && (
        <Plain>
          {"→ "}
          <button type="button" className="gt-chip" onClick={onMoreRequested}>
            더 보기
          </button>
        </Plain>
      )}
    </>
  );
}

/** 찾기 머리줄 `4건`, 다음 쪽이 남으면 `23건 중 10건`. 머리 숫자는 보인 행 수와 맞춘다(commands 6절 더 보기). */
function searchHeader(total: number, shown: number): string {
  return shown < total ? `${total}건 중 ${shown}건` : `${total}건`;
}

type SearchResultLinesProps = { total: number; items: ItemSummary[]; hasMore: boolean; onMoreRequested?: () => void };

function SearchResultLines({ total, items, hasMore, onMoreRequested }: SearchResultLinesProps) {
  return (
    <>
      <Plain>{searchHeader(total, items.length)}</Plain>
      <ListLines items={items} hasMore={hasMore} onMoreRequested={onMoreRequested} />
    </>
  );
}

/** 0건 뒤 최근 자료는 검색 결과처럼 읽히지 않게 머리줄을 단다(commands 6절, ARC-002 사용자 문구). */
function NoResultsLines({ query, recent }: { query: SearchQuery; recent: ItemSummary[] }) {
  return (
    <>
      <Line tone="info">{`0건: "${query.text}"`}</Line>
      {recent.length > 0 && <Line tone="info">{`최근 저장 ${recent.length}건 (검색 결과 아님)`}</Line>}
      <ListLines items={recent} hasMore={false} />
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
        {/* shortcut: `묶음`은 데모 범위 명령이 아니어서 칩 대신 글자로만 둔다. 묶음이 들어오면 칩으로. */}
        {" 또는 묶음 <이름>"}
      </Plain>
    </>
  );
}

type OutputLineProps ={ line: TerminalLine; failed: boolean; onMoreRequested?: () => void };

function OutputLine({ line, failed, onMoreRequested }: OutputLineProps) {
  switch (line.kind) {
    case "prompt":
      return <Prompt cmd={line.text} failed={failed} />;
    case "unknownCommand":
      return (
        <Line tone="error">
          <b>없는 명령:</b> {line.name}
        </Line>
      );
    case "missingArgument":
      // 다른 명령의 빠진 인자 문구는 그 명령의 실행 이슈에서 더한다.
      if (line.command === "keep") return <Line tone="error">저장할 것 없음  예: 담기 https://…</Line>;
      // commands 6절 "빠진 인자".
      if (line.command === "seek") return <Line tone="error">검색어 없음  예: 찾기 결제</Line>;
      // ARC-001 사용자 문구.
      if (line.command === "pick") return <Line tone="error">번호 없음  예: 고르기 131</Line>;
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
    case "recentList":
      return <ListLines items={line.items} hasMore={line.hasMore} onMoreRequested={onMoreRequested} />;
    case "searchResult":
      return (
        <SearchResultLines total={line.total} items={line.items} hasMore={line.hasMore} onMoreRequested={onMoreRequested} />
      );
    case "noResults":
      return <NoResultsLines query={line.query} recent={line.recent} />;
    case "picked":
      return <PickedLines items={line.items} />;
    case "notFound":
      return <Line tone="error">{`없는 번호: ${line.numbers.join(", ")}`}</Line>;
    case "invalidNumber":
      return <Line tone="error">{`잘못된 번호: ${line.input}  예: ${PICK_EXAMPLE}`}</Line>;
    case "commandFailed":
      return <CommandFailedLines command={line.command} reason={line.reason} retry={line.retry} />;
    case "reconnected":
      return <Line tone="ok">연결됨</Line>;
    default:
      // 나머지 줄 종류(#56 계약)는 각 실행 이슈(#58~#68)가 정책 원문으로 그린다.
      return null;
  }
}

function Block({ lines, onMoreRequested }: { lines: TerminalLine[]; onMoreRequested?: () => void }) {
  const failed = lines.some((line) => line.kind === "unknownCommand");
  return (
    <div className="gt-block">
      {lines.map((line, index) => (
        <OutputLine key={index} line={line} failed={failed} onMoreRequested={onMoreRequested} />
      ))}
    </div>
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

/** 입력줄 바로 위 `선택 2  <제목> · <제목>`(commands 6절 고르기). 선택이 없으면 없다. */
function SelectionLine({ selection }: { selection: ItemRef[] }) {
  if (selection.length === 0) return null;
  return <div className="gt-selection">{`선택 ${selection.length}  ${titles(selection)}`}</div>;
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

const carriesFiles =(event: DragEvent) => Array.from(event.dataTransfer?.types ?? []).includes("Files");

export function LoggedInView({
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
}: LoggedInViewProps) {
  const [isDragging, setDragging] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);
  // 명령 칩·번호는 입력줄에 찍기만 한다(commands 6절, 2026-11-26 PO 결정). 눌린 버튼에 초점이 남으면 엔터가 버튼을 다시 누르므로 입력줄로 돌려보낸다.
  const chips: TerminalChips = {
    insert: (command) => {
      onInputChange(command);
      inputRef.current?.focus();
    },
    selected: new Set(selection.map((ref) => ref.number)),
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
    setDragging(true);
  }

  function handleDragLeave(event: DragEvent) {
    // 화면 안의 자식으로 옮겨 가는 것은 떠난 것이 아니다.
    if (event.relatedTarget instanceof Node && event.currentTarget.contains(event.relatedTarget)) return;
    setDragging(false);
  }

  function handleDrop(event: DragEvent) {
    if (!carriesFiles(event)) return;
    event.preventDefault();
    setDragging(false);
    const files = Array.from(event.dataTransfer.files);
    if (files.length > 0) onFilesDrop(files);
  }

  return (
    <main
      className="gt-screen"
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
          {toBlocks(lines).map((block, index) => (
            <Block key={index} lines={block} onMoreRequested={onMoreRequested} />
          ))}
        </ChipContext.Provider>
        <SelectionLine selection={selection} />
        <DockInput
          inputRef={inputRef}
          value={input}
          placeholder="링크 붙여 넣기 또는 명령"
          onChange={onInputChange}
          onSubmit={onSubmit}
        />
      </Window>
      {isDragging && <DropGuide />}
    </main>
  );
}
