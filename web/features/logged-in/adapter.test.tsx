import { act } from "react";
import { describe, expect, it, vi } from "vitest";
import type { LoggedInScreenHandle } from "../../support/swift";
import type { BridgedLoggedInState } from "../../support/bridge-state";
import type { DroppedFile } from "../../support/view-state";
import { LoggedInAdapter } from "./adapter";

function mountAdapter(held: DroppedFile[] = [], lines: BridgedLoggedInState["lines"] = []) {
  const handle = {
    inputChanged: vi.fn(),
    submitted: vi.fn(),
    pasted: vi.fn(),
    filesDropped: vi.fn(),
    moreRequested: vi.fn(),
    release: vi.fn(),
  } satisfies LoggedInScreenHandle;
  const hold = vi.fn((_files: readonly File[]) => held);
  const host = document.createElement("section");
  document.body.append(host);
  const adapter = new LoggedInAdapter({ hold });
  adapter.mount(host, handle);
  act(() =>
    adapter.render({ itemCount: 34, lines, input: "", selection: [], processingCount: 0, isOffline: false }),
  );
  // 붙여 넣기·놓기는 순수 뷰가 받는다. 이벤트는 뷰가 그린 화면에 보낸다.
  const screen = host.querySelector("main")!;
  return { screen, handle, hold };
}

function pasteEvent(text: string): Event {
  const event = new Event("paste", { bubbles: true, cancelable: true });
  return Object.assign(event, { clipboardData: { getData: () => text } });
}

function dragEvent(type: "dragover" | "drop", files: File[]): Event {
  const event = new Event(type, { bubbles: true, cancelable: true });
  return Object.assign(event, { dataTransfer: { files, types: files.length > 0 ? ["Files"] : ["text/plain"] } });
}

describe("터미널 화면 어댑터", () => {
  it("더보기있는목록이있을때_더보기를누르면_moreRequested를보내는지", () => {
    // given
    const { screen, handle } = mountAdapter([], [{ kind: "recentList", items: [], hasMore: true }]);
    const more = Array.from(screen.querySelectorAll("button")).find((button) => button.textContent?.includes("더 보기"));

    // when
    act(() => more?.click());

    // then
    expect(handle.moreRequested).toHaveBeenCalledTimes(1);
  });

  it("화면이붙어있을때_글을붙여넣으면_그글을pasted로보내는지", () => {
    // given
    const { screen, handle } = mountAdapter();

    // when
    screen.dispatchEvent(pasteEvent("https://example.com/pay"));

    // then
    expect(handle.pasted).toHaveBeenCalledWith("https://example.com/pay");
  });

  it("클립보드에글이없을때_붙여넣으면_아무것도보내지않는지", () => {
    // given
    const { screen, handle } = mountAdapter();

    // when
    screen.dispatchEvent(pasteEvent(""));

    // then
    expect(handle.pasted).not.toHaveBeenCalled();
  });

  it("파일을끌어왔을때_화면에놓으면_쥔파일값을filesDropped로보내고브라우저기본동작을막는지", () => {
    // given
    const held = [{ id: "f1", name: "결제.pdf", size: 8 }];
    const { screen, handle, hold } = mountAdapter(held);
    const file = new File(["%PDF-1.7"], "결제.pdf");
    const drop = dragEvent("drop", [file]);

    // when
    screen.dispatchEvent(drop);

    // then
    expect(hold).toHaveBeenCalledWith([file]);
    expect(handle.filesDropped).toHaveBeenCalledWith(held);
    expect(drop.defaultPrevented).toBe(true);
  });

  it("파일을끌고있을때_화면위를지나면_놓을수있게기본동작을막는지", () => {
    // given
    const { screen } = mountAdapter();
    const dragOver = dragEvent("dragover", [new File(["x"], "a.md")]);

    // when
    screen.dispatchEvent(dragOver);

    // then
    expect(dragOver.defaultPrevented).toBe(true);
  });

  it("파일이아닌것을끌어왔을때_화면에놓으면_아무것도보내지않는지", () => {
    // given
    const { screen, handle, hold } = mountAdapter();

    // when
    screen.dispatchEvent(dragEvent("drop", []));

    // then
    expect(hold).not.toHaveBeenCalled();
    expect(handle.filesDropped).not.toHaveBeenCalled();
  });
});
