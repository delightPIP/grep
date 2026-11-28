// 자료 보기 줄 렌더러.
import { type ReactNode, useState } from "react";
import { savedAtText } from "../format/date";
import { charCountText } from "../format/size";
import { Preview } from "./handoff";
import { isProcessing } from "./list";
import { ChipList, CommandChip, NumberCell, Plain } from "../parts";
import type { BlockedReason, ItemDetail, ItemSummary } from "../../../support/view-state";
import { Line } from "../../../ui/grep";

/** ARC-005·COM-004 `본문 못 가져옴: <이유>`의 이유 낱말. */
const BLOCKED_REASON_LABEL: Record<BlockedReason, string> = {
  loginRequired: "로그인 필요",
  accessDenied: "접근 거부",
  disallowedURL: "열지 않는 주소",
  encrypted: "암호 걸린 PDF",
  noText: "글자 없음",
};

/** ARC-005 처리 상태 문구. 파일 이유(COM-004)에는 `제목·링크만 저장`을 붙이지 않는다. ready면 null. */
function statusText(item: ItemSummary): { tone: "hint" | "warn"; text: string } | null {
  if (isProcessing(item)) return { tone: "hint", text: "· 요약 생성 중" };
  if (item.status === "failed") return { tone: "warn", text: "! 요약 못 만듦  제목·출처만 넘김" };
  if (item.status !== "blocked" || item.blockedReason === null) return null;
  const reason = BLOCKED_REASON_LABEL[item.blockedReason];
  return {
    tone: "warn",
    text: item.kind === "link" ? `! 본문 못 가져옴: ${reason}  제목·링크만 저장` : `! 본문 못 가져옴: ${reason}`,
  };
}

/** 새 탭으로 열 주소. http·https만 링크로 만든다(`javascript:` 같은 주소를 막는다). */
function isWebUrl(url: string): boolean {
  try {
    const { protocol } = new URL(url);
    return protocol === "http:" || protocol === "https:";
  } catch {
    return false;
  }
}

/** ARC-011 규칙 6-2 출처 칸. 링크 자료는 호스트를 누르면 원래 주소를 새 탭으로 연다. */
function DetailSource({ detail }: { detail: ItemDetail }) {
  const text = detailSource(detail);
  if (detail.item.kind !== "link" || detail.url === null || !isWebUrl(detail.url)) return <>{text}</>;
  return (
    <a className="gt-chip" href={detail.url} target="_blank" rel="noopener noreferrer">
      {text}
    </a>
  );
}

/** ARC-011 규칙 6-2 출처 글. 링크는 호스트, 아니면 `직접 넣음 · <형식>`(ARC-007 형식 값). 이미지는 미리보기 URL이 있는 파일이다(계약). */
function detailSource(detail: ItemDetail): string {
  const { item } = detail;
  if (item.kind === "link") return item.source ?? "";
  if (item.kind === "text") return "직접 넣음 · 글";
  if (detail.previewUrl !== null) return "직접 넣음 · 이미지";
  return item.source ? `직접 넣음 · ${item.source.toUpperCase()}` : "직접 넣음";
}

/** 자세히 보기 한 줄. 이름표 칸과 값 칸(시안 ItemDetail). */
function DetailRow({ label, tone, children }: { label: string; tone?: "hint" | "warn"; children: ReactNode }) {
  return (
    <div className={tone ? `gt-line gt-detail-row gt-${tone}` : "gt-line gt-detail-row"}>
      <span className="gt-detail-label">{label}</span>
      <span>{children}</span>
    </div>
  );
}

/** ARC-011 규칙 6-8·7 본문 머리. 일부만 읽었으면 ARC-004 규칙 8 문구를 붙인다. */
function bodyHead(detail: ItemDetail): string {
  const from = detail.bodyFromImage ? "(이미지에서 읽음) " : "";
  const partial = detail.item.partialNote ? ` (${detail.item.partialNote})` : "";
  // 본문이 있으면 서버가 글자 수도 준다. 없으면 받은 본문(앞 2만 자) 길이로 대신한다.
  return `${from}${charCountText(detail.bodyLength ?? Array.from(detail.body ?? "").length)}${partial}  `;
}

/** ARC-011 규칙 6-9 원본. 이미지는 그림, 파일은 `원본 열기`(서명 URL 10분). PDF 첫 쪽 그림은 계약에 아직 없다. */
function OriginalRow({ detail }: { detail: ItemDetail }) {
  if (detail.previewUrl === null && detail.originalUrl === null) return null;
  return (
    <DetailRow label="원본">
      <span className="gt-detail-original">
        {detail.previewUrl !== null && (
          <img className="gt-detail-image" src={detail.previewUrl} alt={`${detail.item.title} 미리보기`} />
        )}
        {detail.originalUrl !== null && (
          <a className="gt-chip" href={detail.originalUrl} target="_blank" rel="noopener noreferrer">
            원본 열기
          </a>
        )}
      </span>
    </DetailRow>
  );
}

/** ARC-011 규칙 6-8 본문. 본문이 없으면 이유가 있을 때만 `· 본문 없음: <이유>`. */
/**
 * 본문이 없을 때 `· 본문 없음: <이유>`의 이유(통합 세션 규칙, #131). blocked·failed만 그리고,
 * 처리 중(상태 줄이 알림)과 ready(본문 열이 생기기 전에 처리된 자료)는 본문 줄을 그리지 않는다.
 * failed 이유 `처리 실패`는 handoff-format 3절과 같은 낱말이다(`(요약 없음: 처리 실패)`, 통합 세션 확정).
 */
function noBodyReason(item: ItemSummary): string | null {
  if (item.status === "failed") return "처리 실패";
  if (item.status === "blocked" && item.blockedReason !== null) return BLOCKED_REASON_LABEL[item.blockedReason];
  return null;
}

function DetailBody({ detail }: { detail: ItemDetail }) {
  const { item } = detail;
  const [isExpanded, setExpanded] = useState(item.kind === "text");
  if (detail.body === null) {
    const reason = noBodyReason(item);
    return reason === null ? null : <Line tone="info">{`본문 없음: ${reason}`}</Line>;
  }
  return (
    <>
      <DetailRow label="본문">
        {bodyHead(detail)}
        <button type="button" className="gt-chip" aria-expanded={isExpanded} onClick={() => setExpanded(!isExpanded)}>
          {isExpanded ? "접기" : "펼치기"}
        </button>
      </DetailRow>
      {isExpanded && <Preview text={detail.body} />}
    </>
  );
}

/**
 * ARC-011 규칙 6 자세히 보기. 값이 없는 줄은 뺀다. 터미널 출력 블록은 연 때 모습 그대로 둔다(규칙 9).
 * 글 자료는 본문이 곧 원본이라 펼쳐 둔다. `펼치기`는 화면 칩이라 누르면 바로 펼친다.
 */
export function ItemDetailLines({ detail }: { detail: ItemDetail }) {
  const { item } = detail;
  const status = statusText(item);
  const summaryLabel = item.summarySource === "user" ? "요약 (직접 고침)" : "AI 요약";
  return (
    <section className="gt-detail" aria-label="자세히 보기">
      <div className="gt-line gt-row">
        <NumberCell number={item.number} />
        <b>{item.title}</b>
      </div>
      <DetailRow label="출처">
        <DetailSource detail={detail} />
      </DetailRow>
      <DetailRow label="저장">{savedAtText(item.savedAt)}</DetailRow>
      {status !== null && (
        <DetailRow label="상태" tone={status.tone}>
          {status.text}
        </DetailRow>
      )}
      {detail.handoffSummary !== null && <DetailRow label={summaryLabel}>{detail.handoffSummary}</DetailRow>}
      {detail.allTags.length > 0 && (
        <DetailRow label="태그 (AI 추정)">
          <ChipList commands={detail.allTags.map((tag) => [`#${tag}`, `찾기 #${tag}`] as const)} />
        </DetailRow>
      )}
      <DetailRow label="묶음">
        {detail.bundles.length === 0 ? "없음" : <ChipList commands={detail.bundles.map((name) => [name, `묶음 ${name}`] as const)} />}
      </DetailRow>
      <DetailBody detail={detail} />
      <OriginalRow detail={detail} />
      <Plain>
        {"→ "}
        <CommandChip command={`고르기 ${item.number}`} />
        {" 또는 "}
        <CommandChip command="묶음 ">묶음 &lt;이름&gt;</CommandChip>
        {" 또는 "}
        <CommandChip command={`고치기 ${item.number}`} />
        {" 또는 "}
        <CommandChip command={`버리기 ${item.number}`} />
      </Plain>
    </section>
  );
}
