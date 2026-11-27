// 터미널 화면. 순수 뷰: 받은 상태만 그리고, 입력은 onInputChange·onSubmit·onPaste·onFilesDrop으로만 알린다.
// 배치는 시안 Main·Errors·Logout ③ 아트보드, 출력 비우기(로그아웃·다른 계정 로그인, COM-009)는 코어가 lines로 내려준다.
import { useState, type ClipboardEvent, type DragEvent, type ReactNode } from "react";
import type { ItemSummary, LoggedInState, SaveFailure, SaveRecovery, TerminalLine } from "../../support/view-state";
import { DockInput, Line, Prompt, StatusBar, Window } from "../../ui/grep";

export type LoggedInViewProps = LoggedInState & {
  onInputChange: (text: string) => void;
  onSubmit: (text: string) => void;
  /** 입력줄이 빈 채로 붙여 넣었다. 붙여 넣기만 해도 저장한다(commands 3절 담기). */
  onPaste: (text: string) => void;
  /** 화면에 파일을 끌어다 놓았다. */
  onFilesDrop: (files: File[]) => void;
};

const HELP_HINT = { key: "?", label: "도움말" };
/** commands 6절 글 저장: `<첫 줄, 24자까지>` */
const TEXT_TITLE_LIMIT = 24;
const BYTES_PER_MB = 1024 * 1024;

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
      {/* shortcut: 번호·제목·출처만. 저장 시각·태그를 넣은 목록 행은 #60 `최근`에서 함께 만든다. */}
      <Plain>{`${item.number}  ${withSource(item)}`}</Plain>
      <Plain>→ 고르기 {item.number}</Plain>
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

function OutputLine({ line, failed }: { line: TerminalLine; failed: boolean }) {
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
      return line.command === "keep" ? <Line tone="error">저장할 것 없음  예: 담기 https://…</Line> : null;
    case "saved":
      return <SavedLines item={line.item} />;
    case "alreadySaved":
      return <AlreadySavedLines item={line.item} />;
    case "inTrash":
      return <Line tone="warn">{`휴지통에 있음 → ${line.number}번. 되살리기 ${line.number}`}</Line>;
    case "saveFailed":
      return <SaveFailedLines reason={line.reason} recovery={line.recovery} />;
    default:
      // 나머지 줄 종류(#56 계약)는 각 실행 이슈(#58~#68)가 정책 원문으로 그린다.
      return null;
  }
}

function Block({ lines }: { lines: TerminalLine[] }) {
  const failed = lines.some((line) => line.kind === "unknownCommand");
  return (
    <div className="gt-block">
      {lines.map((line, index) => (
        <OutputLine key={index} line={line} failed={failed} />
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

const carriesFiles = (event: DragEvent) => Array.from(event.dataTransfer?.types ?? []).includes("Files");

export function LoggedInView({
  itemCount,
  lines,
  input,
  onInputChange,
  onSubmit,
  onPaste,
  onFilesDrop,
}: LoggedInViewProps) {
  const [isDragging, setDragging] = useState(false);

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
        status={<StatusBar items={[{ label: "자료", value: itemCount }]} hint={HELP_HINT} />}
      >
        {toBlocks(lines).map((block, index) => (
          <Block key={index} lines={block} />
        ))}
        <DockInput
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
