import { type BridgedLoggedInState, toLoggedInState } from "../../support/bridge-state";
import { ReactScreen } from "../../support/react-screen";
import type { LoggedInScreenHandle, LoggedInViewBridge } from "../../support/swift";
import type { DroppedFile } from "../../support/view-state";
import { LoggedInView } from "./view";

/** 끌어다 놓은 파일을 쥐는 쪽(`support/browser-file-port.ts`). 코어에는 이름표·이름·크기만 간다. */
export type FileHolder = { hold(files: readonly File[]): DroppedFile[] };

const PLAIN_TEXT = "text/plain";
const FILES_DRAG_TYPE = "Files";

function carriesFiles(event: Event): boolean {
  return (event as DragEvent).dataTransfer?.types.includes(FILES_DRAG_TYPE) ?? false;
}

/** 어댑터. Swift `LoggedInViewBridge`(Sources/GrepWeb/LoggedInBridge.swift)를 구현하고 값을 순수 뷰에 넘긴다. */
export class LoggedInAdapter implements LoggedInViewBridge {
  #screen = new ReactScreen<LoggedInScreenHandle>();
  #files: FileHolder;

  constructor(files: FileHolder) {
    this.#files = files;
  }

  mount(host: Element, handle: LoggedInScreenHandle): void {
    this.#screen.mount(host, handle);
    this.#listenForPaste(host, handle);
    this.#listenForDrop(host, handle);
  }

  render(state: BridgedLoggedInState): void {
    const viewState = toLoggedInState(state);
    this.#screen.render((handle) => (
      <LoggedInView
        {...viewState}
        onInputChange={(text) => handle.inputChanged(text)}
        onSubmit={(text) => handle.submitted(text)}
      />
    ));
  }

  /** 붙여 넣은 글을 알린다. 기본 동작은 막지 않는다. 입력줄에도 그대로 들어가고, 저장할지는 코어가 정한다. */
  #listenForPaste(host: Element, handle: LoggedInScreenHandle): void {
    host.addEventListener("paste", (event) => {
      const text = (event as ClipboardEvent).clipboardData?.getData(PLAIN_TEXT);
      if (text) handle.pasted(text);
    });
  }

  /** 파일을 놓으면 브라우저가 그 파일을 여는 기본 동작을 막고 코어에 알린다. */
  #listenForDrop(host: Element, handle: LoggedInScreenHandle): void {
    host.addEventListener("dragover", (event) => {
      if (carriesFiles(event)) event.preventDefault();
    });
    host.addEventListener("drop", (event) => {
      const files = Array.from((event as DragEvent).dataTransfer?.files ?? []);
      if (files.length === 0) return;
      event.preventDefault();
      handle.filesDropped(this.#files.hold(files));
    });
  }
}
