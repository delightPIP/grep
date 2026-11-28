// #179 선택 칩·선택 줄의 자료 낱말(ARC-003 규칙 14): `<종류 낱말> <번호>`.
import type { ItemRef } from "../../../support/view-state";

const EXTENSION = /\.([A-Za-z0-9]+)$/;

/** 링크는 호스트, 글은 `글`, 파일은 확장자 대문자(이미지도 `PNG` 등). */
function kindWord(ref: ItemRef): string {
  switch (ref.kind) {
    case "link":
      // shortcut: 호스트가 없는 링크는 정책에 낱말이 없어 `링크`로 둔다.
      return ref.source || "링크";
    case "text":
      return "글";
    case "file":
      // 파일의 source는 형식(확장자). 없으면 제목의 확장자.
      // shortcut: 둘 다 없는 파일은 정책에 낱말이 없어 `파일`로 둔다.
      return (ref.source || EXTENSION.exec(ref.title)?.[1])?.toUpperCase() ?? "파일";
  }
}

export function pickWord(ref: ItemRef): string {
  return `${kindWord(ref)} ${ref.number}`;
}

/** `PDF 25 · 글 12 · example.com 3` */
export const pickWords = (refs: readonly ItemRef[]) => refs.map(pickWord).join(" · ");
