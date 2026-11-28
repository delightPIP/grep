// 명령 이름·실패 이유 낱말.
import type { CommandFailure, CommandName } from "../../../support/view-state";

/** 화면에 찍는 명령 이름(commands 2절). */
export const COMMAND_LABEL: Record<CommandName, string> = {
  keep: "담기",
  recent: "최근",
  seek: "찾기",
  pick: "고르기",
  handoff: "넘기기",
  guide: "도움말",
  about: "설명",
  signOut: "로그아웃",
  revise: "고치기",
  drop: "버리기",
  revive: "되살리기",
  bin: "휴지통",
  pack: "묶음",
  peek: "열기",
  gather: "찾아두기",
  bring: "가져오기",
  plug: "연결",
};

/** COM-010·COM-008 이유 낱말. */
export const COMMAND_FAILURE_LABEL: Record<CommandFailure, string> = {
  disconnected: "연결 끊김",
  timedOut: "응답 없음",
  serverError: "서버 오류",
  clipboardDenied: "클립보드 거부",
};
