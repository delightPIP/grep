// 연결 줄 렌더러.
import { connectionDay } from "../format/date";
import { CommandChip, Plain } from "../parts";
import type { ConnectionEntry } from "../../../support/view-state";
import { Line } from "../../../ui/grep";

/** ACC-002 규칙 7·10 `연결`: 연결 주소 안내 두 줄, 그 아래 연결 목록. 읽은 적 없는 연결은 `읽음` 칸을 뺀다. */
export function ConnectionListLines({ mcpUrl, connections }: { mcpUrl: string; connections: ConnectionEntry[] }) {
  return (
    <>
      <Line tone="info">{`연결 주소  ${mcpUrl}`}</Line>
      <Plain dim>{"  AI 도구의 연결(MCP) 설정에 이 주소를 넣고 그렙 계정으로 로그인. 연결한 도구는 검색·읽기만 가능"}</Plain>
      {connections.length === 0 ? (
        <Line tone="info">연결 0개</Line>
      ) : (
        <>
          <Plain>{`${connections.length}개 연결`}</Plain>
          {connections.map((connection) => (
            <div key={connection.number} className="gt-line gt-name-row">
              <span className="gt-row-num">{connection.number}</span>
              <span>{connection.client}</span>
              <span className="gt-hint">{`연결 ${connectionDay(connection.connectedAt)}`}</span>
              {connection.lastReadAt !== null && <span className="gt-hint">{`읽음 ${connectionDay(connection.lastReadAt)}`}</span>}
            </div>
          ))}
          <Plain>
            {"→ "}
            <CommandChip command="연결 끊기 ">연결 끊기 &lt;번호&gt;</CommandChip>
          </Plain>
        </>
      )}
    </>
  );
}

/** ACC-002 규칙 11 연결이 끝난 이유. revoked 낱말은 정책에 없어 계약 설명(다른 기기에서 끊음·모든 기기 로그아웃)에서 줄였다. */
export const CONNECTION_END_REASON = { expired: "로그인 만료", revoked: "다른 기기에서 끊음" } as const;
