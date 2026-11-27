// 앱 진입점. 피처별 어댑터와 로그인 모듈, 브라우저 포트, 서버 주소를 넘긴다. 조립은 Swift `GrepAppRoot`가 한다.
import { LoggedInAdapter } from "./features/logged-in/adapter";
import { LoggedOutAdapter } from "./features/logged-out/adapter";
import { createBrowserAuthService } from "./auth/supabase-auth";
import { browserClipboard } from "./support/browser-clipboard";
import { BrowserFilePort } from "./support/browser-file-port";
import { localHistoryStore } from "./support/local-history-store";
import { init } from "./support/swift";

const { exports } = await init();
const files = new BrowserFilePort();
exports.startGrepApp(
  new LoggedOutAdapter(),
  new LoggedInAdapter(files),
  createBrowserAuthService(),
  browserClipboard,
  files,
  localHistoryStore,
  import.meta.env.VITE_API_BASE_URL,
);
