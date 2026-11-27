// 계약(#56). core/Core/Sources/HistoryStore.swift를 JS 쪽에서 구현할 모양이다. M 갈래가 localStorage로 구현한다.
// 기록 본문(payload)은 코어가 만든 JSON 문자열이다. 이 포트는 해석하지 않고 읽고 쓰기만 한다(COM-009).

export type HistoryRecord = {
  /** 기록을 남긴 계정(접근 토큰의 sub). 다른 계정이면 코어가 되살리지 않는다. */
  subject: string;
  payload: string;
};

export interface HistoryStore {
  /** 없거나 읽지 못하면 null. */
  load(): HistoryRecord | null;
  save(record: HistoryRecord): void;
  /** 로그아웃·다른 계정 로그인 때 지운다(COM-009 규칙 3·5). */
  clear(): void;
}
