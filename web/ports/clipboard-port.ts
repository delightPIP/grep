// 계약(#56). core/Core/Sources/ClipboardPort.swift를 JS 쪽에서 구현할 모양이다. M 갈래가 navigator.clipboard로 구현한다.

export type ClipboardResult = "copied" | "denied";

export interface ClipboardPort {
  /** 넣었으면 copied, 브라우저가 막았으면 denied(COM-008 `클립보드 거부`). */
  copy(text: string): Promise<ClipboardResult>;
}
