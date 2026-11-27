import { afterEach, describe, expect, it, vi } from "vitest";
import { BrowserFilePort } from "./browser-file-port";

const UPLOAD_URL = "https://storage.example.com/object/upload/sign/items/a.pdf?token=t";

function pdf(name = "결제.pdf"): File {
  return new File(["%PDF-1.7"], name, { type: "application/pdf" });
}

function stubFetch(result: () => Promise<Response>) {
  const fetchMock = vi.fn(result);
  vi.stubGlobal("fetch", fetchMock);
  return fetchMock;
}

afterEach(() => vi.unstubAllGlobals());

describe("브라우저 파일 포트", () => {
  it("파일두개를끌어다놓았을때_쥐면_서로다른이름표와이름과크기를돌려주는지", () => {
    // given
    const port = new BrowserFilePort();
    const files = [pdf("a.pdf"), pdf("b.pdf")];

    // when
    const held = port.hold(files);

    // then
    expect(held.map((file) => file.name)).toEqual(["a.pdf", "b.pdf"]);
    expect(held.map((file) => file.size)).toEqual([files[0].size, files[1].size]);
    expect(held[0].id).not.toBe(held[1].id);
  });

  it("쥔파일이있을때_올리면_서명URL로파일을PUT하는지", async () => {
    // given
    const fetchMock = stubFetch(async () => new Response(null, { status: 200 }));
    const port = new BrowserFilePort();
    const file = pdf();
    const [held] = port.hold([file]);

    // when
    const result = await port.upload(held.id, UPLOAD_URL);

    // then
    expect(result).toEqual({ kind: "uploaded" });
    expect(fetchMock).toHaveBeenCalledWith(UPLOAD_URL, expect.objectContaining({ method: "PUT", body: file }));
  });

  it("저장소가2xx밖으로답할때_올리면_rejected로끝나는지", async () => {
    // given
    stubFetch(async () => new Response(null, { status: 403 }));
    const port = new BrowserFilePort();
    const [held] = port.hold([pdf()]);

    // when
    const result = await port.upload(held.id, UPLOAD_URL);

    // then
    expect(result).toEqual({ kind: "failed", error: "rejected" });
  });

  it("서버에닿지못할때_올리면_unreachable로끝나는지", async () => {
    // given
    stubFetch(async () => {
      throw new TypeError("Failed to fetch");
    });
    const port = new BrowserFilePort();
    const [held] = port.hold([pdf()]);

    // when
    const result = await port.upload(held.id, UPLOAD_URL);

    // then
    expect(result).toEqual({ kind: "failed", error: "unreachable" });
  });

  it("시간제한을넘겼을때_올리면_timedOut으로끝나는지", async () => {
    // given
    stubFetch(async () => {
      throw new DOMException("signal timed out", "TimeoutError");
    });
    const port = new BrowserFilePort();
    const [held] = port.hold([pdf()]);

    // when
    const result = await port.upload(held.id, UPLOAD_URL);

    // then
    expect(result).toEqual({ kind: "failed", error: "timedOut" });
  });

  it("쥔적없는이름표일때_올리면_요청없이missingFile로끝나는지", async () => {
    // given
    const fetchMock = stubFetch(async () => new Response(null, { status: 200 }));
    const port = new BrowserFilePort();

    // when
    const result = await port.upload("없는-이름표", UPLOAD_URL);

    // then
    expect(result).toEqual({ kind: "failed", error: "missingFile" });
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("파일을놓은뒤일때_올리면_missingFile로끝나는지", async () => {
    // given
    stubFetch(async () => new Response(null, { status: 200 }));
    const port = new BrowserFilePort();
    const [held] = port.hold([pdf()]);
    port.release(held.id);

    // when
    const result = await port.upload(held.id, UPLOAD_URL);

    // then
    expect(result).toEqual({ kind: "failed", error: "missingFile" });
  });

  it("쥔HTML파일이있을때_글로읽으면_파일내용을돌려주는지", async () => {
    // given
    const port = new BrowserFilePort();
    const [held] = port.hold([new File(["<DL></DL>"], "bookmarks.html", { type: "text/html" })]);

    // when
    const result = await port.readText(held.id);

    // then
    expect(result).toEqual({ kind: "read", text: "<DL></DL>" });
  });

  it("놓은파일일때_글로읽으면_파일없음으로답하는지", async () => {
    // given
    const port = new BrowserFilePort();
    const [held] = port.hold([pdf()]);
    port.release(held.id);

    // when
    const result = await port.readText(held.id);

    // then
    expect(result).toEqual({ kind: "failed", error: "missingFile" });
  });
});
