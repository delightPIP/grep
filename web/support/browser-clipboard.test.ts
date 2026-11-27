import { afterEach, describe, expect, it, vi } from "vitest";
import { browserClipboard } from "./browser-clipboard";

afterEach(() => vi.unstubAllGlobals());

describe("브라우저 클립보드", () => {
  it("브라우저가허락할때_글을넣으면_copied로끝나고그글이들어가는지", async () => {
    // given
    const writeText = vi.fn(async () => {});
    vi.stubGlobal("navigator", { clipboard: { writeText } });

    // when
    const result = await browserClipboard.copy("넘길 글");

    // then
    expect(result).toBe("copied");
    expect(writeText).toHaveBeenCalledWith("넘길 글");
  });

  it("브라우저가막았을때_글을넣으면_denied로끝나는지", async () => {
    // given
    const writeText = vi.fn(async () => {
      throw new DOMException("denied", "NotAllowedError");
    });
    vi.stubGlobal("navigator", { clipboard: { writeText } });

    // when
    const result = await browserClipboard.copy("넘길 글");

    // then
    expect(result).toBe("denied");
  });

  it("클립보드가없는브라우저일때_글을넣으면_denied로끝나는지", async () => {
    // given
    vi.stubGlobal("navigator", {});

    // when
    const result = await browserClipboard.copy("넘길 글");

    // then
    expect(result).toBe("denied");
  });
});
