import { act, cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { Burrow, MOLE_PALETTE, type MoleAction } from "./burrow";

beforeEach(() => {
  vi.useFakeTimers();
});

afterEach(() => {
  cleanup();
  vi.useRealTimers();
  vi.unstubAllGlobals();
});

function renderBurrow(action: MoleAction, actionKey = 1) {
  const view = render(<Burrow action={action} actionKey={actionKey} start={0.14} />);
  return {
    ...view,
    replay: (next: MoleAction, key: number) => view.rerender(<Burrow action={next} actionKey={key} start={0.14} />),
  };
}

const mole = () => screen.getByRole("button", { name: "두더지 누르기" });
const frame = (container: HTMLElement) => container.querySelector(".gt-burrow-body")?.getAttribute("data-frame");
const mark = (container: HTMLElement) => container.querySelector(".gt-burrow-mark")?.getAttribute("data-mark") ?? null;
const docClass = (container: HTMLElement) => container.querySelector(".gt-burrow-doc")?.className ?? null;
const leftPercent = () => parseFloat(mole().style.left);

function wait(ms: number) {
  act(() => {
    vi.advanceTimersByTime(ms);
  });
}

function reduceMotion() {
  vi.stubGlobal("matchMedia", (query: string) => ({ matches: query.includes("reduce"), media: query }));
}

describe("Burrow 땅굴 두더지(#175, 디자인 시스템 9절·시안 08)", () => {
  it("찾기를_틀었을때_끝까지_기다리면_반대편에서_문서를_들고_느낌표와_나오는지", () => {
    // given
    const { container } = renderBurrow("seek");

    // when
    wait(1910);

    // then
    expect(leftPercent()).toBe(86);
    expect(frame(container)).toBe("hold");
    expect(mark(container)).toBe("bang");
    wait(1100);
    expect(frame(container)).toBe("up");
    expect(mark(container)).toBeNull();
  });

  it("끌어_오기를_틀었을때_잠시_뒤면_가운데서_만세하는지", () => {
    // given
    const { container } = renderBurrow("dragover");

    // when
    wait(320);

    // then
    expect(leftPercent()).toBe(50);
    expect(frame(container)).toBe("catch");
    expect(mole().classList.contains("is-cheer")).toBe(true);
  });

  it("저장을_틀었을때_끝까지_기다리면_문서를_받아_묻고_다시_서는지", () => {
    // given
    const { container } = renderBurrow("save");

    // when
    wait(520);

    // then
    expect(docClass(container)).toContain("gt-fall");
    wait(420);
    expect(docClass(container)).toBeNull();
    expect(frame(container)).toBe("hold");
    wait(1220);
    expect(frame(container)).toBe("up");
    expect(container.querySelector(".gt-burrow-body")?.getAttribute("style")).toContain("translateY(0%)");
  });

  it("넘기기를_틀었을때_잠시_뒤면_문서가_날아가고_사라지는지", () => {
    // given
    const { container } = renderBurrow("handoff");

    // when
    wait(260);

    // then
    expect(docClass(container)).toContain("gt-fly");
    wait(760);
    expect(docClass(container)).toBeNull();
  });

  it("틀림을_틀었을때_고개를_흔들며_물음표가_뜨고_끝나면_멈추는지", () => {
    // given
    const { container } = renderBurrow("error");

    // when
    wait(0);

    // then
    expect(mole().classList.contains("is-shake")).toBe(true);
    expect(mark(container)).toBe("ask");
    wait(760);
    expect(mole().classList.contains("is-shake")).toBe(false);
    expect(mark(container)).toBeNull();
  });

  it("두더지를_눌렀을때_끝까지_기다리면_다른_곳에서_나오는지", () => {
    // given
    renderBurrow("idle");
    wait(0);

    // when
    fireEvent.click(mole());
    wait(1590);

    // then
    expect(Math.abs(leftPercent() - 14)).toBeGreaterThanOrEqual(30);
  });

  it("가만히_있을때_시간이_지나면_눈을_깜빡였다_뜨는지", () => {
    // given
    const { container } = renderBurrow("idle");

    // when
    wait(3400);

    // then
    expect(frame(container)).toBe("blink");
    wait(140);
    expect(frame(container)).toBe("up");
  });

  it("같은_동작인데_순번이_바뀌었을때_다시_하는지", () => {
    // given
    const { replay } = renderBurrow("error", 1);
    wait(800);
    expect(mole().classList.contains("is-shake")).toBe(false);

    // when
    replay("error", 2);
    wait(0);

    // then
    expect(mole().classList.contains("is-shake")).toBe(true);
  });

  it("움직임을_줄이는_설정일때_찾기를_틀면_기본_모습_그대로인지", () => {
    // given
    reduceMotion();
    const { container } = renderBurrow("seek");

    // when
    wait(5000);
    fireEvent.click(mole());
    wait(2000);

    // then
    expect(leftPercent()).toBe(14);
    expect(frame(container)).toBe("up");
    expect(mark(container)).toBeNull();
  });

  it("어느_테마에서_그려도_두더지_색은_전용_팔레트인지", () => {
    // given
    const palette = new Set(Object.values(MOLE_PALETTE));

    // when
    const { container } = render(
      <div data-theme="light">
        <Burrow action="idle" actionKey={1} />
      </div>,
    );

    // then
    const fills = Array.from(container.querySelectorAll("rect"), (rect) => rect.getAttribute("fill"));
    expect(fills.length).toBeGreaterThan(0);
    expect(fills.every((fill) => fill !== null && palette.has(fill))).toBe(true);
  });
});
