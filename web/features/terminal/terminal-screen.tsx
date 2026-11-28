// 터미널 화면(배치는 view.tsx가 감싼다). 순수 뷰: 받은 상태만 그리고, 입력은 onInputChange·onSubmit·onPaste·onFilesDrop으로만 알린다.
// 배치는 시안 Main·Errors·Logout ③ 아트보드, 출력 비우기(로그아웃·다른 계정 로그인, COM-009)는 코어가 lines로 내려준다.
import { type ClipboardEvent, type DragEvent, useEffect, useRef, useState } from "react";
import { pickWords } from "../logged-in/pick-word";
import { Block } from "./block";
import { windowTitle } from "./format/title";
import { TerminalIntro } from "./lines/guide";
import { ChipContext, type TerminalChips } from "./parts";
import { ReviseForm } from "./revise-form";
import type { ItemRef, LoggedInState, MoleCue, TerminalLine } from "../../support/view-state";
import { Burrow, type MoleAction } from "../../ui/burrow";
import { DockInput, StatusBar, type StatusItem, Window } from "../../ui/grep";

export type TerminalScreenProps = Omit<LoggedInState, "selection"> & {
  /** 고른 자료. #179 kind·source가 오면 선택 줄에 종류 낱말로 쓴다. */
  selection: ItemRef[];
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

/** 명령 한 번 = 블록 하나(디자인 시스템 1절 원칙 2). 입력줄(prompt)마다 새 블록을 연다. */
function toBlocks(lines: TerminalLine[]): TerminalLine[][] {
  const blocks: TerminalLine[][] = [];
  for (const line of lines) {
    if (line.kind === "prompt" || blocks.length === 0) blocks.push([line]);
    else blocks[blocks.length - 1].push(line);
  }
  return blocks;
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
function SelectionLine({ selection }: { selection: ItemRef[] }) {
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
        scrollKey={lines.length}
        dock={
          <>
            <SelectionLine selection={selection} />
            <DockInput
              inputRef={inputRef}
              value={input}
              placeholder="링크 붙여 넣기 또는 명령"
              onChange={onInputChange}
              onSubmit={onSubmit}
              above={<Burrow action={moleCue.action} actionKey={moleCue.key} label="그렙 두더지. 누르면 땅속으로 들어갔다 나온다" />}
            />
          </>
        }
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
      </Window>
      {isDragging && <DropGuide />}
    </div>
  );
}
