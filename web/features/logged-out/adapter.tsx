import { toLoggedOutState } from "../../support/bridge-state";
import { ReactScreen } from "../../support/react-screen";
import type { LoggedOutScreenHandle, LoggedOutViewBridge } from "../../support/swift";
import { TempLoggedOutView as LoggedOutView } from "../../support/temp-views";

/** 어댑터. Swift `LoggedOutViewBridge`(Sources/GrepWeb/LoggedOutBridge.swift)를 구현하고 값을 순수 뷰에 넘긴다. */
export class LoggedOutAdapter implements LoggedOutViewBridge {
  #screen = new ReactScreen<LoggedOutScreenHandle>();

  mount(host: Element, handle: LoggedOutScreenHandle): void {
    this.#screen.mount(host, handle);
  }

  render(noticeKind: string | null, failureReason: string | null, isSigningIn: boolean): void {
    const state = toLoggedOutState(noticeKind, failureReason, isSigningIn);
    this.#screen.render((handle) => (
      <LoggedOutView {...state} onSignIn={(provider) => handle.signInTapped(provider)} />
    ));
  }
}
