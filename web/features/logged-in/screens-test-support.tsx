// 탭 화면(배치·보관함·설정) 테스트가 같이 쓰는 렌더 도우미와 자료.
import { act, render, screen, within } from "@testing-library/react";
import { vi } from "vitest";
import type { ArchiveState, ItemDetail, ItemSummary, SettingsState } from "../../support/view-state";
import { LoggedInView, type LoggedInViewProps } from "./view";

export const DEFAULT_WIDTH = window.innerWidth;

export function setWidth(width: number) {
  Object.defineProperty(window, "innerWidth", { configurable: true, value: width });
}

export function resizeTo(width: number) {
  act(() => {
    setWidth(width);
    window.dispatchEvent(new Event("resize"));
  });
}

export function item(number: number, overrides: Partial<ItemSummary> = {}): ItemSummary {
  return {
    number,
    kind: "link",
    title: `자료 ${number}`,
    source: "example.com",
    status: "ready",
    blockedReason: null,
    listSummary: null,
    summarySource: null,
    partialNote: null,
    tags: [],
    matchedIn: null,
    savedAt: "2026-11-26T05:03:00Z",
    ...overrides,
  };
}

export function detail(number: number): ItemDetail {
  return {
    item: item(number),
    url: null,
    handoffSummary: null,
    allTags: [],
    bundles: [],
    bodyLength: null,
    body: null,
    bodyFromImage: false,
    originalUrl: null,
    previewUrl: null,
  };
}

export const ARCHIVE: ArchiveState = {
  groups: [
    { group: "tag", value: "결제", count: 2 },
    { group: "format", value: "link", count: 5 },
    { group: "source", value: "direct", count: 1 },
    { group: "date", value: "today", count: 3 },
  ],
  bundles: [
    { name: "결제", count: 2 },
    { name: "빈묶음", count: 0 },
  ],
  savedSearches: [
    { query: "토스", count: 4 },
    { query: "없는것", count: 0 },
  ],
  filter: { kind: "all" },
  items: [item(7), item(6)],
  hasMore: true,
  status: "idle",
};

export const SETTINGS: SettingsState = {
  account: { authProvider: "github", itemCount: 34 },
  connections: [{ number: 3, client: "Claude", connectedAt: "2026-11-20T01:00:00Z", lastReadAt: null }],
};

export function renderView(state: Partial<LoggedInViewProps> = {}) {
  const callbacks = {
    onInputChange: vi.fn(),
    onSubmit: vi.fn(),
    onPaste: vi.fn(),
    onFilesDrop: vi.fn(),
    onArchiveOpen: vi.fn(),
    onArchiveSelect: vi.fn(),
    onArchiveMore: vi.fn(),
    onSettingsOpen: vi.fn(),
    onThemeChange: vi.fn(),
  };
  const props: LoggedInViewProps = {
    itemCount: 34,
    lines: [],
    input: "",
    selection: [],
    processingCount: 0,
    isOffline: false,
    ...callbacks,
    ...state,
  };
  const result = render(<LoggedInView {...props} />);
  const rerender = (next: Partial<LoggedInViewProps>) => result.rerender(<LoggedInView {...props} {...next} />);
  return { ...callbacks, container: result.container, rerender };
}

export const nav = () => screen.queryByRole("navigation", { name: "화면 이동" });
export const navItem = (name: string) => within(nav()!).getByRole("button", { name: new RegExp(name) });
export const current = () => within(nav()!).getByRole("button", { current: "page" }).textContent;
