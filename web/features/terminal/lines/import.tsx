// 가져오기 줄 렌더러.
import { CommandChip, Plain } from "../parts";
import { Line } from "../../../ui/grep";

/** 가져오기 한 번에 받는 링크 수(COM-005, 발표 전 임시값). */
const IMPORT_LIMIT = 200;

type ImportFinishedLinesProps = { saved: number; skipped: number; failed: number; overLimit: number; failedUrls: string[] };

/**
 * commands 6절 가져오기 끝. 실패 링크는 줄마다(시안 Import ③).
 * overLimit 문구는 정책에 없어 개발 제안을 통합 세션이 승인했다(#127). commands.md에는 통합 PR에서 적는다.
 */
export function ImportFinishedLines({ saved, skipped, failed, overLimit, failedUrls }: ImportFinishedLinesProps) {
  return (
    <>
      <Line tone="ok">{`저장 ${saved}건 · 건너뜀 ${skipped}건 (이미 저장됨) · 실패 ${failed}건`}</Line>
      {failedUrls.map((url) => (
        <Plain key={url} dim>{`  실패: ${url}`}</Plain>
      ))}
      {overLimit > 0 && (
        <Line tone="warn">
          {`${IMPORT_LIMIT}건 넘어 안 가져옴 ${overLimit}건  → 나눠서 다시: `}
          <CommandChip command="가져오기" />
        </Line>
      )}
    </>
  );
}
