// 로그인 뒤 화면. 폭에 따라 사이드바·아이콘 레일·하단 탭으로 터미널·보관함·설정을 오간다(COM-011, MOB-001).
// 순수 뷰: 받은 상태만 그린다. 탭·폭·자세히 보기 칸은 뷰 상태이고, 세 화면은 늘 붙여 둬 폭·탭이 바뀌어도 상태가 남는다.
import { useState } from "react";
import type { TerminalLine } from "../../support/view-state";
import { ArchiveScreen, ArchiveSections } from "./archive";
import type { ArchiveFilter, LoggedInStateWithScreens } from "./contract";
import { useLayout, type Tab } from "./layout";
import { Nav } from "./nav";
import { SettingsScreen, type ThemeChoice } from "./settings";
import { TerminalScreen, type TerminalScreenProps } from "./terminal";

export type { ThemeChoice } from "./settings";

export type LoggedInViewProps = Omit<TerminalScreenProps, "selection"> &
  LoggedInStateWithScreens & {
    /**
     * 보관함·설정을 열었다, 보관함 구역을 골랐다, 보관함 `더 보기`(계약 `archiveOpen`·`archiveSelect`·`archiveMore`·`settingsOpen`).
     * shortcut: 선택 속성. 어댑터가 handle로 이으면(통합) 필수로 바꾼다.
     */
    onArchiveOpen?: () => void;
    onArchiveSelect?: (filter: ArchiveFilter) => void;
    onArchiveMore?: () => void;
    onSettingsOpen?: () => void;
    /** COM-012 고른 테마. 없으면 시스템 따름. 저장은 `support/theme-store.ts`(M). */
    theme?: ThemeChoice;
    onThemeChange?: (theme: ThemeChoice) => void;
  };

/** 확인 줄이 떠 있다(답을 기다림). 하단 탭을 숨긴다(MOB-001 규칙 4). */
const CONFIRM_KINDS: ReadonlySet<TerminalLine["kind"]> = new Set([
  "handoffConfirm",
  "dropConfirm",
  "binEmptyConfirm",
  "signOutEverywhereConfirm",
  "bundleDeleteConfirm",
  "savedSearchDeleteConfirm",
  "disconnectConfirm",
]);

/** 화면 키보드가 올라오는 기기. 마우스 기기의 좁은 창은 입력줄에 늘 초점이 있으므로 탭을 숨기지 않는다. */
const isTouchDevice = () => typeof window.matchMedia === "function" && window.matchMedia("(pointer: coarse)").matches;

export function LoggedInView(props: LoggedInViewProps) {
  const {
    archive,
    settings,
    lines,
    input,
    selection,
    revising,
    theme = "system",
    onSubmit,
    onInputChange,
    onArchiveOpen,
    onArchiveSelect,
    onArchiveMore,
    onSettingsOpen,
    onThemeChange,
  } = props;
  const layout = useLayout();
  // COM-011 규칙 6: 늘 터미널에서 시작한다.
  const [tab, setTab] = useState<Tab>("terminal");
  const [isTyping, setTyping] = useState(false);
  // 보관함·설정은 처음 열 때 붙이고, 그 뒤로는 떼지 않는다(보던 위치가 남게).
  const [opened, setOpened] = useState<ReadonlySet<Tab>>(() => new Set(["terminal"]));

  function show(next: Tab) {
    setTab(next);
    setOpened((prev) => (prev.has(next) ? prev : new Set([...prev, next])));
  }

  function select(next: Tab) {
    show(next);
    if (next === "archive" && !archive) onArchiveOpen?.();
    if (next === "settings") onSettingsOpen?.();
  }

  function selectFilter(filter: ArchiveFilter) {
    show("archive");
    onArchiveSelect?.(filter);
  }

  // 다른 화면에서 실행한 명령이 치던 글을 지우지 않게 되돌린다(COM-011 규칙 5).
  function run(command: string) {
    onSubmit(command);
    if (input !== "") onInputChange(input);
  }

  function runInTerminal(command: string) {
    setTab("terminal");
    run(command);
  }

  function insertInTerminal(command: string) {
    setTab("terminal");
    onInputChange(command);
  }

  const lastLine = lines[lines.length - 1];
  const isAsking = lastLine !== undefined && CONFIRM_KINDS.has(lastLine.kind);
  // MOB-001 규칙 4: 입력 중(화면 키보드)·확인 줄·고르기 중(선택 줄)·고치기 칸에는 하단 탭을 숨긴다.
  const hidesTabs = tab === "terminal" && (isTyping || isAsking || selection.length > 0 || Boolean(revising));
  const nav = (
    <Nav
      layout={layout}
      current={tab}
      onSelect={select}
      archiveSections={<ArchiveSections archive={archive} onSelect={selectFilter} />}
    />
  );

  return (
    <main className={`gt-screen gt-shell gt-shell-${layout}`}>
      {layout !== "tabs" && nav}
      <div className="gt-shell-content">
        <div
          className="gt-pane"
          hidden={tab !== "terminal"}
          onFocus={(event) => setTyping(event.target instanceof HTMLInputElement && isTouchDevice())}
          onBlur={() => setTyping(false)}
        >
          <TerminalScreen {...props} />
        </div>
        {opened.has("archive") && (
          <div className="gt-pane" hidden={tab !== "archive"}>
            <ArchiveScreen
              layout={layout}
              archive={archive}
              lines={lines}
              selection={selection}
              onRun={run}
              onInsert={insertInTerminal}
              onSelect={selectFilter}
              onMore={() => onArchiveMore?.()}
            />
          </div>
        )}
        {opened.has("settings") && (
          <div className="gt-pane" hidden={tab !== "settings"}>
            <SettingsScreen settings={settings} theme={theme} onThemeChange={onThemeChange} onRun={runInTerminal} />
          </div>
        )}
      </div>
      {layout === "tabs" && !hidesTabs && nav}
    </main>
  );
}
