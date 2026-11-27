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
    case "signedOutEverywhere":
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

/** Swift가 넘기는 터미널 값(Sources/GrepWeb/TerminalStateValue.swift). 줄은 `TerminalLine`과 같은 모양의 객체다. */
export type BridgedLine = { kind: string; [field: string]: unknown };
export type BridgedLoggedInState = Omit<LoggedInState, "lines"> & { lines: readonly BridgedLine[] };

/** 계약의 줄 종류 전부. 종류가 늘거나 줄면 여기서 타입 오류가 난다. */
const LINE_KINDS: Record<TerminalLine["kind"], true> = {
  prompt: true,
  unknownCommand: true,
  missingArgument: true,
  missingTag: true,
  saved: true,
  alreadySaved: true,
  inTrash: true,
  saveFailed: true,
  recentList: true,
  searchResult: true,
  noResults: true,
  picked: true,
  notFound: true,
  invalidNumber: true,
  handedOff: true,
  handoffFailed: true,
  commandFailed: true,
  handoffConfirm: true,
  cancelled: true,
  welcome: true,
  guide: true,
  about: true,
  reconnected: true,
  dropConfirm: true,
  dropped: true,
  revived: true,
  binList: true,
  binEmptyConfirm: true,
  binEmptied: true,
  revised: true,
  tagsRemoved: true,
  samplesSaved: true,
  unpicked: true,
  pickCleared: true,
  signOutEverywhereConfirm: true,
};

/** 줄 안의 값은 Swift 브리지가 계약 모양으로 만든다. 여기서는 종류만 확인한다. */
function toLine(line: BridgedLine): TerminalLine {
  if (!Object.hasOwn(LINE_KINDS, line.kind)) throw new Error(`unknown line kind: ${line.kind}`);
  return line as TerminalLine;
}

export function toLoggedInState(bridged: BridgedLoggedInState): LoggedInState {
  return { ...bridged, lines: bridged.lines.map(toLine) };
}
