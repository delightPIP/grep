// 명령 한 번의 출력 블록.
import { OutputLine } from "./output-line";
import type { TerminalLine } from "../../support/view-state";

export function Block({ lines, onMoreRequested }: { lines: TerminalLine[]; onMoreRequested?: () => void }) {
  const failed = lines.some((line) => line.kind === "unknownCommand");
  const savedInBlock = lines.some((line) => line.kind === "searchSaved");
  return (
    <div className="gt-block">
      {lines.map((line, index) => (
        <OutputLine key={index} line={line} failed={failed} savedInBlock={savedInBlock} onMoreRequested={onMoreRequested} />
      ))}
    </div>
  );
}
