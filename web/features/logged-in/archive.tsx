// 보관함 화면(#168, ARC-007·ARC-011, 시안 10·28). 순수 뷰: archive 상태만 그리고 동작은 콜백·명령으로만 알린다.
// 자료 열기(`열기 N`)·고르기(`고르기 N`)는 있던 명령을 그대로 쓴다(계약).
import { useState, type ReactNode } from "react";
import type { ItemDetail, ItemRef, TerminalLine } from "../../support/view-state";
import { Line } from "../../ui/grep";
import type { ArchiveFilter, ArchiveState, AutoGroup, AutoGroupEntry } from "../../support/view-state";
import type { Layout } from "./layout";
import { ChipContext, ItemDetailLines, ListRow, MoreChip, Plain, type TerminalChips } from "./terminal";

/** ARC-007 값의 낱말. 형식·날짜는 정책 값 그대로, 출처의 `direct`는 "직접 넣음". */
const FORMAT_LABEL: Record<string, string> = { link: "링크", text: "글", image: "이미지", file: "파일" };
const DATE_LABEL: Record<string, string> = { today: "오늘", week: "이번 주", month: "이번 달", earlier: "그 전" };
/** 태그 묶음 이름표는 ARC-004 `태그 (AI 추정)`. */
const GROUP_TITLE: Record<AutoGroup, string> = { format: "형식", source: "출처", date: "날짜", tag: "태그 (AI 추정)" };
const GROUP_ORDER: readonly AutoGroup[] = ["format", "source", "date", "tag"];

export function autoGroupLabel({ group, value }: Pick<AutoGroupEntry, "group" | "value">): string {
  if (group === "format") return FORMAT_LABEL[value] ?? value;
  if (group === "date") return DATE_LABEL[value] ?? value;
  if (group === "source") return value === "direct" ? "직접 넣음" : value;
  return `#${value}`;
}

/** 목록 머리 이름. shortcut: `전체`는 정책에 문구가 없어 AI 제안이다. PO 확인 때 바꾼다. */
function filterTitle(filter: ArchiveFilter): string {
  switch (filter.kind) {
    case "all":
      return "전체";
    case "auto":
      return `${GROUP_TITLE[filter.group]} · ${autoGroupLabel(filter)}`;
    case "bundle":
      return `묶음 ${filter.name}`;
    case "savedSearch":
      return `찾기 ${filter.query}`;
  }
}

function sameFilter(a: ArchiveFilter, b: ArchiveFilter): boolean {
  return filterTitle(a) === filterTitle(b);
}

function SectionEntry({ label, count, filter, current, onSelect }: {
  label: string;
  count?: number;
  filter: ArchiveFilter;
  current: ArchiveFilter | null;
  onSelect: (filter: ArchiveFilter) => void;
}) {
  return (
    <li>
      <button
        type="button"
        className="gt-section-entry"
        aria-label={count === undefined ? label : `${label} ${count}건`}
        aria-current={current !== null && sameFilter(current, filter) ? "true" : undefined}
        onClick={() => onSelect(filter)}
      >
        <span className="gt-section-name">{label}</span>
        {count !== undefined && <span className="gt-section-count">{count}</span>}
      </button>
    </li>
  );
}

function Section({ title, children }: { title: string; children: ReactNode }) {
  return (
    <div className="gt-section" role="group" aria-label={title}>
      <div className="gt-section-title">{title}</div>
      <ul className="gt-section-list">{children}</ul>
    </div>
  );
}

type SectionsProps = { archive: ArchiveState | null | undefined; onSelect: (filter: ArchiveFilter) => void };

/**
 * ARC-007 보관함 구역. 차례는 묶음 → 저장한 찾기 → 형식·출처·날짜·태그.
 * 묶음은 0건도 보이고(ARC-003 규칙 9), 0건 저장한 찾기는 숨긴다(ARC-012). 0건 자동 묶음은 서버가 뺀다.
 */
export function ArchiveSections({ archive, onSelect }: SectionsProps) {
  if (!archive) return null;
  const current = archive.filter;
  const savedSearches = archive.savedSearches.filter((entry) => entry.count > 0);
  return (
    <div className="gt-sections">
      <ul className="gt-section-list">
        <SectionEntry label="전체" filter={{ kind: "all" }} current={current} onSelect={onSelect} />
      </ul>
      <Section title="묶음">
        {archive.bundles.map((bundle) => (
          <SectionEntry
            key={bundle.name}
            label={bundle.name}
            count={bundle.count}
            filter={{ kind: "bundle", name: bundle.name }}
            current={current}
            onSelect={onSelect}
          />
        ))}
      </Section>
      {savedSearches.length > 0 && (
        <Section title="저장한 찾기">
          {savedSearches.map((entry) => (
            <SectionEntry
              key={entry.query}
              label={entry.query}
              count={entry.count}
              filter={{ kind: "savedSearch", query: entry.query }}
              current={current}
              onSelect={onSelect}
            />
          ))}
        </Section>
      )}
      {GROUP_ORDER.map((group) => {
        const entries = archive.groups.filter((entry) => entry.group === group && entry.count > 0);
        if (entries.length === 0) return null;
        return (
          <Section key={group} title={GROUP_TITLE[group]}>
            {entries.map((entry) => (
              <SectionEntry
                key={entry.value}
                label={autoGroupLabel(entry)}
                count={entry.count}
                filter={{ kind: "auto", group, value: entry.value }}
                current={current}
                onSelect={onSelect}
              />
            ))}
          </Section>
        );
      })}
    </div>
  );
}

/** 열어 둔 자료의 가장 새 자세히 보기. 처리가 끝나 다시 온 줄이 있으면 그 줄을 그린다(ARC-011 규칙 9). */
function latestDetail(lines: TerminalLine[], number: number): ItemDetail | null {
  for (let index = lines.length - 1; index >= 0; index -= 1) {
    const line = lines[index];
    if (line.kind === "itemDetail" && line.detail.item.number === number) return line.detail;
  }
  return null;
}

/** shortcut: `· 불러오는 중`·`✗ 불러오기 안 됨`·`다시 시도`는 iOS 보관함 탭 문구를 따랐다. 정책 문구가 생기면 바꾼다. */
function ListStatus({ archive, onRetry }: { archive: ArchiveState; onRetry: () => void }) {
  if (archive.status === "loading") return <Plain dim>· 불러오는 중</Plain>;
  if (archive.status === "error") {
    return (
      <Line tone="error">
        {"불러오기 안 됨  "}
        <button type="button" className="gt-chip" onClick={onRetry}>
          다시 시도
        </button>
      </Line>
    );
  }
  if (archive.items.length === 0) return <Line tone="info">자료 0건</Line>;
  return null;
}

function DetailPane({ detail, backButton }: { detail: ItemDetail | null; backButton?: ReactNode }) {
  return (
    <section className="gt-detail-pane" aria-label="자세히 보기 칸">
      {backButton}
      {detail === null ? <Plain dim>· 여는 중</Plain> : <ItemDetailLines key={detail.item.number} detail={detail} />}
    </section>
  );
}

export type ArchiveScreenProps = {
  layout: Layout;
  archive: ArchiveState | null | undefined;
  lines: TerminalLine[];
  selection: ItemRef[];
  /** 명령을 화면을 옮기지 않고 실행한다(`열기 N`·`고르기 N`). */
  onRun: (command: string) => void;
  /** 명령을 터미널 입력줄에 찍고 터미널로 옮긴다(자세히 보기의 동작, ARC-011 규칙 10). */
  onInsert: (command: string) => void;
  onSelect: (filter: ArchiveFilter) => void;
  onMore: () => void;
};

export function ArchiveScreen({ layout, archive, lines, selection, onRun, onInsert, onSelect, onMore }: ArchiveScreenProps) {
  const [opened, setOpened] = useState<number | null>(null);
  const selected = new Set(selection.map((ref) => ref.number));
  // 목록: 제목은 `열기 N`으로 열고, 번호는 `고르기 N`을 바로 실행한다(ARC-011 규칙 4). 입력줄이 없는 화면이라 찍지 않고 실행한다.
  const listChips: TerminalChips = {
    insert: (command) => {
      const open = /^열기 (\d+)$/.exec(command);
      if (open) setOpened(Number(open[1]));
      onRun(command);
    },
    selected,
  };
  const detailChips: TerminalChips = { insert: onInsert, selected };
  const isWide = layout === "sidebar";
  const detail = opened === null ? null : latestDetail(lines, opened);

  if (!isWide && opened !== null) {
    const back = (
      <button type="button" className="gt-chip gt-back" onClick={() => setOpened(null)}>
        ‹ 보관함
      </button>
    );
    return (
      <ChipContext.Provider value={detailChips}>
        <DetailPane detail={detail} backButton={back} />
      </ChipContext.Provider>
    );
  }

  return (
    <div className={isWide ? "gt-archive gt-archive-wide" : "gt-archive"}>
      <section className="gt-archive-list" aria-label="보관함">
        {!isWide && <ArchiveSections archive={archive} onSelect={onSelect} />}
        {archive ? (
          <>
            <div className="gt-archive-title">{filterTitle(archive.filter)}</div>
            <ChipContext.Provider value={listChips}>
              {archive.items.map((item) => (
                <ListRow key={item.number} item={item} />
              ))}
            </ChipContext.Provider>
            <ListStatus archive={archive} onRetry={archive.items.length > 0 ? onMore : () => onSelect(archive.filter)} />
            {archive.hasMore && archive.status === "idle" && <MoreChip onMoreRequested={onMore} />}
          </>
        ) : (
          <Plain dim>· 불러오는 중</Plain>
        )}
      </section>
      {isWide && opened !== null && (
        <ChipContext.Provider value={detailChips}>
          <DetailPane detail={detail} />
        </ChipContext.Provider>
      )}
    </div>
  );
}
