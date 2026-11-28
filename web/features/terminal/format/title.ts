// 제목·머리 줄 형식.
import { monthDay, periodDays } from "./date";
import type { ItemRef, ItemSummary, Period, TerminalLine } from "../../../support/view-state";

/** commands 6절 글 저장: `<첫 줄, 24자까지>` */
const TEXT_TITLE_LIMIT = 24;

/** 창 제목은 마지막에 친 명령 이름, 아무것도 안 쳤으면 `처음`(시안 Main·Logout ③④). */
export function windowTitle(lines: TerminalLine[]): string {
  const prompts = lines.filter((line) => line.kind === "prompt");
  const last = prompts[prompts.length - 1];
  return last?.text.trim().split(/\s+/)[0] || "처음";
}

export function withSource(item: ItemSummary): string {
  return item.source ? `${item.title} (${item.source})` : item.title;
}

export function textTitle(title: string): string {
  return Array.from(title.split("\n")[0]).slice(0, TEXT_TITLE_LIMIT).join("").trimEnd();
}

/** 찾기 머리줄 `4건`, 다음 쪽이 남으면 `23건 중 10건`. 머리 숫자는 보인 행 수와 맞춘다(commands 6절 더 보기). */
export function searchHeader(total: number, shown: number): string {
  return shown < total ? `${total}건 중 ${shown}건` : `${total}건`;
}

/** 시점이 붙으면 머리 뒤에 ` · 지난달 (10/1~10/31)`(commands 6절 시점을 붙인 결과). */
export function listHeader(total: number, shown: number, period: Period | null | undefined): string {
  const count = searchHeader(total, shown);
  if (period == null) return count;
  const { first, last } = periodDays(period);
  return `${count} · ${period.label} (${monthDay(first)}~${monthDay(last)})`;
}

export const titles = (items: ItemRef[]) => items.map((ref) => ref.title).join(" · ");
