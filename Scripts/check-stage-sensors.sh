#!/bin/bash
# 문서 및 워크플로 게이트 센서 (docs 플러그인 — Inspired by awslabs/aidlc-workflows Sensors)
#
#   1. no-tbd (blocking):
#      검사 대상 문서에 미결 표기(TBD, TODO, FIXME, 추후 결정, 미정)나 HTML 주석 자리표시가
#      남아 있으면 실패(exit 1)한다. README.md, open-questions.md, 추가 전용 기록인
#      ai-usage/log/ 는 검사하지 않는다.
#   2. upstream-coverage (blocking):
#      상위 문서(--upstream 지정 문서, .agents/flow/*/spec.md, docs/PRD.md, docs/POLICY.md)에 적힌
#      식별자(US-1, ARC-001, ADR-0001 형식)가 하위 문서(--target, tickets.md, SPEC.md)에 인용됐는지
#      검사해 증발한 요구사항(Orphan Requirement)을 적발한다. 식별자가 없는 상위 문서는 검사할 것이 없다.
#   3. claim-sources:
#      명세서(spec.md/SPEC.md)에 근거 태그([Policy: ...], [ADR: ...], [Code: ...], [User], [Docs: ...])나
#      정책·ADR 번호가 하나도 없으면 권고(--strict 이면 blocking)한다.
#      AI 활용 로그(ai-usage/log/NNN-*.md)에 '## 검증', '## 사람의 판단' 섹션이 없으면 blocking.
#
# 종료 코드: 0 통과, 1 위반(blocking), 2 실행 환경 오류 또는 검사 대상 없음(잘못된 옵션·경로 포함)
# 사용법:
#   bash Scripts/check-stage-sensors.sh [루트 경로] [--target <파일또는폴더>] [--upstream <상위파일>] [--strict]

set -u

ROOT="."
TARGET=""
UPSTREAM=""
STRICT=0

while [ $# -gt 0 ]; do
    case "$1" in
        --target|--upstream)
            if [ $# -lt 2 ]; then
                echo "오류: $1 옵션에는 값이 필요함" >&2
                exit 2
            fi
            if [ "$1" = "--target" ]; then TARGET="$2"; else UPSTREAM="$2"; fi
            shift 2
            ;;
        --strict)
            STRICT=1
            shift
            ;;
        -*)
            echo "오류: 알 수 없는 옵션: $1 (사용 가능: --target, --upstream, --strict)" >&2
            exit 2
            ;;
        *)
            ROOT="$1"
            shift
            ;;
    esac
done

PYTHON=""
for candidate in python3 python; do
    if command -v "$candidate" >/dev/null 2>&1 \
        && "$candidate" -c 'import sys; sys.exit(0 if sys.version_info[0] >= 3 else 1)' >/dev/null 2>&1; then
        PYTHON="$candidate"
        break
    fi
done
if [ -z "$PYTHON" ]; then
    echo "오류: 실행 가능한 python3(또는 python)를 찾을 수 없어 센서를 실행할 수 없음"
    exit 2
fi

PYTHONIOENCODING=utf-8 "$PYTHON" - "$ROOT" "$TARGET" "$UPSTREAM" "$STRICT" <<'PY'
import glob, json, os, re, sys

for stream in (sys.stdout, sys.stderr):
    if hasattr(stream, "reconfigure"):
        stream.reconfigure(encoding="utf-8")

root = os.path.abspath(sys.argv[1])
target_arg = sys.argv[2]
upstream_arg = sys.argv[3]
strict = sys.argv[4] == "1"

blocking_findings = []
advisory_findings = []

if not os.path.isdir(root):
    print(f"오류: 루트 경로가 없음: {root}")
    sys.exit(2)

def rel(path):
    try:
        return os.path.relpath(path, root).replace(os.sep, "/")
    except ValueError:
        return path.replace(os.sep, "/")

def read(path):
    with open(path, encoding="utf-8-sig") as f:
        return f.read()

def strip_fenced_code(text):
    """코드 블록 안의 예시 TBD/TODO는 실제 미결 항목이 아니므로 줄 수만 유지한 채 비운다."""
    lines = text.splitlines()
    out = []
    in_fence = False
    fence_marker = ""
    for line in lines:
        stripped = line.lstrip()
        m = re.match(r"^(`{3,}|~{3,})", stripped)
        if m:
            marker = m.group(1)[0]
            if not in_fence:
                in_fence = True
                fence_marker = marker
            elif stripped.startswith(fence_marker * 3):
                in_fence = False
                fence_marker = ""
            out.append("")
            continue
        out.append("" if in_fence else line)
    return out

# 1. 검사 대상 파일 수집
files = []
if target_arg:
    tpath = os.path.abspath(os.path.join(root, target_arg)) if not os.path.isabs(target_arg) else target_arg
    if os.path.isfile(tpath):
        files.append(tpath)
    elif os.path.isdir(tpath):
        files.extend(sorted(glob.glob(os.path.join(tpath, "**", "*.md"), recursive=True)))
    else:
        print(f"오류: --target 경로가 없음: {tpath}")
        sys.exit(2)
else:
    for d in ("docs", "Docs"):
        dpath = os.path.join(root, d)
        if os.path.isdir(dpath):
            files.extend(sorted(glob.glob(os.path.join(dpath, "**", "*.md"), recursive=True)))
    flow_dir = os.path.join(root, ".agents", "flow")
    if os.path.isdir(flow_dir):
        files.extend(sorted(glob.glob(os.path.join(flow_dir, "**", "*.md"), recursive=True)))

# README 템플릿 안내 및 open-questions.md는 TBD/빈 표 허용 예외
SKIP_BASENAMES = {"open-questions.md"}
files = [f for f in files if os.path.basename(f) not in SKIP_BASENAMES and os.path.isfile(f)]

# 대소문자를 구분하지 않는 파일 시스템(Windows, macOS)에서는 docs 와 Docs 가 같은 폴더라 두 번 잡힌다.
seen = set()
unique_files = []
for f in files:
    key = os.path.normcase(os.path.realpath(f))
    if key not in seen:
        seen.add(key)
        unique_files.append(f)
files = unique_files

if not files:
    print("오류: 검사할 마크다운 파일이 없음 (통과가 아니라 미검사)")
    sys.exit(2)

def is_ai_log(path):
    return re.search(r"ai-usage[\\/]log[\\/]", path) is not None

# ==========================================
# Sensor 1: no-tbd (Blocking)
# ==========================================
TBD_PATTERN = re.compile(r"(?<![A-Za-z0-9_-])(TBD|TODO|FIXME)(?![A-Za-z0-9_-])|추후\s*결정|미정(?!의)")
COMMENT_PLACEHOLDER = re.compile(r"<!--\s*(?!learned\b).*?-->")

for fpath in files:
    rpath = rel(fpath)
    # README.md 내 틀(Template) 안내는 제외
    if os.path.basename(fpath) == "README.md":
        continue
    # AI 활용 로그는 추가 전용 기록이다. 과거 항목에 적힌 "TODO"가 게이트를 영구히 막지 않게 한다.
    if is_ai_log(fpath):
        continue
    raw = read(fpath)
    clean_lines = strip_fenced_code(raw)
    for idx, line in enumerate(clean_lines, start=1):
        # 마크다운 인라인 코드(`TBD`) 제거 후 검사
        no_inline = re.sub(r"`[^`]*`", "", line)
        m = TBD_PATTERN.search(no_inline)
        if m:
            blocking_findings.append(f"[no-tbd] {rpath}:{idx}: 미결 표기('{m.group(0)}')가 남아 있음")
        if COMMENT_PLACEHOLDER.search(no_inline):
            blocking_findings.append(f"[no-tbd] {rpath}:{idx}: 제거되지 않은 템플릿 HTML 주석이 남아 있음")

# ==========================================
# Sensor 2: upstream-coverage
# ==========================================
ID_PATTERN = re.compile(r"\b(US-\d+|ADR-(?:[A-Z]{2,5}-)?\d{3,4}|[A-Z]{2,4}-\d{3})\b")

# 문서 식별자처럼 보이지만 알고리즘·표준 이름인 것(SHA-256, AES-256 등)은 요구사항 ID가 아니다.
NON_ID_PREFIXES = {"SHA", "AES", "RSA", "UTF", "ISO", "RFC", "TLS", "HTTP", "MD", "CRC"}

def requirement_ids(text):
    return sorted({i for i in ID_PATTERN.findall(text) if i.split("-")[0] not in NON_ID_PREFIXES})

checked_pairs = set()

def check_pair_coverage(up_path, down_path):
    if not (os.path.isfile(up_path) and os.path.isfile(down_path)):
        return
    pair = (os.path.normcase(os.path.realpath(up_path)), os.path.normcase(os.path.realpath(down_path)))
    if pair in checked_pairs:
        return
    checked_pairs.add(pair)
    up_text = "\n".join(strip_fenced_code(read(up_path)))
    down_text = read(down_path)
    up_ids = requirement_ids(up_text)
    missing = [uid for uid in up_ids if uid not in down_text]
    if missing:
        msg = f"[upstream-coverage] {rel(down_path)}: 상위 문서({rel(up_path)})의 식별자 누락 -> {', '.join(missing)}"
        blocking_findings.append(msg)

if upstream_arg and target_arg:
    up_full = os.path.abspath(os.path.join(root, upstream_arg)) if not os.path.isabs(upstream_arg) else upstream_arg
    down_full = os.path.abspath(os.path.join(root, target_arg)) if not os.path.isabs(target_arg) else target_arg
    check_pair_coverage(up_full, down_full)
else:
    # .agents/flow/<intent>/ 내부의 spec.md -> issues.md (또는 구버전 tickets.md) 자동 대조
    flow_root = os.path.join(root, ".agents", "flow")
    if os.path.isdir(flow_root):
        for intent_dir in sorted(glob.glob(os.path.join(flow_root, "*"))):
            if os.path.isdir(intent_dir):
                check_pair_coverage(os.path.join(intent_dir, "spec.md"), os.path.join(intent_dir, "issues.md"))
                check_pair_coverage(os.path.join(intent_dir, "spec.md"), os.path.join(intent_dir, "tickets.md"))
    # team-workflow: docs/PRD.md & docs/POLICY.md -> docs/SPEC.md 대조
    for d in ("docs", "Docs"):
        prd_p = os.path.join(root, d, "PRD.md")
        pol_p = os.path.join(root, d, "POLICY.md")
        spec_p = os.path.join(root, d, "SPEC.md")
        check_pair_coverage(prd_p, spec_p)
        check_pair_coverage(pol_p, spec_p)

# ==========================================
# Sensor 3: claim-sources
# ==========================================
SOURCE_TAG = re.compile(r"\[(Policy|ADR|Code|User|Docs)\s*:|\b(ADR-(?:[A-Z]{2,5}-)?\d{3,4}|[A-Z]{2,4}-\d{3})\b")

for fpath in files:
    rpath = rel(fpath)
    bname = os.path.basename(fpath)
    raw = read(fpath)
    if bname in ("spec.md", "SPEC.md"):
        if not SOURCE_TAG.search(raw):
            msg = f"[claim-sources] {rpath}: 명세서에 근거 출처 태그([Policy: ID], [ADR: ID], [Code: path], [User])가 하나도 없음"
            if strict:
                blocking_findings.append(msg)
            else:
                advisory_findings.append(msg)
    elif re.search(r"ai-usage[\\/]log[\\/]\d{3}-", fpath):
        if not re.search(r"^## 검증\s*$", raw, re.MULTILINE):
            msg = f"[claim-sources] {rpath}: AI 활용 로그에 '## 검증' 섹션이 누락됨"
            blocking_findings.append(msg)
        if not re.search(r"^## 사람의 판단\s*$", raw, re.MULTILINE):
            msg = f"[claim-sources] {rpath}: AI 활용 로그에 '## 사람의 판단' 섹션이 누락됨"
            blocking_findings.append(msg)

# 결과 출력
if blocking_findings:
    print("❌ [Stage Sensors: BLOCKED] 다음 결정론적 센서 위반을 해결해야 게이트를 통과할 수 있습니다:")
    for item in blocking_findings:
        print(f"  - {item}")
if advisory_findings:
    print("⚠️ [Stage Sensors: ADVISORY] 권고 사항:")
    for item in advisory_findings:
        print(f"  - {item}")

if not blocking_findings and not advisory_findings:
    print(f"✅ [Stage Sensors: PASSED] 검사 완료 ({len(files)}개 파일, 위반 0건)")

sys.exit(1 if blocking_findings else 0)
PY
