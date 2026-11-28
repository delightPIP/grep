// COM-011·MOB-001 이동 줄. 사이드바(1008px 이상)·아이콘 레일(600~1007px)·하단 탭(600px 미만).
// 이동에만 쓰고 배지를 달지 않는다(COM-011 규칙 4).
import type { ReactNode } from "react";
import type { Layout, Tab } from "./layout";

/** COM-011 사용자 문구. 이 차례다(규칙 4). */
export const TABS: ReadonlyArray<{ tab: Tab; label: string; icon: string }> = [
  { tab: "terminal", label: "터미널", icon: ">_" },
  { tab: "archive", label: "보관함", icon: "▤" },
  { tab: "settings", label: "설정", icon: "⚙" },
];

type NavProps = {
  layout: Layout;
  current: Tab;
  onSelect: (tab: Tab) => void;
  /** 사이드바의 보관함 구역(묶음·저장한 찾기·자동 묶음). 레일·탭에는 없다. */
  archiveSections?: ReactNode;
};

const NAV_CLASS: Record<Layout, string> = { sidebar: "gt-nav gt-sidebar", rail: "gt-nav gt-rail", tabs: "gt-nav gt-tabbar" };

export function Nav({ layout, current, onSelect, archiveSections }: NavProps) {
  return (
    <nav className={NAV_CLASS[layout]} aria-label="화면 이동">
      <ul className="gt-nav-list">
        {TABS.map(({ tab, label, icon }) => (
          <li key={tab}>
            <button
              type="button"
              className="gt-nav-item"
              aria-current={tab === current ? "page" : undefined}
              onClick={() => onSelect(tab)}
            >
              <span className="gt-nav-icon" aria-hidden="true">
                {icon}
              </span>
              <span className="gt-nav-label">{label}</span>
            </button>
            {tab === "archive" && layout === "sidebar" && archiveSections}
          </li>
        ))}
      </ul>
    </nav>
  );
}
