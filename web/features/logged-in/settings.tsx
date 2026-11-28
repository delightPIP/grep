// 설정 화면(#168, 시안 26). 계정 · AI 도구 연결(ACC-002) · 휴지통 · 테마(COM-012) · 로그아웃.
// 연결 끊기·휴지통·로그아웃은 있던 명령을 그대로 쓴다. 확인 줄은 터미널에 뜨므로 터미널로 옮겨 실행한다(계약).
import type { ReactNode } from "react";
import type { ConnectionEntry } from "../../support/view-state";
import { Line } from "../../ui/grep";
import type { SettingsState } from "./contract";
import { Plain } from "./terminal";

/** COM-012 테마 세 가지. 저장은 `support/theme-store.ts`(M)가 한다. */
export type ThemeChoice = "system" | "light" | "dark";

/** COM-012 사용자 문구 `시스템 따름` · `밝게` · `어둡게`, 이 차례. */
const THEME_OPTIONS: ReadonlyArray<readonly [ThemeChoice, string]> = [
  ["system", "시스템 따름"],
  ["light", "밝게"],
  ["dark", "어둡게"],
];

const PROVIDER_LABEL = { google: "Google", github: "GitHub" } as const;

/** 한국 날짜 `MM/DD`. 터미널 `연결` 목록과 같은 표기(ACC-002 규칙 7). */
const DAY_FORMAT = new Intl.DateTimeFormat("en-US", { timeZone: "Asia/Seoul", month: "2-digit", day: "2-digit" });
const day = (iso: string) => DAY_FORMAT.format(new Date(iso));

function SettingRow({ label, sub, children }: { label: string; sub?: string; children?: ReactNode }) {
  return (
    <div className="gt-setting-row">
      <div className="gt-setting-text">
        <div>{label}</div>
        {sub && <div className="gt-hint">{sub}</div>}
      </div>
      {children && <div className="gt-setting-action">{children}</div>}
    </div>
  );
}

function Group({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section className="gt-setting-group" aria-label={title}>
      <h2 className="gt-setting-title">{title}</h2>
      {children}
    </section>
  );
}

function ActionButton({ label, danger = false, onPress }: { label: string; danger?: boolean; onPress: () => void }) {
  return (
    <button type="button" className={danger ? "gt-button gt-button-danger" : "gt-button"} onClick={onPress}>
      {label}
    </button>
  );
}

function ConnectionRow({ connection, onRun }: { connection: ConnectionEntry; onRun: (command: string) => void }) {
  const read = connection.lastReadAt === null ? "" : `  읽음 ${day(connection.lastReadAt)}`;
  return (
    <SettingRow label={connection.client} sub={`연결 ${day(connection.connectedAt)}${read}`}>
      <ActionButton label="끊기" onPress={() => onRun(`연결 끊기 ${connection.number}`)} />
    </SettingRow>
  );
}

export function ThemeRow({ theme, onChange }: { theme: ThemeChoice; onChange?: (theme: ThemeChoice) => void }) {
  return (
    <SettingRow label="테마">
      <div className="gt-segmented" role="radiogroup" aria-label="테마">
        {THEME_OPTIONS.map(([value, label]) => (
          <button
            key={value}
            type="button"
            role="radio"
            aria-checked={theme === value}
            className="gt-segment"
            onClick={() => onChange?.(value)}
          >
            {label}
          </button>
        ))}
      </div>
    </SettingRow>
  );
}

export type SettingsScreenProps = {
  settings: SettingsState | null | undefined;
  theme: ThemeChoice;
  onThemeChange?: (theme: ThemeChoice) => void;
  /** 명령을 터미널로 옮겨 실행한다(확인 줄이 터미널에 뜬다). */
  onRun: (command: string) => void;
};

/** shortcut: 줄 이름·설명 낱말은 iOS 설정 탭 문구를 따랐다(시안 26). 정책 문구가 생기면 바꾼다. */
export function SettingsScreen({ settings, theme, onThemeChange, onRun }: SettingsScreenProps) {
  const account = settings?.account ?? null;
  const connections = settings?.connections ?? [];
  return (
    <div className="gt-settings" aria-label="설정" role="region">
      <Group title="계정">
        {account === null ? (
          <Plain dim>· 불러오는 중</Plain>
        ) : (
          <SettingRow label={`${PROVIDER_LABEL[account.authProvider]} 계정`} sub={`자료 ${account.itemCount}`} />
        )}
      </Group>
      <Group title="AI 도구 연결">
        {settings && connections.length === 0 && <Line tone="info">연결 0개</Line>}
        {connections.map((connection) => (
          <ConnectionRow key={connection.number} connection={connection} onRun={onRun} />
        ))}
        <SettingRow label="연결 주소" sub="AI 도구의 연결(MCP) 설정에 넣는 주소">
          <ActionButton label="보기" onPress={() => onRun("연결")} />
        </SettingRow>
      </Group>
      <Group title="휴지통">
        <SettingRow label="휴지통" sub="30일 뒤 영구 삭제">
          <ActionButton label="열기" onPress={() => onRun("휴지통")} />
        </SettingRow>
      </Group>
      <Group title="화면">
        <ThemeRow theme={theme} onChange={onThemeChange} />
      </Group>
      <Group title="로그아웃">
        <SettingRow label="이 기기 로그아웃" sub="이 기기의 터미널 기록도 지움">
          <ActionButton label="로그아웃" onPress={() => onRun("로그아웃")} />
        </SettingRow>
        <SettingRow label="모든 기기 로그아웃" sub="AI 도구 연결도 끊김">
          <ActionButton label="모든 기기" danger onPress={() => onRun("로그아웃 모든기기")} />
        </SettingRow>
      </Group>
    </div>
  );
}
