// #179 선택 칩·선택 줄의 자료 낱말(ARC-003 규칙 14): `<종류 낱말> <번호>`.
import type { PickedRef } from "./contract";

const EXTENSION = /\.([A-Za-z0-9]+)$/;

/** 링크는 호스트, 글은 `글`, 파일은 확장자 대문자(이미지도 `PNG` 등). */
function kindWord(ref: PickedRef): string {
  switch (ref.kind) {
    case "link":
      // shortcut: 호스트가 없는 링크는 정책에 낱말이 없어 `링크`로 둔다.
      return ref.source || "링크";
    case "text":
      return "글";
    case "file":
      // shortcut: 확장자 없는 파일은 정책에 낱말이 없어 `파일`로 둔다.
      return EXTENSION.exec(ref.title)?.[1].toUpperCase() ?? "파일";
    default:
      // shortcut: M 갈래가 kind를 채우기 전(계약 전 상태)에는 제목을 그대로 쓴다. 통합 뒤 지운다.
      return ref.title;
  }
}

export function pickWord(ref: PickedRef): string {
  return ref.kind === undefined ? ref.title : `${kindWord(ref)} ${ref.number}`;
}

/** `PDF 25 · 글 12 · example.com 3` */
export const pickWords = (refs: readonly PickedRef[]) => refs.map(pickWord).join(" · ");
