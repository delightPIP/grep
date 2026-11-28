// 땅굴 두더지(디자인 시스템 9절 `Burrow`, 시안 08 두더지 동작·07 직접 쳐 보기).
// 시안 아티팩트 project/ds/grep/components/bundle.js `Burrow`의 그림·순서·클래스 이름을 옮겼다.
// 두더지 색은 테마와 상관없이 같다(전용 팔레트). 움직임을 줄이는 설정이면 기본 모습만 보인다.
import { useEffect, useRef, useState, type CSSProperties, type ReactNode } from "react";
import "../styles/grep.css";

/** 일곱 동작. dragover·poke·idle은 뷰가 스스로 정하고, 나머지는 코어가 화면 상태 `mole`로 넘긴다. */
export type MoleAction = "idle" | "seek" | "dragover" | "save" | "handoff" | "error" | "poke";

/** 두더지 전용 팔레트(시안 MOLE_PAL). */
export const MOLE_PALETTE: Record<string, string> = {
  M: "#4a4460", R: "#6a4228", h: "#f5c9a3", m: "#6c6585", o: "#16120f", q: "#99a2ad",
  r: "#8a5a3a", s: "#f2a0a8", w: "#fbfbf8", y: "#f2c86b",
};

type Frame = "up" | "blink" | "catch" | "hold" | "give";

// 땅 위로 나온 두더지(16x16). 시안 MOLE_ACT.
const FRAMES: Record<Frame, string[]> = {
  up: ["................", "................", "................", "................", ".....oooooo.....", "....ommmmmmo....", "...ommmmmmmmo...", "...omommmmomo...", "..ommomssmommo..", "..ommmssssmmmo..", "..ohhmmmmmmhho..", ".ohhhmmMMmmhhho.", ".ommmmMMMMmmmmo.", "..ommmmmmmmmmo..", "..ommmmmmmmmmo..", "...oooooooooo..."],
  blink: ["................", "................", "................", "................", ".....oooooo.....", "....ommmmmmo....", "...ommmmmmmmo...", "...ommmmmmmmo...", "..omoomssmoomo..", "..ommmssssmmmo..", "..ohhmmmmmmhho..", ".ohhhmmMMmmhhho.", ".ommmmMMMMmmmmo.", "..ommmmmmmmmmo..", "..ommmmmmmmmmo..", "...oooooooooo..."],
  catch: ["................", "................", "................", ".oo..........oo.", "ohho.oooooo.ohho", "ohhoommmmmmoohho", ".ohommmmmmmmoho.", "..ohmommmmomho..", "..ommomssmommo..", "..ommmssssmmmo..", "..ommmmmmmmmmo..", "..ommmmMMmmmmo..", "..ommmMMMMmmmo..", "..ommmmmmmmmmo..", "..ommmmmmmmmmo..", "...oooooooooo..."],
  hold: ["................", "................", "................", "................", ".....oooooo.....", "....ommmmmmo....", "...ommmmmmmmo...", "...omommmmomo...", "..ommomssmommo..", "..ommmoooommmo..", "..ohhmowwomhho..", ".ohhhmoqqomhhho.", ".ommmmowwommmmo.", "..ommmoooommmo..", "..ommmmmmmmmmo..", "...oooooooooo..."],
  give: ["................", "................", "................", "................", ".....oooooo.....", "....ommmmmmo....", "...ommmmmmmmo...", "...omommmmomo...", "..ommomssmomoooo", "..ommmssssmmowwo", "..ohhmmmmmmhoqqo", ".ohhhmmMMmmhowwo", ".ommmmMMMMmmoooo", "..ommmmmmmmmmo..", "..ommmmmmmmmmo..", "...oooooooooo..."],
};

type Mark = "bang" | "ask";

const SPRITES = {
  mound: ["......rrrr......", "....rrRrrrrr....", "..rrrrrrrRrrrr..", ".rRrrrrrrrrrrRr."],
  bang: [".ooo.", ".oyo.", ".oyo.", ".oyo.", ".ooo.", ".oyo.", ".ooo."],
  ask: [".ooo.", "oyyyo", "o.oyo", "..oyo", ".oyo.", ".ooo.", ".oyo.", ".ooo."],
  doc: ["oooo", "owwo", "oqqo", "owwo", "oooo"],
};

/** 글자 그림 한 장을 같은 색이 이어진 가로 칸 단위의 사각형으로 바꾼다. `.`은 빈칸. */
export function pixelRects(rows: readonly string[]): ReactNode[] {
  return rows.flatMap((row, y) => {
    const rects: ReactNode[] = [];
    let x = 0;
    while (x < row.length) {
      const ch = row.charAt(x);
      let width = 1;
      while (x + width < row.length && row.charAt(x + width) === ch) width++;
      if (ch !== ".") rects.push(<rect key={`${y}-${x}`} x={x} y={y} width={width} height={1} fill={MOLE_PALETTE[ch]} />);
      x += width;
    }
    return rects;
  });
}

function Pixels({ rows, px }: { rows: readonly string[]; px: number }) {
  const width = rows[0].length;
  return (
    <svg viewBox={`0 0 ${width} ${rows.length}`} width={width * px} height={rows.length * px} shapeRendering="crispEdges" aria-hidden="true">
      {pixelRects(rows)}
    </svg>
  );
}

type Scene = {
  /** 땅 위 가로 위치(0~1). */
  x: number;
  /** 0이면 땅 위, 1이면 땅속. */
  depth: 0 | 1;
  frame: Frame;
  /** 땅속을 지나는 흙 둔덕의 가로 위치. 없으면 null. */
  mound: number | null;
  mark: Mark | null;
  doc: "fall" | "fly" | null;
  /** 흙 튀김을 다시 틀 때마다 1씩 는다. */
  dust: number;
  shake: boolean;
  cheer: boolean;
};

type Step = [delay: number, change: Partial<Scene> | ((scene: Scene) => Partial<Scene>)];

const BLINK_EVERY_MS = 3400;
const BLINK_FOR_MS = 140;
const CENTER = 0.5;
const SEEK_LEFT = 0.14;
const SEEK_RIGHT = 0.86;
/** 누르면 지금 자리에서 이만큼은 떨어진 곳에서 나온다. */
const POKE_MIN_JUMP = 0.3;

function prefersReducedMotion(): boolean {
  return typeof window.matchMedia === "function" && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
}

const atCenter = (scene: Scene) => scene.depth === 0 && Math.abs(scene.x - CENTER) < 0.02;

/** 파고 들어가 땅속으로 target까지 가서 나온다. */
function dig(from: number, target: number): Step[] {
  return [
    [0, { frame: "blink", cheer: false, mark: null }],
    [120, (scene) => ({ depth: 1, dust: scene.dust + 1 })],
    [320, { mound: from }],
    [60, { mound: target }],
    [1050, { x: target, mound: null, frame: "up" }],
    [40, { depth: 0 }],
  ];
}

/** 쏙 들어갔다 x에서 나온다. */
function popAt(x: number, frame: Frame): Step[] {
  return [
    [0, { depth: 1, mark: null }],
    [280, { x, frame }],
    [40, { depth: 0 }],
  ];
}

function pokeTarget(from: number): number {
  let next = from;
  for (let tries = 0; Math.abs(next - from) < POKE_MIN_JUMP && tries < 20; tries++) next = 0.1 + Math.random() * 0.8;
  return next;
}

function stepsFor(action: MoleAction, scene: Scene): Step[] {
  switch (action) {
    case "seek": {
      const target = scene.x < CENTER ? SEEK_RIGHT : SEEK_LEFT;
      return [...dig(scene.x, target), [320, { frame: "hold", mark: "bang" }], [1100, { frame: "up", mark: null }]];
    }
    case "dragover":
      return atCenter(scene) ? [[0, { frame: "catch", cheer: true }]] : [...popAt(CENTER, "catch"), [0, { cheer: true }]];
    case "save": {
      const lead: Step[] = atCenter(scene) ? [[0, { frame: "catch" }]] : popAt(CENTER, "catch");
      return [
        ...lead,
        [200, { doc: "fall", cheer: false }],
        [420, { doc: null, frame: "hold" }],
        [500, { frame: "blink" }],
        [120, (now) => ({ depth: 1, dust: now.dust + 1 })],
        [520, { frame: "up" }],
        [80, { depth: 0 }],
      ];
    }
    case "handoff":
      return [[0, { frame: "give" }], [260, { doc: "fly", frame: "up" }], [760, { doc: null }]];
    case "error":
      return [[0, { frame: "blink", mark: "ask", shake: true }], [760, { shake: false, mark: null, frame: "up" }]];
    case "poke":
      return dig(scene.x, pokeTarget(scene.x));
    case "idle":
      return [[0, { frame: "up" }]];
  }
}

const RESET: Partial<Scene> = { doc: null, mound: null, shake: false, mark: null, cheer: false, depth: 0 };

export type BurrowProps = {
  action: MoleAction;
  /** 바뀌면 같은 동작도 처음부터 다시 한다. */
  actionKey: number;
  /** 두더지 한 변(px). 16의 배수. */
  size?: number;
  /** 처음 가로 위치(0~1). */
  start?: number;
  label?: string;
};

export function Burrow({ action, actionKey, size = 48, start = SEEK_LEFT, label = "그렙 두더지" }: BurrowProps) {
  const px = size / 16;
  const [scene, setScene] = useState<Scene>({
    x: start, depth: 0, frame: "up", mound: null, mark: null, doc: null, dust: 0, shake: false, cheer: false,
  });
  const sceneRef = useRef(scene);
  sceneRef.current = scene;
  const timers = useRef<ReturnType<typeof setTimeout>[]>([]);

  function clearTimers() {
    timers.current.forEach(clearTimeout);
    timers.current = [];
  }

  function play(next: MoleAction) {
    if (prefersReducedMotion()) return;
    clearTimers();
    let at = 0;
    for (const [delay, change] of [[0, RESET] as Step, ...stepsFor(next, sceneRef.current)]) {
      at += delay;
      timers.current.push(
        setTimeout(() => setScene((prev) => ({ ...prev, ...(typeof change === "function" ? change(prev) : change) })), at),
      );
    }
  }

  useEffect(() => {
    play(action);
    // actionKey가 같은 동작을 다시 틀게 한다. play는 매번 새로 만들어지지만 sceneRef만 읽는다.
  }, [action, actionKey]);

  // 가만히 서 있으면 가끔 눈을 깜빡인다.
  useEffect(() => {
    const id = setInterval(() => {
      const now = sceneRef.current;
      if (now.frame !== "up" || now.depth !== 0 || now.mark || prefersReducedMotion()) return;
      setScene((prev) => ({ ...prev, frame: "blink" }));
      timers.current.push(setTimeout(() => setScene((prev) => (prev.frame === "blink" ? { ...prev, frame: "up" } : prev)), BLINK_FOR_MS));
    }, BLINK_EVERY_MS);
    return () => {
      clearInterval(id);
      clearTimers();
    };
  }, []);

  const left = `${scene.x * 100}%`;
  const moleClass = ["gt-burrow-mole", scene.shake && "is-shake", scene.cheer && "is-cheer"].filter(Boolean).join(" ");
  return (
    <div className="gt-burrow" style={{ "--b-size": `${size}px` } as CSSProperties} role="group" aria-label={label}>
      <div className="gt-burrow-sky">
        {scene.mark && (
          <span key={`m${scene.mark}${scene.x}`} className="gt-burrow-mark" data-mark={scene.mark} style={{ left }}>
            <Pixels rows={SPRITES[scene.mark]} px={px} />
          </span>
        )}
        {scene.doc && (
          <span className={`gt-burrow-doc gt-${scene.doc}`} style={{ left }}>
            <Pixels rows={SPRITES.doc} px={px} />
          </span>
        )}
        {scene.mound !== null && (
          <span className="gt-burrow-mound" style={{ left: `${scene.mound * 100}%` }}>
            <Pixels rows={SPRITES.mound} px={px} />
          </span>
        )}
        <span key={`d${scene.dust}`} className={scene.dust ? "gt-burrow-dust is-on" : "gt-burrow-dust"} style={{ left }} aria-hidden="true">
          <i /><i /><i /><i />
        </span>
        <button type="button" className={moleClass} style={{ left }} aria-label="두더지 누르기" onClick={() => play("poke")}>
          <span className="gt-burrow-body" data-frame={scene.frame} style={{ transform: `translateY(${scene.depth * 100}%)` }}>
            <Pixels rows={FRAMES[scene.frame]} px={px} />
          </span>
        </button>
      </div>
      <div className="gt-burrow-ground" aria-hidden="true" />
    </div>
  );
}
