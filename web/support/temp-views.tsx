// 임시 뷰. C 갈래의 순수 뷰(features/*/view.tsx)가 병합되면 어댑터의 import를 바꾸고 이 파일을 지운다.
// props 모양은 C 갈래 핸드오프와 같다: 상태(view-state.ts) + 콜백. 문구는 ACC-001·명령어 설명서 원문이다.
import type { AuthProvider, LoggedInState, LoggedOutNotice, LoggedOutState, TerminalLine } from "./view-state";

const FAILURE_REASON_TEXT = { disconnected: "연결 끊김", timedOut: "응답 없음", denied: "권한 거부" } as const;

function noticeText(notice: LoggedOutNotice): string {
  switch (notice.kind) {
    case "cancelled":
      return "✗ 로그인 취소됨";
    case "failed":
      return `✗ 로그인 실패: ${FAILURE_REASON_TEXT[notice.reason]}`;
    case "expired":
      return "! 로그인 만료 → 다시 로그인";
    case "signedOut":
      return "✓ 로그아웃됨";
  }
}

export function TempLoggedOutView({
  notice,
  isSigningIn,
  onSignIn,
}: LoggedOutState & { onSignIn: (provider: AuthProvider) => void }) {
  return (
    <>
      <p>그렙 ~ $ 로그인 필요</p>
      {notice && <p id="notice">{noticeText(notice)}</p>}
      <button id="signInGoogle" disabled={isSigningIn} onClick={() => onSignIn("google")}>
        Google로 계속
      </button>
      <button id="signInGitHub" disabled={isSigningIn} onClick={() => onSignIn("github")}>
        GitHub로 계속
      </button>
    </>
  );
}

function lineText(line: TerminalLine): string {
  return line.kind === "prompt" ? `그렙 ~ $ ${line.text}` : `✗ 없는 명령: ${line.name}`;
}

export function TempLoggedInView({
  itemCount,
  lines,
  input,
  onInputChange,
  onSubmit,
}: LoggedInState & { onInputChange: (text: string) => void; onSubmit: (text: string) => void }) {
  return (
    <>
      <p id="statusBar">{itemCount == null ? "자료" : `자료 ${itemCount}`}</p>
      <ol id="output">
        {lines.map((line, index) => (
          <li key={index}>{lineText(line)}</li>
        ))}
      </ol>
      <form
        onSubmit={(event) => {
          event.preventDefault();
          onSubmit(input);
        }}
      >
        <input id="commandInput" autoFocus value={input} onChange={(event) => onInputChange(event.target.value)} />
      </form>
    </>
  );
}
