// 로그인 화면(W1·W2·W3·W10). 순수 뷰: 받은 상태만 그리고, 버튼은 onSignIn으로만 알린다.
// 배치는 시안 12번 아트보드(Login.dc.html), 문구는 docs/policies/account/ACC-001 "사용자 문구" 원문이다.
import type { ReactNode } from "react";
import type {
  AuthProvider,
  LoggedOutNotice,
  LoggedOutState,
  SignInFailureReason,
} from "../../support/view-state";
import { Banner, Line, SecondaryButton, StatusBar, Window, type Tone } from "../../ui/grep";

export type LoggedOutViewProps = LoggedOutState & {
  onSignIn: (provider: AuthProvider) => void;
};

const FAILURE_REASON_TEXT: Record<SignInFailureReason, string> = {
  disconnected: "연결 끊김",
  timedOut: "응답 없음",
  denied: "권한 거부",
};

/** 기호는 Line이 tone으로 붙인다. 핵심어 하나만 굵게(디자인 시스템 3절). */
function noticeLine(notice: LoggedOutNotice): { tone: Tone; text: ReactNode } {
  switch (notice.kind) {
    case "cancelled":
      return { tone: "error", text: <b>로그인 취소됨</b> };
    case "failed":
      return { tone: "error", text: <><b>로그인 실패:</b> {FAILURE_REASON_TEXT[notice.reason]}</> };
    case "expired":
      return { tone: "warn", text: <><b>로그인 만료</b> → 다시 로그인</> };
    case "signedOut":
      return { tone: "ok", text: <b>로그아웃됨</b> };
  }
}

const PROVIDERS: { provider: AuthProvider; label: string }[] = [
  { provider: "google", label: "Google로 계속" },
  { provider: "github", label: "GitHub로 계속" },
];

export function LoggedOutView({ notice, isSigningIn, onSignIn }: LoggedOutViewProps) {
  const line = notice ? noticeLine(notice) : null;
  return (
    <main className="gt-screen">
      <Window title="로그인" status={<StatusBar items={[]} />}>
        <Banner
          lead="저장해 둔 링크·캡처·PDF를 찾아 AI 도구에 붙여 넣을 글로 복사"
          tagline="담기 → 찾기 → 넘기기"
        />
        <div style={{ height: 12 }} aria-hidden="true" />
        <div className="gt-login-prompt">
          <span className="gt-login-prompt-head">그렙 ~ $</span> <span>로그인 필요</span>
        </div>
        {line && <Line tone={line.tone}>{line.text}</Line>}
        <div className="gt-login-actions">
          {PROVIDERS.map(({ provider, label }) => (
            <SecondaryButton
              key={provider}
              label={label}
              disabled={isSigningIn}
              onPress={() => onSignIn(provider)}
            />
          ))}
        </div>
      </Window>
    </main>
  );
}
