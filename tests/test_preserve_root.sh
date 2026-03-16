#!/usr/bin/env bash
set -e

HOOK_FILE="$HOME/.rm-safely"
PASS=0 FAIL=0

ok()   { echo -e "\033[32m[PASS]\033[0m $1"; PASS=$((PASS+1)); }
fail() { echo -e "\033[31m[FAIL]\033[0m $1"; FAIL=$((FAIL+1)); }

check() {
    local desc="$1" pattern="$2"; shift 2
    output=$("$@" 2>&1) || true
    echo "$output" | grep -q "$pattern" && ok "$desc" || fail "$desc: $output"
}

[ -f "$HOOK_FILE" ] || { echo "Run './rm-safely install' first"; exit 1; }
# shellcheck source=/dev/null
source "$HOOK_FILE"

echo "=== Trash mode ==="
check "rm /"                "dangerous" rm /
check "rm -rf /"            "dangerous" rm -rf /
check "rm ///"              "dangerous" rm ///
check "rm /tmp/../../../"   "dangerous" rm /tmp/../../../

echo "=== Bypass mode (--rm) ==="
check "rm --rm -rf /"       "refusing"  rm --rm -rf /
check "rm --rm ///"         "refusing"  rm --rm ///
check "rm --rm /tmp/../../../" "refusing" rm --rm /tmp/../../../

echo "=== Normal operations ==="
D="/tmp/rm-safely-test-$$"
mkdir -p "$D"

echo test > "$D/f.txt"
rm "$D/f.txt"
[ ! -f "$D/f.txt" ] && ok "file trashed" || fail "file not trashed"

mkdir -p "$D/sub"; echo test > "$D/sub/f.txt"
rm -r "$D/sub"
[ ! -d "$D/sub" ] && ok "dir trashed" || fail "dir not trashed"

/bin/rm -rf "$D"

echo ""
echo "Pass: $PASS  Fail: $FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
