// 크기 형식(MB, 글자 수).
const BYTES_PER_MB = 1024 * 1024;

export function megabytes(bytes: number): string {
  return `${Math.round((bytes / BYTES_PER_MB) * 10) / 10}MB`;
}

export const charCountText = (count: number) => `${count.toLocaleString("ko-KR")}자`;
