#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON_BIN="${SCRIPT_DIR}/.venv/bin/python3"

MODE="${1:-}"
shift || true

REPORT_PATH=""
TASK_ID=""
FROM_AGENT="gunshi"
ESCALATE=false
PROJECT_DIR="$SCRIPT_DIR"
TYPECHECK_CMD=""
TEST_CMD=""
ESLINT_CMD=""
PR_NUMBER=""
YAML_FILE=""
OUTPUT_FILE=""
VERCEL_STATUS=""

usage() {
    cat <<'EOF'
Usage:
  bash scripts/qc_validate.sh report --report <path> [--task-id <id>] [--escalate] [--from <agent>]
  bash scripts/qc_validate.sh repo [options]

Repo options:
  --project-dir <dir>
  --typecheck-cmd <cmd>
  --test-cmd <cmd>
  --eslint-cmd <cmd>
  --pr <number>
  --yaml <path>
  --output <path>
  --vercel-status <READY|BUILDING|ERROR>
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --report) REPORT_PATH="$2"; shift 2 ;;
        --task-id) TASK_ID="$2"; shift 2 ;;
        --from) FROM_AGENT="$2"; shift 2 ;;
        --project-dir) PROJECT_DIR="$2"; shift 2 ;;
        --typecheck-cmd) TYPECHECK_CMD="$2"; shift 2 ;;
        --test-cmd) TEST_CMD="$2"; shift 2 ;;
        --eslint-cmd) ESLINT_CMD="$2"; shift 2 ;;
        --pr) PR_NUMBER="$2"; shift 2 ;;
        --yaml) YAML_FILE="$2"; shift 2 ;;
        --output) OUTPUT_FILE="$2"; shift 2 ;;
        --vercel-status) VERCEL_STATUS="$2"; shift 2 ;;
        --escalate) ESCALATE=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
done

if [[ -z "$MODE" ]]; then
    usage
    exit 1
fi

declare -i FAIL_COUNT=0
declare -i WARN_COUNT=0
declare -i PASS_COUNT=0
declare -a RESULTS=()
AMBIGUOUS_HIT=0

record() {
    local id="$1" status="$2" detail="$3"
    RESULTS+=("${id}|${status}|${detail}")
    case "$status" in
        PASS|N/A) PASS_COUNT+=1 ;;
        WARN|CONDITIONAL) WARN_COUNT+=1 ;;
        FAIL) FAIL_COUNT+=1 ;;
    esac
}

run_optional() {
    local label="$1" cmd="$2"
    if [[ -z "$cmd" ]]; then
        echo "__NA__"
        return 0
    fi
    if bash -lc "cd \"$PROJECT_DIR\" && $cmd" >/tmp/qc_validate.$$."$label".log 2>&1; then
        echo "__PASS__"
    else
        cat /tmp/qc_validate.$$."$label".log >&2 || true
        echo "__FAIL__"
    fi
}

scan_pattern() {
    local file="$1" pattern="$2"
    if rg -qi "$pattern" "$file"; then
        return 0
    fi
    return 1
}

escalate_to_shogun() {
    local reason="$1"
    local detail="$2"
    local message
    message=$'【QCエスカレーション】\n'"task_id: ${TASK_ID:-unknown}"$'\n'"判定: CONDITIONAL PASS"$'\n'"理由: ${reason}"$'\n'"詳細: ${detail}"$'\n'"確認依頼: 将軍のご判断をお願いしたし。"
    bash "$SCRIPT_DIR/scripts/inbox_write.sh" shogun "$message" escalation "$FROM_AGENT"
}

report_mode() {
    if [[ -z "$REPORT_PATH" || ! -f "$REPORT_PATH" ]]; then
        echo "report mode requires --report <path>" >&2
        exit 1
    fi

    scan_pattern "$REPORT_PATH" 'overall[[:space:]]*:[[:space:]]*(PASS|FAIL|CONDITIONAL PASS)' \
        && record R1 PASS "overall verdict found" \
        || record R1 FAIL "overall verdict missing"

    scan_pattern "$REPORT_PATH" 'purpose verdict[[:space:]]*:[[:space:]]*(PASS|FAIL)' \
        && record R2 PASS "purpose verdict found" \
        || record R2 FAIL "purpose verdict missing"

    if rg -q 'AC[0-9]+: (PASS|FAIL)|- .*(PASS|FAIL)' "$REPORT_PATH"; then
        record R3 PASS "acceptance criteria verdicts found"
    else
        record R3 FAIL "acceptance criteria verdicts missing"
    fi

    if scan_pattern "$REPORT_PATH" '未検証|unverified|TODO|TBD'; then
        record R4 FAIL "unverified marker found"
    else
        record R4 PASS "no unverified markers"
    fi

    if scan_pattern "$REPORT_PATH" '許容|CONDITIONAL|概ね|暫定|ただし'; then
        AMBIGUOUS_HIT=1
        record R5 CONDITIONAL "ambiguous wording requires escalation"
    else
        record R5 PASS "no ambiguous wording"
    fi

    if [[ "$AMBIGUOUS_HIT" -eq 1 && "$ESCALATE" == true ]]; then
        escalate_to_shogun "曖昧判定を検知" "$REPORT_PATH"
    fi
}

repo_mode() {
    local result

    result=$(run_optional typecheck "$TYPECHECK_CMD")
    [[ "$result" == "__PASS__" ]] && record S1 PASS "typecheck passed"
    [[ "$result" == "__FAIL__" ]] && record S1 FAIL "typecheck failed"
    [[ "$result" == "__NA__" ]] && record S1 N/A "typecheck command not provided"

    if [[ -n "$TEST_CMD" ]]; then
        local test_log="/tmp/qc_validate.$$.tests.log"
        if bash -lc "cd \"$PROJECT_DIR\" && $TEST_CMD" >"$test_log" 2>&1; then
            if rg -qi '\bSKIP(PED)?\b|pending' "$test_log"; then
                record S2 FAIL "test output contains SKIP"
            else
                record S2 PASS "tests passed without SKIP"
            fi
        else
            cat "$test_log" >&2 || true
            record S2 FAIL "tests failed"
        fi
    else
        record S2 N/A "test command not provided"
    fi

    if [[ -z "$(git -C "$PROJECT_DIR" status --porcelain)" ]]; then
        record S3 PASS "git worktree clean"
    else
        record S3 FAIL "uncommitted changes present"
    fi

    if [[ -n "$PR_NUMBER" ]] && command -v gh >/dev/null 2>&1; then
        local repo
        repo="$(gh pr view "$PR_NUMBER" --json baseRepositoryOwner --jq '.baseRepositoryOwner.login' 2>/dev/null || true)"
        [[ "$repo" == "higaTousan" ]] && record S4 PASS "PR target is origin owner"
        [[ "$repo" != "higaTousan" ]] && record S4 FAIL "PR target is not higaTousan"
    else
        record S4 N/A "PR number or gh unavailable"
    fi

    if [[ -n "$YAML_FILE" ]]; then
        if [[ -x "$PYTHON_BIN" ]] && "$PYTHON_BIN" -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))" "$YAML_FILE" >/dev/null 2>&1; then
            record S5 PASS "yaml parsed"
        else
            record S5 FAIL "yaml parse failed"
        fi
    else
        record S5 N/A "yaml file not provided"
    fi

    if [[ -n "$OUTPUT_FILE" ]]; then
        if [[ -s "$OUTPUT_FILE" ]]; then
            record S6 PASS "output file exists and non-empty"
        else
            record S6 FAIL "output file missing or empty"
        fi
    else
        record S6 N/A "output file not provided"
    fi

    if [[ -n "$VERCEL_STATUS" ]]; then
        [[ "$VERCEL_STATUS" == "READY" ]] && record S7 PASS "vercel preview ready"
        [[ "$VERCEL_STATUS" != "READY" ]] && record S7 FAIL "vercel preview not ready"
    else
        record S7 N/A "vercel status not provided"
    fi

    result=$(run_optional eslint "$ESLINT_CMD")
    [[ "$result" == "__PASS__" ]] && record S8 PASS "eslint passed"
    [[ "$result" == "__FAIL__" ]] && record S8 FAIL "eslint failed"
    [[ "$result" == "__NA__" ]] && record S8 N/A "eslint command not provided"

    if git -C "$PROJECT_DIR" remote -v | awk '$1=="upstream" && $3=="(push)" {print $2}' | grep -qx 'no_push_allowed'; then
        record S9 PASS "upstream push locked"
    else
        record S9 FAIL "upstream push URL is not locked"
    fi

    if [[ -f "$PROJECT_DIR/queue/postmortems/ACTIVE_PATTERNS.md" ]]; then
        record S10 PASS "ACTIVE_PATTERNS.md exists"
    else
        record S10 FAIL "ACTIVE_PATTERNS.md missing"
    fi

    if git -C "$PROJECT_DIR" diff --cached --name-only HEAD 2>/dev/null | rg -q '(^|/)\.env|\.pem$|\.key$'; then
        record S11 FAIL "sensitive file pattern detected in staged files"
    else
        record S11 PASS "no sensitive file pattern in staged files"
    fi

    if git -C "$PROJECT_DIR" diff --cached --numstat HEAD 2>/dev/null | awk '$1 > 1024 {found=1} END{exit !found}'; then
        record S12 FAIL "large staged file detected"
    else
        record S12 PASS "no oversized staged file"
    fi

    if [[ -n "$REPORT_PATH" ]] && rg -o 'https?://[^ )]+' "$REPORT_PATH" >/tmp/qc_validate.$$.urls 2>/dev/null; then
        if [[ ! -s /tmp/qc_validate.$$.urls ]]; then
            record S13 N/A "no urls in report"
        else
            local url_fail=0
            while IFS= read -r url; do
                curl -Is --max-time 10 "$url" >/dev/null || url_fail=1
            done </tmp/qc_validate.$$.urls
            [[ "$url_fail" -eq 0 ]] && record S13 PASS "report urls reachable"
            [[ "$url_fail" -eq 1 ]] && record S13 FAIL "report contains unreachable url"
        fi
    else
        record S13 N/A "report path not provided for url check"
    fi

    if find "$PROJECT_DIR/scripts" -name '*.sh' -print0 2>/dev/null | xargs -0 -I{} bash -n "{}"; then
        record S14 PASS "shell syntax valid"
    else
        record S14 FAIL "shell syntax error detected"
    fi

    if git -C "$PROJECT_DIR" diff --cached HEAD 2>/dev/null | rg -qi 'api[_-]?key|secret|password|token'; then
        record S15 FAIL "possible secret detected in staged diff"
    else
        record S15 PASS "no secret-like token in staged diff"
    fi
}

case "$MODE" in
    report) report_mode ;;
    repo) repo_mode ;;
    *)
        echo "Unknown mode: $MODE" >&2
        usage
        exit 1
        ;;
esac

for entry in "${RESULTS[@]}"; do
    IFS='|' read -r id status detail <<<"$entry"
    printf '%s\t%s\t%s\n' "$id" "$status" "$detail"
done

if [[ "$FAIL_COUNT" -gt 0 ]]; then
    printf 'OVERALL\tFAIL\t%d fail(s), %d warning(s)\n' "$FAIL_COUNT" "$WARN_COUNT"
    exit 1
fi

if [[ "$WARN_COUNT" -gt 0 ]]; then
    printf 'OVERALL\tCONDITIONAL PASS\t0 fail(s), %d warning(s)\n' "$WARN_COUNT"
    exit 0
fi

printf 'OVERALL\tPASS\t%d check(s) passed\n' "$PASS_COUNT"
