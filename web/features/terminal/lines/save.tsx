// 담기 줄 렌더러.
import { megabytes } from "../format/size";
import { textTitle, withSource } from "../format/title";
import { isProcessing, ListRow } from "./list";
import { CommandChip, Plain } from "../parts";
import type { ItemSummary, SaveFailure, SaveRecovery } from "../../../support/view-state";
import { Line } from "../../../ui/grep";

/** ARC-005 이유 낱말과 COM-004 파일 문구. */
function failureText(reason: SaveFailure): string {
  switch (reason.kind) {
    case "disconnected":
      return "연결 끊김";
    case "timedOut":
      return "응답 없음";
    case "serverError":
      return "서버 오류";
    case "unsupportedFormat":
      return `받지 않는 형식 (.${reason.fileExtension})`;
    case "tooLarge":
      return `20MB 넘음 (${reason.fileName} · ${megabytes(reason.bytes)})`;
  }
}

/** ARC-005 규칙 2. 크기·형식 거절은 COM-004 문구에 이미 무엇인지 들어 있어 파일 이름을 붙이지 않는다. */
function recoverySuffix(reason: SaveFailure, recovery: SaveRecovery): string {
  if (recovery.kind === "inputKept") return "  입력은 남겨 둠";
  if (recovery.kind === "file" && (reason.kind === "disconnected" || reason.kind === "timedOut" || reason.kind === "serverError")) {
    return ` (${recovery.name})`;
  }
  return "";
}

export function SavedLines({ item }: { item: ItemSummary }) {
  return (
    <>
      <Line tone="ok">
        {item.kind === "text" ? `저장됨 (글)  ${textTitle(item.title)}` : `저장됨  ${withSource(item)}`}
      </Line>
      {isProcessing(item) && <Plain dim>· 요약 생성 중</Plain>}
    </>
  );
}

export function AlreadySavedLines({ item }: { item: ItemSummary }) {
  return (
    <>
      <Line tone="warn">이미 저장됨 → {item.number}번 (새로 만들지 않음)</Line>
      <ListRow item={item} />
      <Plain>
        {"→ "}
        <CommandChip command={`고르기 ${item.number}`} />
      </Plain>
    </>
  );
}

export function SaveFailedLines({ reason, recovery }: { reason: SaveFailure; recovery: SaveRecovery }) {
  return (
    <>
      <Line tone="error">{`저장 안 됨: ${failureText(reason)}${recoverySuffix(reason, recovery)}`}</Line>
      {recovery.kind === "retry" && <Plain>→ 다시: {recovery.command}</Plain>}
    </>
  );
}

/** 고친 뒤. 직접 고친 요약에는 ARC-004 규칙 1 이름표를 붙인다(시안 Edit ②). */
export function RevisedLines({ item }: { item: ItemSummary }) {
  return (
    <>
      <Line tone="ok">{`고침 ${item.number}번  ${item.title}`}</Line>
      {item.summarySource === "user" && item.listSummary !== null && (
        <Plain dim>{`요약 (직접 고침)  ${item.listSummary}`}</Plain>
      )}
    </>
  );
}
