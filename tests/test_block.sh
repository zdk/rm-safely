#!/usr/bin/env bash

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_FILE="$HOME/.rm-safely"
BLOCK_FILE="$HOME/.rm-safely-block"
TEST_DIR="/tmp/rm-safely-block-test-$$"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

print_scenario() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}SCENARIO: $1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_test() {
    echo -e "${YELLOW}[TEST]${NC} $1"
    TESTS_RUN=$((TESTS_RUN + 1))
}

print_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

print_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

# Backup and clean state
backup_block=""
if [ -f "$BLOCK_FILE" ]; then
    backup_block=$(cat "$BLOCK_FILE")
fi
/bin/rm -f "$BLOCK_FILE"

# Install and source
bash "$SCRIPT_DIR/../rm-safely" install >/dev/null 2>&1 || true
# shellcheck source=/dev/null
source "$HOOK_FILE"

mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1

# ==========================================
print_scenario "rm -b (add protection)"
# ==========================================

print_test "Protect a path"
output=$(rm -b "$TEST_DIR")
if echo "$output" | grep -q "Protected:"; then
    print_pass "Path protected"
else
    print_fail "Should print Protected message"
fi

print_test "Path is written to block file"
if [ -f "$BLOCK_FILE" ] && command grep -q "$TEST_DIR" "$BLOCK_FILE"; then
    print_pass "Path found in block file"
else
    print_fail "Path should be in block file"
fi

print_test "Protect multiple paths at once"
mkdir -p "$TEST_DIR/multi_a" "$TEST_DIR/multi_b"
output=$(rm -b "$TEST_DIR/multi_a" "$TEST_DIR/multi_b")
if echo "$output" | grep -q "Protected:.*multi_a" && echo "$output" | grep -q "Protected:.*multi_b"; then
    print_pass "Multiple paths protected"
else
    print_fail "Should protect both paths"
fi

print_test "Duplicate protection shows Already protected"
output=$(rm -b "$TEST_DIR")
if echo "$output" | grep -q "Already protected:"; then
    print_pass "Duplicate detected"
else
    print_fail "Should show Already protected"
fi

# ==========================================
print_scenario "rm -b --list"
# ==========================================

print_test "List shows protected paths"
output=$(rm -b --list)
if echo "$output" | grep -q "Protected paths:" && echo "$output" | grep -q "$TEST_DIR"; then
    print_pass "List shows paths"
else
    print_fail "Should list protected paths"
fi

print_test "List with no arg (bare -b) also lists"
output=$(rm -b)
if echo "$output" | grep -q "Protected paths:"; then
    print_pass "Bare -b lists paths"
else
    print_fail "Bare -b should list paths"
fi

print_test "List when no paths protected shows message"
/bin/rm -f "$BLOCK_FILE"
output=$(rm -b --list)
if echo "$output" | grep -q "No protected paths"; then
    print_pass "Empty list handled"
else
    print_fail "Should show No protected paths"
fi

# ==========================================
print_scenario "rm -b --remove"
# ==========================================

# Re-add for remove tests
rm -b "$TEST_DIR" >/dev/null 2>&1

print_test "Remove protection from a path"
output=$(rm -b --remove "$TEST_DIR")
if echo "$output" | grep -q "Unprotected:"; then
    print_pass "Path unprotected"
else
    print_fail "Should show Unprotected message"
fi

print_test "Path is removed from block file"
if [ ! -f "$BLOCK_FILE" ] || ! command grep -q "$TEST_DIR" "$BLOCK_FILE"; then
    print_pass "Path removed from file"
else
    print_fail "Path should be removed from block file"
fi

print_test "Remove non-existent path shows Not found"
output=$(rm -b --remove "/nonexistent/path/xyz")
if echo "$output" | grep -q "Not found:"; then
    print_pass "Not found handled"
else
    print_fail "Should show Not found"
fi

print_test "Remove with no arg shows usage"
output=$(rm -b --remove 2>&1) || true
if echo "$output" | grep -q "Usage:"; then
    print_pass "Usage shown"
else
    print_fail "Should show usage"
fi

print_test "Remove when no block file shows No protected paths"
/bin/rm -f "$BLOCK_FILE"
output=$(rm -b --remove "$TEST_DIR" 2>&1) || true
if echo "$output" | grep -q "No protected paths"; then
    print_pass "No file handled"
else
    print_fail "Should show No protected paths"
fi

# ==========================================
print_scenario "rm -b --help and unknown flags"
# ==========================================

print_test "--help shows usage"
output=$(rm -b --help)
if echo "$output" | grep -q "Usage:" && echo "$output" | grep -q "rm -b"; then
    print_pass "Help shown"
else
    print_fail "Should show help"
fi

print_test "Unknown flag returns error"
output=$(rm -b --bogus 2>&1) || true
if echo "$output" | grep -q "Unknown option:"; then
    print_pass "Unknown option handled"
else
    print_fail "Should show Unknown option"
fi

# ==========================================
print_scenario "Protection blocks rm (trash path)"
# ==========================================

/bin/rm -f "$BLOCK_FILE"
echo "protected content" > "$TEST_DIR/protected_file.txt"
rm -b "$TEST_DIR/protected_file.txt" >/dev/null 2>&1

print_test "rm on protected file is blocked"
output=$(rm "$TEST_DIR/protected_file.txt" 2>&1) || true
if echo "$output" | grep -q "is protected"; then
    print_pass "Protected file blocked"
else
    print_fail "Should block deletion of protected file"
fi

print_test "Protected file still exists"
if [ -f "$TEST_DIR/protected_file.txt" ]; then
    print_pass "File still exists"
else
    print_fail "Protected file should still exist"
fi

print_test "rm on subdirectory of protected path is blocked"
rm -b --remove "$TEST_DIR/protected_file.txt" >/dev/null 2>&1
rm -b "$TEST_DIR" >/dev/null 2>&1
echo "sub content" > "$TEST_DIR/subfile.txt"
output=$(rm "$TEST_DIR/subfile.txt" 2>&1) || true
if echo "$output" | grep -q "is protected"; then
    print_pass "Subdirectory file blocked"
else
    print_fail "Should block files under protected directory"
fi

print_test "Block message suggests rm -b --remove"
if echo "$output" | grep -q "rm -b --remove"; then
    print_pass "Message suggests unprotect command"
else
    print_fail "Should suggest rm -b --remove"
fi

# ==========================================
print_scenario "Protection blocks rm -rf"
# ==========================================

print_test "rm -rf on protected directory is blocked"
output=$(rm -rf "$TEST_DIR" 2>&1) || true
if echo "$output" | grep -q "is protected"; then
    print_pass "rm -rf blocked"
else
    print_fail "Should block rm -rf on protected dir"
fi

print_test "Protected directory still exists"
if [ -d "$TEST_DIR" ]; then
    print_pass "Directory still exists"
else
    print_fail "Protected directory should still exist"
fi

# ==========================================
print_scenario "--rm bypasses protection"
# ==========================================

echo "bypass content" > "$TEST_DIR/bypass_file.txt"
rm -b "$TEST_DIR/bypass_file.txt" >/dev/null 2>&1

print_test "--rm bypasses protection"
# shellcheck disable=SC2216
echo "yes" | rm --rm "$TEST_DIR/bypass_file.txt" >/dev/null 2>&1
if [ ! -f "$TEST_DIR/bypass_file.txt" ]; then
    print_pass "--rm bypassed protection"
else
    print_fail "--rm should bypass protection"
fi

rm -b --remove "$TEST_DIR/bypass_file.txt" >/dev/null 2>&1

# ==========================================
print_scenario "Symlink-aware protection"
# ==========================================

rm -b --remove "$TEST_DIR" >/dev/null 2>&1
/bin/rm -f "$BLOCK_FILE"

mkdir -p "$TEST_DIR/real_dir"
ln -sf "$TEST_DIR/real_dir" "$TEST_DIR/symlink_dir"

rm -b "$TEST_DIR/symlink_dir" >/dev/null 2>&1

print_test "Duplicate detected via real path (added via symlink)"
output=$(rm -b "$TEST_DIR/real_dir" 2>&1)
if echo "$output" | grep -q "Already protected:"; then
    print_pass "Symlink-aware duplicate detection"
else
    print_fail "Should detect duplicate via resolved path"
fi

print_test "Remove via real path when added via symlink"
output=$(rm -b --remove "$TEST_DIR/real_dir" 2>&1)
if echo "$output" | grep -q "Unprotected:"; then
    print_pass "Symlink-aware removal"
else
    print_fail "Should remove via resolved path"
fi

/bin/rm -f "$TEST_DIR/symlink_dir"
/bin/rm -rf "$TEST_DIR/real_dir"

# ==========================================
print_scenario "Never file with comments and blank lines"
# ==========================================

/bin/rm -f "$BLOCK_FILE"
cat > "$BLOCK_FILE" <<EOF
# This is a comment
$TEST_DIR/commented_test

# Another comment

EOF

print_test "List skips comments and blank lines"
output=$(rm -b --list)
if echo "$output" | grep -q "commented_test" && ! echo "$output" | grep -q "#"; then
    print_pass "Comments and blanks skipped in list"
else
    print_fail "Should skip comments and blank lines"
fi

print_test "is_blocked skips comments"
echo "content" > "$TEST_DIR/commented_test"
output=$(rm "$TEST_DIR/commented_test" 2>&1) || true
if echo "$output" | grep -q "is protected"; then
    print_pass "is_blocked works with comments in file"
else
    print_fail "Should still protect paths despite comments"
fi

# ==========================================
print_scenario "Unprotect then delete"
# ==========================================

/bin/rm -f "$BLOCK_FILE"
echo "delete me" > "$TEST_DIR/unprotect_then_delete.txt"
rm -b "$TEST_DIR/unprotect_then_delete.txt" >/dev/null 2>&1

print_test "File is blocked while protected"
output=$(rm "$TEST_DIR/unprotect_then_delete.txt" 2>&1) || true
if echo "$output" | grep -q "is protected"; then
    print_pass "Blocked while protected"
else
    print_fail "Should be blocked"
fi

print_test "File can be trashed after unprotect"
rm -b --remove "$TEST_DIR/unprotect_then_delete.txt" >/dev/null 2>&1
rm "$TEST_DIR/unprotect_then_delete.txt" 2>&1
if [ ! -f "$TEST_DIR/unprotect_then_delete.txt" ]; then
    print_pass "File trashed after unprotect"
else
    print_fail "Should be trashable after unprotect"
fi

# ==========================================
print_scenario "resolve_path edge cases"
# ==========================================

/bin/rm -f "$BLOCK_FILE"

print_test "Protect with relative path"
mkdir -p "$TEST_DIR/reltest"
cd "$TEST_DIR" || exit 1
rm -b reltest >/dev/null 2>&1
output=$(rm -b --list)
if echo "$output" | grep -q "$TEST_DIR/reltest"; then
    print_pass "Relative path resolved to absolute"
else
    print_fail "Should resolve relative path"
fi
rm -b --remove "$TEST_DIR/reltest" >/dev/null 2>&1

print_test "Protect path with trailing slash"
rm -b "$TEST_DIR/reltest/" >/dev/null 2>&1
output=$(rm -b --list)
if echo "$output" | grep -q "$TEST_DIR/reltest"; then
    print_pass "Trailing slash handled"
else
    print_fail "Should handle trailing slash"
fi
rm -b --remove "$TEST_DIR/reltest" >/dev/null 2>&1

print_test "Protect path with /. and .."
rm -b "$TEST_DIR/reltest/../reltest/./." >/dev/null 2>&1
output=$(rm -b --list)
if echo "$output" | grep -q "$TEST_DIR/reltest"; then
    print_pass "Dot segments resolved"
else
    print_fail "Should resolve /. and .."
fi
rm -b --remove "$TEST_DIR/reltest" >/dev/null 2>&1

# ==========================================
print_scenario "Zsh compatibility"
# ==========================================

if command -v zsh >/dev/null 2>&1; then
    /bin/rm -f "$BLOCK_FILE"

    print_test "Full flow in zsh: add, list, block, remove, delete"
    zsh_output=$(zsh -c "
source \"$HOOK_FILE\"
mkdir -p \"$TEST_DIR/zsh_test\"
echo 'zsh content' > \"$TEST_DIR/zsh_test/file.txt\"

# Add
rm -b \"$TEST_DIR/zsh_test\"

# List
rm -b --list

# Block
rm \"$TEST_DIR/zsh_test/file.txt\" 2>&1 || true

# Remove protection
rm -b --remove \"$TEST_DIR/zsh_test\"

# Delete should now work
rm \"$TEST_DIR/zsh_test/file.txt\" 2>&1

# List should be empty
rm -b --list
" 2>&1)

    if echo "$zsh_output" | grep -q "Protected:" && \
       echo "$zsh_output" | grep -q "Protected paths:" && \
       echo "$zsh_output" | grep -q "is protected" && \
       echo "$zsh_output" | grep -q "Unprotected:" && \
       echo "$zsh_output" | grep -q "No protected paths"; then
        print_pass "Full zsh flow works"
    else
        print_fail "Zsh flow failed. Output: $zsh_output"
    fi

    print_test "zsh: PATH not corrupted after rm -b"
    zsh_output=$(zsh -c "
source \"$HOOK_FILE\"
rm -b \"$TEST_DIR/zsh_path_test\" 2>/dev/null
echo \"PATH_OK=\$(command -v grep >/dev/null 2>&1 && echo yes || echo no)\"
" 2>&1)

    if echo "$zsh_output" | grep -q "PATH_OK=yes"; then
        print_pass "PATH preserved in zsh (no path variable clobbering)"
    else
        print_fail "PATH corrupted in zsh"
    fi

    /bin/rm -f "$BLOCK_FILE"
else
    echo -e "${YELLOW}[SKIP]${NC} zsh not found, skipping zsh tests"
fi

# ==========================================
print_scenario "Cleanup"
# ==========================================

/bin/rm -f "$BLOCK_FILE"
cd /
/bin/rm -rf "$TEST_DIR"

# Restore original block file
if [ -n "$backup_block" ]; then
    echo "$backup_block" > "$BLOCK_FILE"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}BLOCK-PROTECT TEST SUMMARY${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Total Tests Run:    ${YELLOW}$TESTS_RUN${NC}"
echo -e "Tests Passed:       ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed:       ${RED}$TESTS_FAILED${NC}"

if [ "$TESTS_FAILED" -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✓ ALL BLOCK-PROTECT TESTS PASSED!${NC}"
    echo ""
    exit 0
else
    echo ""
    echo -e "${RED}✗ SOME TESTS FAILED${NC}"
    echo ""
    exit 1
fi
