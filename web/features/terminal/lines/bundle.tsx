// 묶음 줄 렌더러.
import { searchHeader } from "../format/title";
import { ListLines } from "./list";
import { CommandChip, NameCountRow, Plain } from "../parts";
import type { BundleEntry, ItemSummary } from "../../../support/view-state";
import { Line } from "../../../ui/grep";

/** ARC-003 규칙 3 묶음 목록. 순서는 서버가 최근에 바뀐 순으로 준다. 없으면 차례로 할 일을 줄을 나눠 안내한다. */
export function BundleListLines({ bundles }: { bundles: BundleEntry[] }) {
  if (bundles.length === 0) {
    return (
      <>
        <Line tone="info">묶음 0개</Line>
        <Plain>
          {"→ "}
          <CommandChip command="고르기 ">고르기 &lt;번호&gt;</CommandChip>
        </Plain>
        <Plain>
          {"→ "}
          <CommandChip command="묶음 ">묶음 &lt;이름&gt;</CommandChip>
        </Plain>
      </>
    );
  }
  return (
    <>
      <Plain>{`${bundles.length}개 묶음`}</Plain>
      {bundles.map((bundle) => (
        <NameCountRow key={bundle.name} name={bundle.name} count={bundle.count} command={`묶음 ${bundle.name}`} />
      ))}
    </>
  );
}

/** ARC-003 넣기. count는 넣은 뒤 묶음 건수다. */
export function BundleAddedLines({ name, count, alreadyCount }: { name: string; count: number; alreadyCount: number }) {
  const already = alreadyCount > 0 ? ` (이미 있음 ${alreadyCount}건)` : "";
  return (
    <>
      <Line tone="ok">{`묶음 ${name}: ${count}건${already}`}</Line>
      <Plain>
        {"→ 다음부터: "}
        <CommandChip command={`넘기기 ${name}`} />
      </Plain>
    </>
  );
}

type BundleViewLinesProps = { name: string; total: number; items: ItemSummary[]; hasMore: boolean; onMoreRequested?: () => void };

/** ARC-003 규칙 5 묶음 안 자료(번호 큰 순). 다음 쪽이 남으면 머리 숫자를 보인 행 수와 맞춘다(commands 6절 더 보기). */
export function BundleViewLines({ name, total, items, hasMore, onMoreRequested }: BundleViewLinesProps) {
  return (
    <>
      <Plain>{`묶음 ${name}  ${searchHeader(total, items.length)}`}</Plain>
      <ListLines items={items} hasMore={hasMore} onMoreRequested={onMoreRequested} />
    </>
  );
}

/** ARC-003 사용자 문구 이름 규칙 위반·금지 이름. */
export const BUNDLE_NAME_RULE = {
  format: "묶음 이름: 띄어쓰기 없이 1~20자 (한글·영문·숫자·-·_)",
  reserved: "묶음 이름: 숫자만 · #시작 · 빼기 · 지우기 불가",
} as const;
