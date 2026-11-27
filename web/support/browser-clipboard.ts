// `web/ports/clipboard-port.ts`의 브라우저 구현.
import type { ClipboardPort } from "../ports/clipboard-port";

/** 권한 거부, 보안 컨텍스트가 아니어서 `navigator.clipboard`가 없는 경우 모두 `클립보드 거부`다(COM-008). */
export const browserClipboard: ClipboardPort = {
  async copy(text) {
    try {
      await navigator.clipboard.writeText(text);
      return "copied";
    } catch {
      return "denied";
    }
  },
};
