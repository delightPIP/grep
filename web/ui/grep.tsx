// 그렙 디자인 시스템 컴포넌트 중 #31 화면에 쓰는 것. 시안 아티팩트 project/ds/grep/components/bundle.js
// (https://claude.ai/artifact/J6XT7UcSDvuPC2quoSsaRm)의 마크업과 클래스 이름을 그대로 옮겼다.
// 순수 뷰 부품이다. 상태를 갖지 않고 Swift를 모른다.
import type { ChangeEvent, KeyboardEvent, ReactNode } from "react";
import "../styles/grep.css";

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

export function Window({ title, status, children }: { title: string; status: ReactNode; children: ReactNode }) {
  return (
    <section className="gt-window gt-screen-window" aria-label="그렙 터미널">
      <div className="gt-titlebar">
        <span className="gt-titlebar-name">
          <b>그렙</b> — {title}
        </span>
      </div>
      <div className="gt-body" role="log" aria-live="polite">
        {children}
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
};

/** 화면 아래 고정 입력줄(시안 Input dock). */
export function DockInput({ value, placeholder, onChange, onSubmit }: DockInputProps) {
  function handleKeyDown(event: KeyboardEvent<HTMLInputElement>) {
    // 한글 조합을 끝내는 엔터는 제출이 아니다.
    if (event.key !== "Enter" || event.nativeEvent.isComposing) return;
    event.preventDefault();
    onSubmit(value);
  }
  return (
    <div className="gt-block gt-dock">
      <div className="gt-dock-line">
        <div className="gt-input">
          <PromptHead />
          <input
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

// 그렙 두더지 기본 모습(16x16). 시안 bundle.js MOLE.idle, MOLE_PAL.
const MOLE_PALETTE: Record<string, string> = {
  M: "#4a4460", R: "#6a4228", h: "#f5c9a3", m: "#6c6585", o: "#16120f", r: "#8a5a3a", s: "#f2a0a8",
};
const MOLE_IDLE = [
  "................", "................", ".....oooooo.....", "....ommmmmmo....",
  "...ommmmmmmmo...", "...omommmmomo...", "..ommomssmommo..", "..ommmssssmmmo..",
  "..ohhmmmmmmhho..", ".ohhhmmMMmmhhho.", ".ommmmMMMMmmmmo.", "..ommmmmmmmmmo..",
  ".rrommmmmmmmorr.", "rrrRrrrrrrRrrrrr", ".rrrrrRrrrrrrrr.", "................",
];

function moleRects(): ReactNode[] {
  return MOLE_IDLE.flatMap((row, y) => {
    const rects: ReactNode[] = [];
    let x = 0;
    while (x < row.length) {
      const ch = row.charAt(x);
      let width = 1;
      while (x + width < row.length && row.charAt(x + width) === ch) width++;
      if (ch !== ".") {
        rects.push(<rect key={`${y}-${x}`} x={x} y={y} width={width} height={1} fill={MOLE_PALETTE[ch]} />);
      }
      x += width;
    }
    return rects;
  });
}

export function Banner({ lead, tagline }: { lead: string; tagline: string }) {
  return (
    <div className="gt-banner-row">
      <svg className="gt-mascot" viewBox="0 0 16 16" width={64} height={64} shapeRendering="crispEdges" aria-hidden="true">
        {moleRects()}
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
