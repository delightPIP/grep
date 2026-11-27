// `web/ports/history-store.ts`의 브라우저 구현. 터미널 기록을 localStorage 한 칸에 둔다(COM-009).
// 본문은 코어가 만든 JSON 글이라 해석하지 않는다. 같은 기기의 창·탭은 한 칸을 같이 쓰고, 마지막에 쓴 것이 남는다.
import type { HistoryRecord, HistoryStore } from "../ports/history-store";

export const HISTORY_KEY = "grep.terminal-history.v1";

function isRecord(value: unknown): value is HistoryRecord {
  if (typeof value !== "object" || value === null) return false;
  const { subject, payload } = value as Record<string, unknown>;
  return typeof subject === "string" && typeof payload === "string";
}

/** 저장소를 못 쓰는 브라우저(용량 초과, 사생활 보호 설정)에서도 터미널은 돌아야 한다. 기록만 남지 않는다. */
function warn(action: string, error: unknown): void {
  console.warn(`터미널 기록 ${action} 실패`, error);
}

export const localHistoryStore: HistoryStore = {
  load() {
    try {
      const stored = localStorage.getItem(HISTORY_KEY);
      if (stored === null) return null;
      const value: unknown = JSON.parse(stored);
      return isRecord(value) ? { subject: value.subject, payload: value.payload } : null;
    } catch (error) {
      warn("읽기", error);
      return null;
    }
  },
  save(record) {
    try {
      localStorage.setItem(HISTORY_KEY, JSON.stringify(record));
    } catch (error) {
      warn("남기기", error);
    }
  },
  clear() {
    try {
      localStorage.removeItem(HISTORY_KEY);
    } catch (error) {
      warn("지우기", error);
    }
  },
};
