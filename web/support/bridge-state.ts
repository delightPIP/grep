// BridgeJS가 넘긴 값(문자열·평평한 인자)을 계약 타입(view-state.ts)으로 바꾼다.
// Swift 쪽 짝: Sources/GrepWeb/BridgeValues.swift. 계약에 없는 값이 오면 두 쪽이 어긋난 것이라 던진다.
import type {
  LoggedInState,
  LoggedOutNotice,
  LoggedOutState,
  SignInFailureReason,
  TerminalLine,
} from "./view-state";

const FAILURE_REASONS: readonly SignInFailureReason[] = ["disconnected", "timedOut", "denied"];

function toFailureReason(reason: string | null): SignInFailureReason {
  const found = FAILURE_REASONS.find((known) => known === reason);
  if (!found) throw new Error(`failed notice needs a known reason, got: ${reason}`);
  return found;
}

function toNotice(kind: string | null, failureReason: string | null): LoggedOutNotice | null {
  switch (kind) {
    case null:
      return null;
    case "cancelled":
    case "expired":
    case "signedOut":
      return { kind };
    case "failed":
      return { kind, reason: toFailureReason(failureReason) };
    default:
      throw new Error(`unknown notice kind: ${kind}`);
  }
}

export function toLoggedOutState(
  noticeKind: string | null,
  failureReason: string | null,
  isSigningIn: boolean,
): LoggedOutState {
  return { notice: toNotice(noticeKind, failureReason), isSigningIn };
}

function toLine(row: { kind: string; text: string }): TerminalLine {
  switch (row.kind) {
    case "prompt":
      return { kind: "prompt", text: row.text };
    case "unknownCommand":
      return { kind: "unknownCommand", name: row.text };
    default:
      throw new Error(`unknown line kind: ${row.kind}`);
  }
}

export function toLoggedInState(
  itemCount: number | null,
  rows: readonly { kind: string; text: string }[],
  input: string,
): LoggedInState {
  return { itemCount, lines: rows.map(toLine), input };
}
