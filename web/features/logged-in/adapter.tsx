import { type BridgedLoggedInState, toLoggedInState } from "../../support/bridge-state";
import { ReactScreen } from "../../support/react-screen";
import type { LoggedInScreenHandle, LoggedInViewBridge } from "../../support/swift";
import type { DroppedFile } from "../../support/view-state";
import { LoggedInView } from "./view";

/** 끌어다 놓은 파일을 쥐는 쪽(`support/browser-file-port.ts`). 코어에는 이름표·이름·크기만 간다. */
export type FileHolder = { hold(files: readonly File[]): DroppedFile[] };

/** 어댑터. Swift `LoggedInViewBridge`(Sources/GrepWeb/LoggedInBridge.swift)를 구현하고 값을 순수 뷰에 넘긴다. */
export class LoggedInAdapter implements LoggedInViewBridge {
  #screen = new ReactScreen<LoggedInScreenHandle>();
  #files: FileHolder;

  constructor(files: FileHolder) {
    this.#files = files;
  }

  mount(host: Element, handle: LoggedInScreenHandle): void {
    this.#screen.mount(host, handle);
  }

  render(state: BridgedLoggedInState): void {
    const viewState = toLoggedInState(state);
    this.#screen.render((handle) => (
      <LoggedInView
        {...viewState}
        onInputChange={(text) => handle.inputChanged(text)}
        onSubmit={(text) => handle.submitted(text)}
        onPaste={(text) => handle.pasted(text)}
        onFilesDrop={(files) => handle.filesDropped(this.#files.hold(files))}
      />
    ));
  }
}
