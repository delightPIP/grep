import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { HISTORY_KEY, localHistoryStore } from "./local-history-store";

beforeEach(() => localStorage.clear());
afterEach(() => vi.restoreAllMocks());

describe("localStorage 기록 저장소", () => {
  it("기록을남겼을때_다시읽으면_같은계정과본문을돌려주는지", () => {
    // given
    localHistoryStore.save({ subject: "user-a", payload: '{"version":1}' });

    // when
    const record = localHistoryStore.load();

    // then
    expect(record).toEqual({ subject: "user-a", payload: '{"version":1}' });
  });

  it("남긴기록이없을때_읽으면_null인지", () => {
    // given: 빈 저장소

    // when
    const record = localHistoryStore.load();

    // then
    expect(record).toBeNull();
  });

  it("기록을남겼을때_지우면_읽을것이없는지", () => {
    // given
    localHistoryStore.save({ subject: "user-a", payload: "{}" });

    // when
    localHistoryStore.clear();

    // then
    expect(localHistoryStore.load()).toBeNull();
    expect(localStorage.getItem(HISTORY_KEY)).toBeNull();
  });

  it.each(["{broken", '"글"', '{"subject":"user-a"}', '{"subject":1,"payload":"{}"}'])(
    "모양이다른값이들어있을때_읽으면_null인지: %s",
    (stored) => {
      // given
      localStorage.setItem(HISTORY_KEY, stored);

      // when
      const record = localHistoryStore.load();

      // then
      expect(record).toBeNull();
    },
  );

  it("저장소가꽉찼을때_기록을남기면_던지지않고경고만남기는지", () => {
    // given
    vi.spyOn(Storage.prototype, "setItem").mockImplementation(() => {
      throw new DOMException("full", "QuotaExceededError");
    });
    const warn = vi.spyOn(console, "warn").mockImplementation(() => {});

    // when
    const save = () => localHistoryStore.save({ subject: "user-a", payload: "{}" });

    // then
    expect(save).not.toThrow();
    expect(warn).toHaveBeenCalledOnce();
  });

  it("저장소를읽을수없을때_읽으면_던지지않고null인지", () => {
    // given
    vi.spyOn(Storage.prototype, "getItem").mockImplementation(() => {
      throw new DOMException("blocked", "SecurityError");
    });
    vi.spyOn(console, "warn").mockImplementation(() => {});

    // when
    const record = localHistoryStore.load();

    // then
    expect(record).toBeNull();
  });
});
