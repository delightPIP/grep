// 고른 테마를 이 브라우저에만 남기고 `<html data-theme>`에 적용한다(COM-012).
// 서버에 올리지 않고, 로그아웃해도 남는다. 남긴 값을 읽지 못하면 시스템 따름이며 오류를 알리지 않는다(규칙 5).

export type Theme = "system" | "light" | "dark";

export const THEME_KEY = "grep.theme";
const THEMES: readonly Theme[] = ["system", "light", "dark"];
const DEFAULT_THEME: Theme = "system";

function isTheme(value: string | null): value is Theme {
  return THEMES.some((theme) => theme === value);
}

/** 남긴 테마. 없거나 모르는 값이거나 저장소가 막혔으면 `system`. */
export function readTheme(): Theme {
  try {
    const stored = localStorage.getItem(THEME_KEY);
    return isTheme(stored) ? stored : DEFAULT_THEME;
  } catch {
    return DEFAULT_THEME;
  }
}

/** 고른 테마를 남긴다. 저장소가 막혔으면 이번 화면에만 적용되고 남지 않는다. */
export function saveTheme(theme: Theme): void {
  try {
    localStorage.setItem(THEME_KEY, theme);
  } catch {
    // 규칙 5: 오류를 알리지 않는다.
  }
}

/** `system`이면 속성을 지워 기기 설정(`prefers-color-scheme`)을 따르게 한다. */
export function applyTheme(theme: Theme, root: HTMLElement = document.documentElement): void {
  if (theme === DEFAULT_THEME) {
    root.removeAttribute("data-theme");
  } else {
    root.dataset.theme = theme;
  }
}

/** 시작할 때 남긴 테마를 적용한다. 로그인 전 화면도 따른다(규칙 4). */
export function applyStoredTheme(root: HTMLElement = document.documentElement): Theme {
  const theme = readTheme();
  applyTheme(theme, root);
  return theme;
}
