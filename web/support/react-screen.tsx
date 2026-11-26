import type { ReactNode } from "react";
import { createRoot, type Root } from "react-dom/client";

/**
 * 브리지 프로토콜의 `mount`/`render`를 React 루트에 잇는다.
 * Swift는 화면 종류마다 뷰 객체 하나에 화면 여러 개를 차례로 맡긴다.
 * 새 화면이 `mount`되면 앞 화면의 루트를 내리고, `render`는 가장 최근 화면에 그린다.
 */
export class ReactScreen<Handle> {
  #current: { root: Root; handle: Handle } | null = null;

  mount(host: Element, handle: Handle): void {
    this.#current?.root.unmount();
    this.#current = { root: createRoot(host), handle };
  }

  render(draw: (handle: Handle) => ReactNode): void {
    if (!this.#current) return;
    const { root, handle } = this.#current;
    root.render(draw(handle));
  }
}
