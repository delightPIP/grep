// 확인 줄 렌더러.
import { HANDOFF_DIRECT_LIMIT, HANDOFF_FIRST_LIMIT } from "./handoff";
import { CommandChip, Plain } from "../parts";
import { Line } from "../../../ui/grep";

/** COM-008 확인 질문. 답 낱말은 명령 칩처럼 입력줄에 찍기만 한다(엔터로 답, COM-007). */
export function HandoffConfirmLines({ total }: { total: number }) {
  return (
    <>
      <Line tone="warn">{`${total}건: 바로 복사 안 함 (${HANDOFF_DIRECT_LIMIT}건 초과)`}</Line>
      <Plain>
        {"→ "}
        {total > HANDOFF_FIRST_LIMIT && (
          <>
            <CommandChip command={`앞${HANDOFF_FIRST_LIMIT}`} />
            {`: 앞 ${HANDOFF_FIRST_LIMIT}건만 · `}
          </>
        )}
        <CommandChip command="전부" />
        {`: ${total}건 전부 · 취소: 그 외 입력`}
      </Plain>
    </>
  );
}

/** COM-007 확인 답. 실행 낱말은 칩으로 입력줄에 찍기만 한다(엔터로 답). */
export function ConfirmAnswer({ word }: { word: string }) {
  return (
    <Plain>
      {"→ 실행: "}
      <CommandChip command={word} />
      {" 다시 입력 · 취소: 그 외 입력"}
    </Plain>
  );
}

/** ARC-008 2건 이상 버리기 확인. */
export function DropConfirmLines({ total }: { total: number }) {
  return (
    <>
      <Line tone="warn">{`버리기? ${total}건 (휴지통으로)`}</Line>
      <ConfirmAnswer word="버리기" />
    </>
  );
}

/** ARC-008 휴지통 비우기 확인. */
export function BinEmptyConfirmLines({ total }: { total: number }) {
  return (
    <>
      <Line tone="warn">{`비우기? ${total}건 (되돌릴 수 없음)`}</Line>
      <ConfirmAnswer word="비우기" />
    </>
  );
}

/** ACC-002 모든 기기 로그아웃 확인. 끊길 AI 도구 연결이 있으면 `· AI 도구 연결 N개`, 없거나 모르면 그 칸을 뺀다. */
export function SignOutEverywhereConfirmLines({ connectionCount }: { connectionCount: number | null }) {
  const connections = connectionCount !== null && connectionCount > 0 ? ` · AI 도구 연결 ${connectionCount}개` : "";
  return (
    <>
      <Line tone="warn">{`로그아웃? 모든 기기${connections} (다른 기기는 최대 1시간 뒤)`}</Line>
      <ConfirmAnswer word="로그아웃" />
    </>
  );
}

/** ARC-003 규칙 8 묶음 지우기 확인. */
export function BundleDeleteConfirmLines({ name, itemCount }: { name: string; itemCount: number }) {
  return (
    <>
      <Line tone="warn">{`지우기? 묶음 ${name} (자료 ${itemCount}건은 남음)`}</Line>
      <ConfirmAnswer word="지우기" />
    </>
  );
}
