import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

// jsdom은 CSS 미디어 쿼리를 계산하지 않는다. 그래서 스타일 원문으로 규칙을 확인한다.
const read = (path: string) => readFileSync(resolve(__dirname, path), "utf-8");

/** `selector { ... }` 블록 안의 `--이름: 값` 쌍. */
function variables(css: string, selector: string): Record<string, string> {
  const start = css.indexOf(selector);
  if (start < 0) return {};
  const body = css.slice(css.indexOf("{", start) + 1, css.indexOf("}", start));
  return Object.fromEntries(Array.from(body.matchAll(/(--[\w-]+):\s*([^;]+);/g), (match) => [match[1], match[2].trim()]));
}

describe("밝은 테마(#169, 디자인 시스템 토큰 두 테마·시안 06)", () => {
  it("시스템이_밝은_테마일때_고른_테마가_없으면_밝은_토큰을_그대로_쓰는지", () => {
    // given
    const light = variables(read("../styles/tokens.css"), '[data-theme="light"]');

    // when
    const followed = variables(read("../styles/grep.css"), ':root:not([data-theme="dark"])');

    // then
    expect(Object.keys(light).length).toBeGreaterThan(0);
    expect(followed).toEqual(light);
    expect(read("../styles/grep.css")).toMatch(/@media \(prefers-color-scheme: light\) \{\s*:root:not\(\[data-theme="dark"\]\)/);
  });

  it("처음_열었을때_어두운_테마로_못박지_않고_두_테마를_알리는지", () => {
    // given
    const html = read("../index.html");

    // when
    const htmlTag = /<html[^>]*>/.exec(html)?.[0] ?? "";

    // then
    expect(htmlTag).not.toContain("data-theme");
    expect(html).toContain('<meta name="color-scheme" content="dark light"');
  });
});
