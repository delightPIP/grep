// 날짜 형식. 한국 날짜(KST) 계산과 저장 시각 표기.
import type { Period } from "../../../support/view-state";

/** ARC-004 규칙 7: 저장 시각은 한국 시간. 표기는 ARC-011 `2026-11-26 14:03`과 같게. */
const SAVED_AT_FORMAT = new Intl.DateTimeFormat("en-CA", {
  timeZone: "Asia/Seoul",
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
  hour: "2-digit",
  minute: "2-digit",
  hourCycle: "h23",
});

export function savedAtText(savedAt: string): string {
  const part = Object.fromEntries(SAVED_AT_FORMAT.formatToParts(new Date(savedAt)).map((p) => [p.type, p.value]));
  return `${part.year}-${part.month}-${part.day} ${part.hour}:${part.minute}`;
}

/**
 * 시점(F22) 날짜 계산. 한국 시간은 일광 절약 시간이 없어 UTC+9 고정이므로, 9시간을 더한 UTC 날짜를 한국 날짜로 쓴다.
 * 날짜는 1970-01-01부터 센 한국 날짜 번호로 다룬다.
 */
const KST_OFFSET_MS = 9 * 60 * 60 * 1000;

const DAY_MS = 24 * 60 * 60 * 1000;

export const DAYS_PER_WEEK = 7;

export const kstDay = (ms: number) => Math.floor((ms + KST_OFFSET_MS) / DAY_MS);

/** 주는 월요일에 시작한다(commands 3절 시점). */
export function weekStart(day: number): number {
  const sundayBased = new Date(day * DAY_MS).getUTCDay();
  return day - ((sundayBased + DAYS_PER_WEEK - 1) % DAYS_PER_WEEK);
}

export function monthDay(day: number): string {
  const date = new Date(day * DAY_MS);
  return `${date.getUTCMonth() + 1}/${date.getUTCDate()}`;
}

/** 기간의 첫날과 마지막 날. to는 반열린 구간 끝이라 1ms 앞이 마지막 날이다. */
export function periodDays(period: Period): { first: number; last: number } {
  return { first: kstDay(Date.parse(period.from)), last: kstDay(Date.parse(period.to) - 1) };
}

/** 기간이 여러 주에 걸치면 주 구분선을 넣는다(user-flow 5절 3번). */
export function spansWeeks(period: Period): boolean {
  const { first, last } = periodDays(period);
  return weekStart(first) !== weekStart(last);
}

/** 연결 목록 날짜 `11/20`. 한국 날짜다(ARC-004 규칙 7). */
export const connectionDay = (iso: string) => monthDay(kstDay(Date.parse(iso)));

/** 한국 날짜 `MM/DD`. 설정 화면 연결 목록 표기(ACC-002 규칙 7). */
const PADDED_DAY_FORMAT = new Intl.DateTimeFormat("en-US", { timeZone: "Asia/Seoul", month: "2-digit", day: "2-digit" });
export const paddedKstMonthDay = (iso: string) => PADDED_DAY_FORMAT.format(new Date(iso));
