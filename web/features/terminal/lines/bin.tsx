// 휴지통 줄 렌더러.
import { searchHeader, textTitle } from "../format/title";
import { CommandChip, MoreChip, NumberCell, Plain } from "../parts";
import type { TrashEntry } from "../../../support/view-state";
import { Line } from "../../../ui/grep";

/** 휴지통 행. 시각 칸에 영구 삭제까지 남은 날(ARC-008 규칙 10). */
function TrashRow({ entry: { item, daysLeft } }: { entry: TrashEntry }) {
  return (
    <div className="gt-line gt-row">
      <NumberCell number={item.number} />
      <span>{item.kind === "text" ? textTitle(item.title) : item.title}</span>
      {item.source && <span className="gt-row-meta">{item.source}</span>}
      <span className="gt-row-meta">{`${daysLeft}일 남음`}</span>
    </div>
  );
}

/** 빈 휴지통(`휴지통` 목록 0건, 빈 휴지통 비우기). 문구는 정책에 없어 통합 세션 요청을 따른다. */
export function EmptyBinLine() {
  return <Line tone="info">휴지통 비어 있음</Line>;
}

type BinListLinesProps = { total: number; items: TrashEntry[]; hasMore: boolean; onMoreRequested?: () => void };

/** `휴지통` 목록(ARC-008 규칙 5, 시안 Trash ③). 순서는 서버가 지운 날 최신순으로 준다. */
export function BinListLines({ total, items, hasMore, onMoreRequested }: BinListLinesProps) {
  if (total === 0) return <EmptyBinLine />;
  return (
    <>
      <Plain>{searchHeader(total, items.length)}</Plain>
      {items.map((entry) => (
        <TrashRow key={entry.item.number} entry={entry} />
      ))}
      {hasMore && <MoreChip onMoreRequested={onMoreRequested} />}
      <Plain>
        {"→ "}
        <CommandChip command="되살리기 ">되살리기</CommandChip>
        {" 또는 "}
        <CommandChip command="휴지통 비우기" />
      </Plain>
    </>
  );
}
