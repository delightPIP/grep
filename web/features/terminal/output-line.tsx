// 출력 줄 한 줄을 종류(kind)에 따라 lines/의 줄 렌더러로 나눠 그린다.
import { COMMAND_LABEL } from "./format/words";
import { BinListLines, EmptyBinLine } from "./lines/bin";
import { BUNDLE_NAME_RULE, BundleAddedLines, BundleListLines, BundleViewLines } from "./lines/bundle";
import { BinEmptyConfirmLines, BundleDeleteConfirmLines, ConfirmAnswer, DropConfirmLines, HandoffConfirmLines, SignOutEverywhereConfirmLines } from "./lines/confirm";
import { CONNECTION_END_REASON, ConnectionListLines } from "./lines/connection";
import { ItemDetailLines } from "./lines/detail";
import { CommandFailedLines, GuideLines, PICK_EXAMPLE, SamplesSavedLines, UnknownCommandLines, WelcomeLines } from "./lines/guide";
import { HandedOffLines, HandoffFailedLines, PickedLines } from "./lines/handoff";
import { ImportFinishedLines } from "./lines/import";
import { ListLines } from "./lines/list";
import { AlreadySavedLines, RevisedLines, SavedLines, SaveFailedLines } from "./lines/save";
import { NoResultsLines, SavedSearchListLines, saveQueryFor, SearchResultLines, SearchSavedLines } from "./lines/search";
import { CommandChip, Plain } from "./parts";
import type { TerminalLine } from "../../support/view-state";
import { Line, Prompt } from "../../ui/grep";

/** savedInBlock: 같은 블록에 찾아두기 결과(searchSaved)가 있다. 뒤따르는 찾기 결과는 이미 찾아둔 검색어다. */
type OutputLineProps = { line: TerminalLine; failed: boolean; savedInBlock: boolean; onMoreRequested?: () => void };

export function OutputLine({ line, failed, savedInBlock, onMoreRequested }: OutputLineProps) {
  switch (line.kind) {
    case "prompt":
      return <Prompt cmd={line.text} failed={failed} />;
    case "unknownCommand":
      return <UnknownCommandLines name={line.name} suggestion={line.suggestion ?? null} />;
    case "missingArgument":
      // 다른 명령의 빠진 인자 문구는 그 명령의 실행 이슈에서 더한다.
      if (line.command === "keep") return <Line tone="error">저장할 것 없음  예: 담기 https://…</Line>;
      // commands 6절 "빠진 인자".
      if (line.command === "seek") return <Line tone="error">검색어 없음  예: 찾기 결제</Line>;
      // ARC-001 사용자 문구.
      // #154 `고르기 빼기`를 번호 없이 치면 빼기 예시.
      if (line.command === "pick" && line.sub === "unpick") return <Line tone="error">번호 없음  예: 고르기 빼기 131</Line>;
      if (line.command === "pick") return <Line tone="error">번호 없음  예: 고르기 131</Line>;
      // ARC-011 사용자 문구.
      if (line.command === "peek") return <Line tone="error">번호 없음  예: 열기 131</Line>;
      // ARC-012 사용자 문구.
      if (line.command === "gather") return <Line tone="error">검색어 없음  예: 찾아두기 텀블러 캠페인</Line>;
      return null;
    case "missingTag":
      // ARC-002 사용자 문구.
      return <Line tone="error">태그 없음  예: 찾기 #결제</Line>;
    case "saved":
      return <SavedLines item={line.item} />;
    case "alreadySaved":
      return <AlreadySavedLines item={line.item} />;
    case "inTrash":
      return <Line tone="warn">{`휴지통에 있음 → ${line.number}번. 되살리기 ${line.number}`}</Line>;
    case "saveFailed":
      return <SaveFailedLines reason={line.reason} recovery={line.recovery} />;
    case "importSuggest":
      // 제안만 한다. 실수로 수백 건이 들어가지 않게 가져오기는 사용자가 친다(#172).
      return (
        <Plain>
          {"→ 북마크 파일이면: "}
          <CommandChip command="가져오기" />
        </Plain>
      );
    case "recentList":
      // 시점이 없는 `최근`은 머리 줄 없이 목록만(commands 6절). 시점이 있으면 찾기와 같은 머리 줄.
      if (line.period == null) return <ListLines items={line.items} hasMore={line.hasMore} onMoreRequested={onMoreRequested} />;
      return (
        <SearchResultLines
          total={line.total ?? line.items.length}
          items={line.items}
          hasMore={line.hasMore}
          onMoreRequested={onMoreRequested}
          period={line.period}
        />
      );
    case "searchResult":
      return (
        <SearchResultLines
          total={line.total}
          items={line.items}
          hasMore={line.hasMore}
          onMoreRequested={onMoreRequested}
          period={line.period}
          saveQuery={saveQueryFor(line, savedInBlock)}
        />
      );
    case "noResults":
      return <NoResultsLines query={line.query} recent={line.recent} period={line.period} related={line.related} />;
    case "picked":
      return <PickedLines items={line.items} />;
    case "notFound":
      return <Line tone="error">{`없는 번호: ${line.numbers.join(", ")}`}</Line>;
    case "invalidNumber":
      return <Line tone="error">{`잘못된 번호: ${line.input}  예: ${PICK_EXAMPLE}`}</Line>;
    case "handedOff":
      return <HandedOffLines result={line.result} />;
    case "welcome":
      return <WelcomeLines />;
    case "guide":
      return <GuideLines />;
    case "handoffConfirm":
      return <HandoffConfirmLines total={line.total} />;
    case "cancelled":
      // COM-007 사용자 문구.
      return <Line tone="info">취소됨</Line>;
    case "handoffFailed":
      return <HandoffFailedLines reason={line.reason} preview={line.preview} />;
    case "commandFailed":
      return <CommandFailedLines command={line.command} reason={line.reason} retry={line.retry} />;
    case "reconnected":
      return <Line tone="ok">연결됨</Line>;
    case "dropped":
      // ARC-008 사용자 문구. 되살리기는 `<번호...>`를 받으므로 옮긴 번호를 모두 적는다.
      return (
        <Line tone="ok">
          {`휴지통 ${line.items.length}건 (30일 뒤 삭제, 되살리기 ${line.items.map((ref) => ref.number).join(" ")})`}
        </Line>
      );
    case "dropConfirm":
      return <DropConfirmLines total={line.total} />;
    case "binList":
      return (
        <BinListLines total={line.total} items={line.items} hasMore={line.hasMore} onMoreRequested={onMoreRequested} />
      );
    case "binEmptyConfirm":
      return <BinEmptyConfirmLines total={line.total} />;
    case "binEmptied":
      // 빈 휴지통을 비우면 `0건 영구 삭제` 대신 비어 있다고만 알린다(통합 세션 요청, 브라우저 실측).
      if (line.count === 0) return <EmptyBinLine />;
      // ARC-008 사용자 문구.
      return <Line tone="ok">{`비움  ${line.count}건 영구 삭제`}</Line>;
    case "signOutEverywhereConfirm":
      return <SignOutEverywhereConfirmLines connectionCount={line.connectionCount ?? null} />;
    // #124 AI 도구 연결(ACC-002 사용자 문구)
    case "connectionList":
      return <ConnectionListLines mcpUrl={line.mcpUrl} connections={line.connections} />;
    case "disconnectConfirm":
      return (
        <>
          <Line tone="warn">{`끊기? ${line.client} (다시 연결하려면 처음부터)`}</Line>
          <ConfirmAnswer word="끊기" />
        </>
      );
    case "disconnected":
      if (line.already) return <Line tone="warn">{`이미 끊김  ${line.client}`}</Line>;
      return <Line tone="ok">{`끊김  ${line.client}`}</Line>;
    case "connectionNotFound":
      return <Line tone="error">{`없는 연결: ${line.number}`}</Line>;
    case "connectionEnded":
      return (
        <>
          <Line tone="warn">{`연결 끊김: ${line.client} (${CONNECTION_END_REASON[line.reason]})`}</Line>
          <Plain>
            {"→ "}
            <CommandChip command="연결" />
          </Plain>
        </>
      );
    case "unpicked":
      // commands 6절 선택 빼기. 남은 수는 그 시점 값을 줄이 들고 온다(지난 줄이 나중 선택에 따라 바뀌지 않게).
      return <Line tone="ok">{`뺌  선택 ${line.remaining}건 남음`}</Line>;
    case "pickCleared":
      // commands 6절 선택 빼기 "모두 풀면 `✓ 선택 비움`". 건수는 문구에 없다.
      return <Line tone="ok">선택 비움</Line>;
    case "samplesSaved":
      return <SamplesSavedLines firstNumber={line.firstNumber} lastNumber={line.lastNumber} items={line.items} />;
    case "revised":
      return <RevisedLines item={line.item} />;
    case "tagsRemoved":
      // 시안 Edit ③(문구 제안). 지운 태그는 다시 붙지 않는다(ARC-002 규칙 2).
      return <Line tone="ok">{`태그 지움 ${line.tags.map((tag) => `#${tag}`).join(" ")} (${line.item.number}번)`}</Line>;
    case "revived":
      // ARC-008 사용자 문구.
      return <Line tone="ok">{`되살림 ${line.items.length}건`}</Line>;
    // #137 ARC-007 규칙 11: `폴더`·`mkdir` 입력은 없는 명령이 아니라 안내.
    case "folderHint":
      return (
        <Line tone="info">
          {"폴더 없음: 묶음이 폴더 역할  → "}
          <CommandChip command="고르기 ">고르기 &lt;번호&gt;</CommandChip>
          {" · "}
          <CommandChip command="묶음 ">묶음 &lt;이름&gt;</CommandChip>
        </Line>
      );
    // #127 북마크 가져오기(commands 6절). 진행은 뒤에서 이어진다(user-flow 10절)
    case "importPrompt":
      return <Line tone="info">북마크 파일을 끌어다 놓기 (브라우저에서 내보낸 HTML, 한 번에 200건)</Line>;
    case "importProgress":
      return (
        <>
          <Line tone="info">{`가져오는 중  ${line.done} / ${line.total}건`}</Line>
          <Plain dim>{"  다른 명령을 쳐도 계속됨"}</Plain>
        </>
      );
    case "importFinished":
      return (
        <ImportFinishedLines
          saved={line.saved}
          skipped={line.skipped}
          failed={line.failed}
          overLimit={line.overLimit}
          failedUrls={line.failedUrls}
        />
      );
    // #134 찾아두기(ARC-012 사용자 문구)
    case "searchSaved":
      return <SearchSavedLines query={line.query} total={line.total} already={line.already} />;
    case "savedSearchList":
      return <SavedSearchListLines searches={line.searches} />;
    case "savedSearchPeriod":
      return (
        <>
          <Line tone="error">{`시점은 찾아두지 않음: ${line.period}`}</Line>
          <Plain>
            {"→ "}
            <CommandChip command={line.suggestion} />
          </Plain>
        </>
      );
    case "savedSearchTooLong":
      return <Line tone="error">검색어 40자 초과</Line>;
    case "savedSearchDeleteConfirm":
      return (
        <>
          <Line tone="warn">{`지우기? 찾아둔 ${line.query} (자료는 남음)`}</Line>
          <ConfirmAnswer word="지우기" />
        </>
      );
    case "savedSearchDeleted":
      return <Line tone="ok">{`지움  찾아둔 ${line.query}`}</Line>;
    case "savedSearchNotFound":
      return <Line tone="error">{`찾아둔 것 없음: ${line.query}`}</Line>;
    // #131 자세히 보기(ARC-011)
    case "itemDetail":
      return <ItemDetailLines detail={line.detail} />;
    case "oneNumberOnly":
      return <Line tone="error">{`번호 하나만  예: ${COMMAND_LABEL[line.command]} 131`}</Line>;
    // #121 묶음(ARC-003 사용자 문구)
    case "bundleList":
      return <BundleListLines bundles={line.bundles} />;
    case "bundleAdded":
      return <BundleAddedLines name={line.name} count={line.count} alreadyCount={line.alreadyCount} />;
    case "bundleView":
      return (
        <BundleViewLines
          name={line.name}
          total={line.total}
          items={line.items}
          hasMore={line.hasMore}
          onMoreRequested={onMoreRequested}
        />
      );
    case "bundleNotFound":
      return (
        <Line tone="error">
          {`없는 묶음: ${line.name}  → `}
          <CommandChip command="묶음" />
        </Line>
      );
    case "bundleUnpicked":
      return <Line tone="ok">{`뺌  묶음 ${line.name}: ${line.remaining}건 남음`}</Line>;
    case "notInBundle":
      // 없는 번호(notFound)와 같게 쉼표로 잇는다.
      return <Line tone="error">{`묶음에 없음: ${line.numbers.join(", ")}`}</Line>;
    case "bundleDeleteConfirm":
      return <BundleDeleteConfirmLines name={line.name} itemCount={line.itemCount} />;
    case "bundleDeleted":
      return <Line tone="ok">{`삭제됨  묶음 ${line.name}`}</Line>;
    case "bundleNameInvalid":
      return <Line tone="error">{BUNDLE_NAME_RULE[line.reason]}</Line>;
    default:
      // 나머지 줄 종류(#56 계약)는 각 실행 이슈(#58~#68)가 정책 원문으로 그린다.
      return null;
  }
}
