// 터미널 화면. 순수 뷰: 받은 상태만 그리고, 입력은 onInputChange·onSubmit으로만 알린다.
// 배치는 시안 Main·Errors·Logout ③ 아트보드, 출력 비우기(로그아웃·다른 계정 로그인, COM-009)는 코어가 lines로 내려준다.
import type { LoggedInState, TerminalLine } from "../../support/view-state";
import { DockInput, Line, Prompt, StatusBar, Window } from "../../ui/grep";

export type LoggedInViewProps = LoggedInState & {
  onInputChange: (text: string) => void;
  onSubmit: (text: string) => void;
};

const HELP_HINT = { key: "?", label: "도움말" };

/** 명령 한 번 = 블록 하나(디자인 시스템 1절 원칙 2). 입력줄(prompt)마다 새 블록을 연다. */
function toBlocks(lines: TerminalLine[]): TerminalLine[][] {
  const blocks: TerminalLine[][] = [];
  for (const line of lines) {
    if (line.kind === "prompt" || blocks.length === 0) blocks.push([line]);
    else blocks[blocks.length - 1].push(line);
  }
  return blocks;
}

/** 창 제목은 마지막에 친 명령 이름, 아무것도 안 쳤으면 `처음`(시안 Main·Logout ③④). */
function windowTitle(lines: TerminalLine[]): string {
  const prompts = lines.filter((line) => line.kind === "prompt");
  const last = prompts[prompts.length - 1];
  return last?.text.trim().split(/\s+/)[0] || "처음";
}

function Block({ lines }: { lines: TerminalLine[] }) {
  const failed = lines.some((line) => line.kind === "unknownCommand");
  return (
    <div className="gt-block">
      {lines.map((line, index) =>
        line.kind === "prompt" ? (
          <Prompt key={index} cmd={line.text} failed={failed} />
        ) : (
          <Line key={index} tone="error">
            <b>없는 명령:</b> {line.name}
          </Line>
        ),
      )}
    </div>
  );
}

export function LoggedInView({ itemCount, lines, input, onInputChange, onSubmit }: LoggedInViewProps) {
  return (
    <main className="gt-screen">
      <Window
        title={windowTitle(lines)}
        status={<StatusBar items={[{ label: "자료", value: itemCount }]} hint={HELP_HINT} />}
      >
        {toBlocks(lines).map((block, index) => (
          <Block key={index} lines={block} />
        ))}
        <DockInput
          value={input}
          placeholder="링크 붙여 넣기 또는 명령"
          onChange={onInputChange}
          onSubmit={onSubmit}
        />
      </Window>
    </main>
  );
}
