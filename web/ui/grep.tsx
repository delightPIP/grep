// 그렙 디자인 시스템 컴포넌트 중 #31 화면에 쓰는 것. 시안 아티팩트 project/ds/grep/components/bundle.js
// (https://claude.ai/artifact/J6XT7UcSDvuPC2quoSsaRm)의 마크업과 클래스 이름을 그대로 옮겼다.
// 순수 뷰 부품이다. 상태를 갖지 않고 Swift를 모른다.
import { useEffect, useLayoutEffect, useRef, type ChangeEvent, type KeyboardEvent, type ReactNode, type Ref } from "react";
import "../styles/grep.css";
import { pixelRects } from "./burrow";

export type Tone = "ok" | "info" | "warn" | "error";

const SYMBOL: Record<Tone, string> = { ok: "✓", info: "·", warn: "!", error: "✗" };

/** 첫 단어(와 `|` 뒤 첫 단어)를 명령 이름 색으로 칠한다. */
function paint(cmd: string): ReactNode[] {
  return cmd.split("|").flatMap((part, index) => {
    const pipe = index > 0 ? [<span key={`p${index}`} className="gt-pipe">|</span>] : [];
    const match = /^(\s*)(\S+)([\s\S]*)$/.exec(part);
    if (!match) return [...pipe, part];
    return [
      ...pipe,
      match[1],
      <span key={`v${index}`} className="gt-verb">{match[2]}</span>,
      match[3],
    ];
  });
}

export type StatusItem = { label: string; value: number | null };

export function StatusBar({ items, hint }: { items: StatusItem[]; hint?: { key: string; label: string } }) {
  return (
    <footer className="gt-status">
      {items.map((item, index) => (
        <span key={item.label}>
          {index > 0 && <span className="gt-status-sep" aria-hidden="true">· </span>}
          {item.label}
          {item.value !== null && <> <b>{item.value}</b></>}
        </span>
      ))}
      {hint && (
        <span className="gt-status-right">
          <kbd className="gt-key">{hint.key}</kbd> {hint.label}
        </span>
      )}
    </footer>
  );
}

/** 맨 아래로 본다고 칠 남은 거리(px). */
const BOTTOM_SLACK_PX = 4;

export type WindowProps = {
  title: string;
  status: ReactNode;
  children: ReactNode;
  /** 출력 끝에 붙는 자리(선택 줄·땅굴·입력줄). 실제 터미널처럼 출력과 함께 스크롤되어, 위로 올리면 함께 사라진다. */
  dock?: ReactNode;
  /** 바뀌면 출력 칸을 맨 아래로 내린다(새 출력이 보이게). 입력만 바뀔 때는 그대로 둔다. */
  scrollKey?: number;
};

export function Window({ title, status, children, dock, scrollKey }: WindowProps) {
  const bodyRef = useRef<HTMLDivElement>(null);
  // 맨 아래를 보고 있으면 그 자리에 붙여 둔다. 아래 자리(선택 줄·땅굴)가 커져 출력 칸이 줄거나, 줄이 뒤늦게 그려져도 마지막 줄이 잘리지 않게.
  const stickToBottom = useRef(true);
  const followsOutput = scrollKey !== undefined;
  useLayoutEffect(() => {
    const body = bodyRef.current;
    if (scrollKey === undefined || !body) return;
    stickToBottom.current = true;
    body.scrollTop = body.scrollHeight;
  }, [scrollKey]);
  useEffect(() => {
    const body = bodyRef.current;
    if (!followsOutput || !body) return;
    const follow = () => {
      if (stickToBottom.current) body.scrollTop = body.scrollHeight;
    };
    const onScroll = () => {
      stickToBottom.current = body.scrollHeight - body.scrollTop - body.clientHeight <= BOTTOM_SLACK_PX;
    };
    body.addEventListener("scroll", onScroll, { passive: true });
    const resize = typeof ResizeObserver === "undefined" ? null : new ResizeObserver(follow);
    resize?.observe(body);
    const mutation = new MutationObserver(follow);
    mutation.observe(body, { childList: true, subtree: true, characterData: true });
    return () => {
      body.removeEventListener("scroll", onScroll);
      resize?.disconnect();
      mutation.disconnect();
    };
  }, [followsOutput]);
  return (
    <section className="gt-window gt-screen-window" aria-label="그렙 터미널">
      <div className="gt-titlebar">
        <span className="gt-titlebar-name">
          <b>그렙</b> — {title}
        </span>
      </div>
      <div ref={bodyRef} className="gt-body" role="log" aria-live="polite">
        {children}
        {dock}
      </div>
      {status}
    </section>
  );
}

function PromptHead() {
  return (
    <span className="gt-prompt-head">
      그렙 <span className="gt-prompt-path">~</span> $
    </span>
  );
}

export function Prompt({ cmd, failed = false }: { cmd: string; failed?: boolean }) {
  return (
    <div className={failed ? "gt-prompt gt-prompt-fail" : "gt-prompt"}>
      <PromptHead />
      <span className="gt-prompt-cmd">{paint(cmd)}</span>
    </div>
  );
}

export function Line({ tone, children }: { tone: Tone; children: ReactNode }) {
  return (
    <div className={`gt-line gt-${tone}`} role={tone === "info" ? undefined : "status"}>
      <span className="gt-line-sym" aria-hidden="true">{SYMBOL[tone]}</span>
      <span className="gt-line-text">{children}</span>
    </div>
  );
}

export function Hint({ children }: { children: ReactNode }) {
  return <div className="gt-hint">{children}</div>;
}

export type DockInputProps = {
  value: string;
  placeholder: string;
  onChange: (text: string) => void;
  onSubmit: (text: string) => void;
  /** 칩을 눌러 명령을 찍은 뒤 입력줄로 돌아올 때 쓴다(엔터로 실행). */
  inputRef?: Ref<HTMLInputElement>;
  /** 입력줄 바로 위, 입력줄과 함께 화면 아래에 붙는 것(땅굴 두더지). */
  above?: ReactNode;
};

/** 화면 아래 고정 입력줄(시안 Input dock). */
export function DockInput({ value, placeholder, onChange, onSubmit, inputRef, above }: DockInputProps) {
  function handleKeyDown(event: KeyboardEvent<HTMLInputElement>) {
    // 한글 조합을 끝내는 엔터는 제출이 아니다.
    if (event.key !== "Enter" || event.nativeEvent.isComposing) return;
    event.preventDefault();
    onSubmit(value);
  }
  return (
    <div className="gt-block gt-dock">
      {above}
      <div className="gt-dock-line">
        <div className="gt-input">
          <PromptHead />
          <input
            ref={inputRef}
            className="gt-input-field"
            type="text"
            aria-label="명령 입력"
            placeholder={placeholder}
            autoComplete="off"
            spellCheck={false}
            autoFocus
            value={value}
            onChange={(event: ChangeEvent<HTMLInputElement>) => onChange(event.target.value)}
            onKeyDown={handleKeyDown}
          />
        </div>
      </div>
    </div>
  );
}

// 그렙 두더지 기본 모습(16x16). 시안 bundle.js MOLE.idle.
const MOLE_IDLE = [
  "................", "................", ".....oooooo.....", "....ommmmmmo....",
  "...ommmmmmmmo...", "...omommmmomo...", "..ommomssmommo..", "..ommmssssmmmo..",
  "..ohhmmmmmmhho..", ".ohhhmmMMmmhhho.", ".ommmmMMMMmmmmo.", "..ommmmmmmmmmo..",
  ".rrommmmmmmmorr.", "rrrRrrrrrrRrrrrr", ".rrrrrRrrrrrrrr.", "................",
];

export function Banner({ lead, tagline }: { lead: string; tagline: string }) {
  return (
    <div className="gt-banner-row">
      <svg className="gt-mascot" viewBox="0 0 16 16" width={64} height={64} shapeRendering="crispEdges" aria-hidden="true">
        {pixelRects(MOLE_IDLE)}
      </svg>
      <div className="gt-banner">
        그렙 ~ $<span className="gt-banner-lead">{lead}</span>
        <span>{tagline}</span>
      </div>
    </div>
  );
}

/** 시안 UiButton kind=secondary size=md. */
export function SecondaryButton({ label, disabled, onPress }: { label: string; disabled: boolean; onPress: () => void }) {
  return (
    <button type="button" className="gt-button" disabled={disabled} onClick={onPress}>
      {label}
    </button>
  );
}
