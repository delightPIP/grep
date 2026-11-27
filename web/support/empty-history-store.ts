// `web/ports/history-store.ts`의 빈 구현. 기록을 남기지 않는다. localStorage 구현은 #68이 넣는다.
import type { HistoryStore } from "../ports/history-store";

export const emptyHistoryStore: HistoryStore = {
  load: () => null,
  save: () => {},
  clear: () => {},
};
