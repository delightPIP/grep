// `web/ports/file-port.ts`의 브라우저 구현. 끌어다 놓은 File을 이름표(id)로 쥐고 있다가 서명 URL로 올린다.
import type { FilePort, FileUploadResult } from "../ports/file-port";
import type { DroppedFile } from "./view-state";

/**
 * 이 시간 안에 끝나지 않으면 `응답 없음`으로 본다(COM-010).
 * 파일을 보내는 시간까지 포함하므로 API 요청의 10초(`FetchHTTPTransport.timeoutMillis`)보다 길게 둔다.
 * 20MB를 약 2.7Mbps 이상에서 올릴 수 있는 값이다(개발자 결정 2026-11-27).
 */
const UPLOAD_TIMEOUT_MILLIS = 60_000;
const TIMEOUT_ERROR_NAME = "TimeoutError";

export class BrowserFilePort implements FilePort {
  #files = new Map<string, File>();
  #heldCount = 0;

  /** 끌어다 놓은 파일을 쥐고, 코어에 넘길 값(이름표·이름·크기)을 돌려준다. 코어가 `release`로 놓게 한다. */
  hold(files: readonly File[]): DroppedFile[] {
    return files.map((file) => {
      this.#heldCount += 1;
      const id = `file-${this.#heldCount}`;
      this.#files.set(id, file);
      return { id, name: file.name, size: file.size };
    });
  }

  async upload(fileId: string, uploadUrl: string): Promise<FileUploadResult> {
    const file = this.#files.get(fileId);
    if (!file) return { kind: "failed", error: "missingFile" };
    try {
      const response = await fetch(uploadUrl, {
        method: "PUT",
        body: file,
        signal: AbortSignal.timeout(UPLOAD_TIMEOUT_MILLIS),
      });
      return response.ok ? { kind: "uploaded" } : { kind: "failed", error: "rejected" };
    } catch (error) {
      const timedOut = error instanceof DOMException && error.name === TIMEOUT_ERROR_NAME;
      return { kind: "failed", error: timedOut ? "timedOut" : "unreachable" };
    }
  }

  release(fileId: string): void {
    this.#files.delete(fileId);
  }
}
