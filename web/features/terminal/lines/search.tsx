// 찾기 줄 렌더러.
import { listHeader } from "../format/title";
import { ListLines } from "./list";
import { CommandChip, NameCountRow, Plain } from "../parts";
import type { ItemSummary, Period, SavedSearchEntry, SearchQuery, TerminalLine } from "../../../support/view-state";
import { Line } from "../../../ui/grep";

type SearchResultLinesProps = {
  total: number;
  items: ItemSummary[];
  hasMore: boolean;
  onMoreRequested?: () => void;
  period?: Period | null;
  /** 결과 맨 아래 `→ 찾아두기 <검색어>` 칩의 검색어(ARC-012 규칙 9). 두지 않으면 null·없음 */
  saveQuery?: string | null;
};

export function SearchResultLines({ total, items, hasMore, onMoreRequested, period, saveQuery }: SearchResultLinesProps) {
  return (
    <>
      <Plain>{listHeader(total, items.length, period)}</Plain>
      <ListLines items={items} hasMore={hasMore} onMoreRequested={onMoreRequested} period={period} />
      {saveQuery != null && (
        <Plain>
          {"→ "}
          <CommandChip command={`찾아두기 ${saveQuery}`} />
        </Plain>
      )}
    </>
  );
}

/**
 * ARC-012 규칙 9: 찾기 결과의 `찾아두기 <검색어>` 칩. 이미 찾아둔 검색어(isSavedSearch, 찾아두기 바로 뒤 결과)와
 * 시점이 붙은 찾기(규칙 4, 저장하지 않음)에는 두지 않는다.
 */
export function saveQueryFor(line: Extract<TerminalLine, { kind: "searchResult" }>, savedInBlock: boolean): string | null {
  if (line.isSavedSearch === true || savedInBlock || line.period != null) return null;
  return line.query.text;
}

/** ARC-012 사용자 문구 찾아두기 결과. 결과 목록은 searchResult 줄이 이어서 그린다. */
export function SearchSavedLines({ query, total, already }: { query: string; total: number; already: boolean }) {
  if (already) return <Line tone="warn">{`이미 찾아둠: ${query}`}</Line>;
  return (
    <>
      <Line tone="ok">{`찾아둠: ${query}  ${total}건`}</Line>
      <Line tone="info">{total === 0 ? "맞는 자료가 저장되면 모임" : "보관함 저장한 찾기에 있음"}</Line>
    </>
  );
}

/** ARC-012 규칙 6 찾아둔 목록. 순서는 서버가 만든 순서 최신부터 준다. 검색어를 누르면 `찾아두기 <검색어>`가 찍힌다. */
export function SavedSearchListLines({ searches }: { searches: SavedSearchEntry[] }) {
  if (searches.length === 0) {
    return (
      <>
        <Line tone="info">찾아둔 것 없음</Line>
        <Plain>
          {"→ "}
          <CommandChip command="찾아두기 ">찾아두기 &lt;검색어&gt;</CommandChip>
        </Plain>
      </>
    );
  }
  return (
    <>
      <Plain>{`${searches.length}개 찾아둠`}</Plain>
      {searches.map((search) => (
        <NameCountRow key={search.query} name={search.query} count={search.count} command={`찾아두기 ${search.query}`} />
      ))}
    </>
  );
}

/** 시점 낱말을 뺀 검색어(`결제 #위젯`). 시점이 붙은 찾기에서 query.text는 시점까지 친 그대로라 다시 만든다. */
const queryWithoutPeriod = (query: SearchQuery) => [query.words, ...query.tags.map((tag) => `#${tag}`)].filter(Boolean).join(" ");

type NoResultsLinesProps = { query: SearchQuery; recent: ItemSummary[]; period?: Period | null; related?: ItemSummary[] | null };

/**
 * 0건 뒤 목록. 뜻이 가까운 자료(#128, ADR-BCK-016)가 있으면 최근 저장 대신 그것을 보인다. 문구는 통합 세션 확정(사용자 승인).
 * 시점이 붙은 0건이어도 같고, `→ 기간 없이` 줄은 그 위에 그대로 둔다.
 */
function NoResultsList({ recent, related }: { recent: ItemSummary[]; related: ItemSummary[] }) {
  if (related.length > 0) {
    return (
      <>
        <Line tone="info">{`뜻이 가까운 자료 ${related.length}건 (낱말은 다름)`}</Line>
        <ListLines items={related} hasMore={false} />
      </>
    );
  }
  return (
    <>
      {recent.length > 0 && <Line tone="info">{`최근 저장 ${recent.length}건 (검색 결과 아님)`}</Line>}
      <ListLines items={recent} hasMore={false} />
    </>
  );
}

export function NoResultsLines({ query, recent, period, related }: NoResultsLinesProps) {
  const bare = queryWithoutPeriod(query);
  return (
    <>
      {period == null ? (
        <Line tone="info">{`0건: "${query.text}"`}</Line>
      ) : (
        // commands 6절 시점을 붙인 결과: `· 0건: "결제" (지난달)` 뒤에 `→ 기간 없이: 찾기 결제`.
        <>
          <Line tone="info">{`0건: "${bare}" (${period.label})`}</Line>
          <Plain>
            {"→ 기간 없이: "}
            <CommandChip command={`찾기 ${bare}`} />
          </Plain>
        </>
      )}
      <NoResultsList recent={recent} related={related ?? []} />
    </>
  );
}
