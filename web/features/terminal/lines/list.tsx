// 목록 줄 렌더러.
import { Fragment, useContext } from "react";
import { DAYS_PER_WEEK, kstDay, monthDay, savedAtText, spansWeeks, weekStart } from "../format/date";
import { textTitle } from "../format/title";
import { ChipContext, MoreChip, NumberCell, Plain } from "../parts";
import type { ItemSummary, Period } from "../../../support/view-state";

/** ARC-002 규칙 4 */
const LIST_TAG_LIMIT = 3;

export const isProcessing = (item: ItemSummary) => item.status === "received" || item.status === "processing";

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

/** 목록 제목. 누르면 `열기 <번호>`가 입력줄에 찍힌다(ARC-011 규칙 4). */
function TitleCell({ item }: { item: ItemSummary }) {
  const { insert } = useContext(ChipContext);
  return (
    <button type="button" className="gt-num-chip gt-row-title" onClick={() => insert(`열기 ${item.number}`)}>
      {item.kind === "text" ? textTitle(item.title) : item.title}
    </button>
  );
}

export function ListRow({ item }: { item: ItemSummary }) {
  const tags = item.tags.slice(0, LIST_TAG_LIMIT);
  const summary = rowSummary(item);
  const match = item.matchedIn === null ? undefined : MATCH_LABEL[item.matchedIn];
  return (
    <>
      <div className="gt-line gt-row">
        <NumberCell number={item.number} />
        <TitleCell item={item} />
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

/** 주 구분선 `── 10/26~11/1 ──`. 기간 끝에서 자르지 않고 월~일 한 주를 보인다(시안 TimeSearch ②). */
function WeekDivider({ start }: { start: number }) {
  return <Plain dim>{`── ${monthDay(start)}~${monthDay(start + DAYS_PER_WEEK - 1)} ──`}</Plain>;
}

type ListLinesProps = { items: ItemSummary[]; hasMore: boolean; onMoreRequested?: () => void; period?: Period | null };

export function ListLines({ items, hasMore, onMoreRequested, period }: ListLinesProps) {
  const divided = period != null && spansWeeks(period);
  const weekOf = (item: ItemSummary) => weekStart(kstDay(Date.parse(item.savedAt)));
  return (
    <>
      {items.map((item, index) => {
        const week = weekOf(item);
        const newWeek = divided && (index === 0 || weekOf(items[index - 1]) !== week);
        return (
          <Fragment key={item.number}>
            {newWeek && <WeekDivider start={week} />}
            <ListRow item={item} />
          </Fragment>
        );
      })}
      {hasMore && <MoreChip onMoreRequested={onMoreRequested} />}
    </>
  );
}
