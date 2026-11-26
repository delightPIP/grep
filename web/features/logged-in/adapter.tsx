import { toLoggedInState } from "../../support/bridge-state";
import { ReactScreen } from "../../support/react-screen";
import type { LoggedInScreenHandle, LoggedInViewBridge, TerminalLineRow } from "../../support/swift";
import { TempLoggedInView as LoggedInView } from "../../support/temp-views";

/** 어댑터. Swift `LoggedInViewBridge`(Sources/GrepWeb/LoggedInBridge.swift)를 구현하고 값을 순수 뷰에 넘긴다. */
export class LoggedInAdapter implements LoggedInViewBridge {
  #screen = new ReactScreen<LoggedInScreenHandle>();

  mount(host: Element, handle: LoggedInScreenHandle): void {
    this.#screen.mount(host, handle);
  }

  render(itemCount: number | null, lines: TerminalLineRow[], input: string): void {
    const state = toLoggedInState(itemCount, lines, input);
    this.#screen.render((handle) => (
      <LoggedInView
        {...state}
        onInputChange={(text) => handle.inputChanged(text)}
        onSubmit={(text) => handle.submitted(text)}
      />
    ));
  }
}
