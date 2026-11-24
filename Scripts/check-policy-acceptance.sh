#!/usr/bin/env bash
# 멀티 플랫폼 클라이언트 정책 합격 기준 및 경계값 어설션 감사 템플릿 (docs 플러그인 번들 스크립트)
#
# 단위 테스트가 단순 통과 개수만 채우지 않고 docs/policies/의
# 필수 경계값·예외·표준 문구를 실제로 어설션(#expect / XCTAssert / expect)하고 있는지 기계적으로 교차 검증한다.
#
# 정책(SSOT) 변경 동기화 규칙 (Closed-Loop):
#   docs/policies/의 경계값·예외·표준 문구가 추가/변경되면 본 스크립트의 *_rules도 같은 PR에서 반드시 함께 갱신한다.

set -euo pipefail

ROOT_DIR="${1:-$(git rev-parse --show-toplevel 2>/dev/null || (cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd))}"

PYTHON=""
for candidate in python3 python; do
  if command -v "$candidate" >/dev/null 2>&1 \
    && "$candidate" -c 'import sys; sys.exit(0 if sys.version_info[0] >= 3 else 1)' >/dev/null 2>&1; then
    PYTHON="$candidate"
    break
  fi
done

if [ -z "$PYTHON" ]; then
  echo "오류: 실행 가능한 python3를 찾을 수 없습니다." >&2
  exit 2
fi

PYTHONIOENCODING=utf-8 "$PYTHON" - "$ROOT_DIR" <<'PY'
import glob
import os
import re
import sys

for stream in (sys.stdout, sys.stderr):
    if hasattr(stream, "reconfigure"):
        stream.reconfigure(encoding="utf-8")

root = sys.argv[1]
violations = []
audited_platforms = []


def check_invariants(platform, module_name, combined_text, rules):
    for label, pattern in rules:
        if not re.search(pattern, combined_text, re.MULTILINE | re.DOTALL):
            violations.append(
                f"[{platform} / {module_name}] 필수 정책 경계값/어설션 누락: {label} (패턴: {pattern})"
            )


# 프로젝트의 플랫폼별 테스트 디렉터리에 맞게 아래 규칙(rules)을 추가·갱신하세요.
# 규칙을 넣을 때 audited_platforms.append(...)도 함께 호출해야 "검사함"으로 집계됩니다.
# 예:
# apple_tests_dir = os.path.join(root, "Apps", "Apple", "Projects", "Core", "Domain", "Tests")
# if os.path.isdir(apple_tests_dir):
#     audited_platforms.append("Apple")
#     apple_tests = "\n".join(open(p, encoding="utf-8").read() for p in sorted(glob.glob(os.path.join(apple_tests_dir, "*.swift"))))
#     check_invariants("Apple", "정책 도메인", apple_tests, [
#         ("경계값 설명", r"정규식_패턴"),
#     ])

if violations:
    for v in violations:
        print(f"✖ {v}", file=sys.stderr)
    print(f"\n정책 합격 기준 감사 실패 (총 {len(violations)}건 누락)", file=sys.stderr)
    sys.exit(1)

if not audited_platforms:
    # 규칙이 하나도 없으면 검사한 것이 없다. 통과로 보고하지 않는다(커밋은 막지 않도록 exit 0).
    print("⚠ 정책 합격 기준 감사: 등록된 규칙이 없어 검사한 항목이 없습니다. Scripts/check-policy-acceptance.sh에 규칙을 추가하세요.")
    sys.exit(0)

print(f"✔ 정책 합격 기준 및 경계값 어설션 감사 통과 (대상: {', '.join(audited_platforms)}, 누락 0건)")
PY
