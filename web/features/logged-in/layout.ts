// COM-011 폭별 배치. 화면 폭·탭은 뷰 상태다(계약 아님).
import { useEffect, useState } from "react";

export type Layout = "tabs" | "rail" | "sidebar";
export type Tab = "terminal" | "archive" | "settings";

/** COM-011 값: 1008px 이상 사이드바, 600px 이상 레일, 그 아래 하단 탭(MOB-001). */
export const SIDEBAR_MIN_WIDTH = 1008;
export const RAIL_MIN_WIDTH = 600;

export function layoutFor(width: number): Layout {
  if (width >= SIDEBAR_MIN_WIDTH) return "sidebar";
  if (width >= RAIL_MIN_WIDTH) return "rail";
  return "tabs";
}

/** 창 폭을 따라 배치를 고른다. 배치만 바뀌고 화면은 다시 만들지 않는다(COM-011 규칙 5). */
export function useLayout(): Layout {
  const [layout, setLayout] = useState<Layout>(() => layoutFor(window.innerWidth));
  useEffect(() => {
    const update = () => setLayout(layoutFor(window.innerWidth));
    window.addEventListener("resize", update);
    return () => window.removeEventListener("resize", update);
  }, []);
  return layout;
}
