// 계약(#56). core/Core/Sources/FilePort.swift를 JS 쪽에서 구현할 모양이다.
// 끌어다 놓은 File은 이 포트가 id로 들고 있고, 코어는 id·이름·크기(DroppedFile)만 안다.

export type FileUploadError = "cancelled" | "unreachable" | "timedOut" | "rejected" | "missingFile";

export type FileUploadResult = { kind: "uploaded" } | { kind: "failed"; error: FileUploadError };

export interface FilePort {
  /** 서명 URL(`POST /uploads`의 uploadUrl)로 PUT한다. 형식 판정과 해시는 서버가 한다(COM-004 규칙 2, COM-001). */
  upload(fileId: string, uploadUrl: string): Promise<FileUploadResult>;
  /** 이 파일을 더 쓰지 않는다. 잡고 있던 File을 놓는다. */
  release(fileId: string): void;
}
