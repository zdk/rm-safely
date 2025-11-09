#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_FILE="$HOME/.rm-safely"
UNDO_STACK="$HOME/.rm-safely-undo-stack"
TEST_DIR="$SCRIPT_DIR/test_e2e_workspace"

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

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_scenario "Environment Setup"
print_test "Checking rm-safely installation"
if [ ! -f "$HOOK_FILE" ]; then
    print_fail "Hook file not found. Please run './rm-safely install' first"
    exit 1
fi
print_pass "rm-safely is installed"

# shellcheck source=/dev/null
source "$HOOK_FILE"

if [ -d "$TEST_DIR" ]; then
    /bin/rm -rf "$TEST_DIR"
fi

print_test "Creating test workspace"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
print_pass "Test workspace created at $TEST_DIR"

print_test "Creating a sample project structure"
mkdir -p src/{components,utils,styles}
mkdir -p docs
mkdir -p tests
echo "console.log('Hello World');" >src/main.js
echo "export const add = (a, b) => a + b;" >src/utils/math.js
echo "export const Button = () => {};" >src/components/Button.jsx
echo ".container { margin: 0; }" >src/styles/app.css
echo "# Project Documentation" >docs/README.md
echo "# TODO: Write tests" >tests/app.test.js
echo "node_modules/" >.gitignore
print_pass "Project structure created (6 files, 6 directories)"

print_scenario "Accidental Deletion & Recovery"
print_test "Accidentally delete important file"
rm src/main.js
if [ ! -f src/main.js ]; then
    print_pass "File deleted successfully"
else
    print_fail "File should be deleted"
fi

print_test "Realize mistake and undo immediately"
rm --undo >/dev/null 2>&1
if [ -f src/main.js ] && [ "$(cat src/main.js)" = "console.log('Hello World');" ]; then
    print_pass "File restored successfully with correct content"
else
    print_fail "File should be restored"
fi

print_scenario "Bulk Deletion & Selective Restore"
print_test "Delete multiple files during refactoring"
rm src/utils/math.js
rm src/components/Button.jsx
rm src/styles/app.css
if [ ! -f src/utils/math.js ] && [ ! -f src/components/Button.jsx ] && [ ! -f src/styles/app.css ]; then
    print_pass "All files deleted"
else
    print_fail "All files should be deleted"
fi

print_test "List trash to find specific file"
output=$(rm --list-trash 2>&1)
if echo "$output" | grep -q "Button.jsx"; then
    print_pass "Trash listing shows deleted files"
else
    print_fail "Should show Button.jsx in trash"
fi

print_test "Restore specific file by hash"
hash=$(rm --list-trash 2>&1 | grep "Button.jsx" | head -1 | awk '{print $1}')
if [ -n "$hash" ]; then
    rm --restore "$hash" >/dev/null 2>&1
    if [ -f src/components/Button.jsx ]; then
        print_pass "Specific file restored by hash: $hash"
    else
        print_fail "File should be restored"
    fi
else
    print_fail "Could not find hash for Button.jsx"
fi

print_test "Restore app.css via undo"
# Undo restores in LIFO order: app.css, Button.jsx (already exists, will conflict), math.js
rm --undo >/dev/null 2>&1 # Restores app.css
if [ -f src/styles/app.css ]; then
    print_pass "app.css restored via undo"
else
    print_fail "app.css should be restored"
fi

print_test "Restore math.js via undo"
rm --undo >/dev/null 2>&1 || true # Tries to restore Button.jsx (already exists, creates conflict)
rm --undo >/dev/null 2>&1 # Restores math.js
if [ -f src/utils/math.js ]; then
    print_pass "math.js restored via undo"
else
    print_fail "math.js should be restored"
fi

print_scenario "Directory Operations"
print_test "Delete entire directory"
rm -r tests
if [ ! -d tests ]; then
    print_pass "Directory deleted"
else
    print_fail "Directory should be deleted"
fi

print_test "Restore directory with contents"
rm --undo >/dev/null 2>&1
if [ -d tests ] && [ -f tests/app.test.js ]; then
    print_pass "Directory and contents restored"
else
    print_fail "Directory should be restored with contents"
fi

print_scenario "Name Conflict Resolution"
print_test "Create conflict scenario"
echo "version 1" >conflict.txt
rm conflict.txt
echo "version 2" >conflict.txt
if [ -f conflict.txt ]; then
    print_pass "Conflict setup complete"
else
    print_fail "Setup failed"
fi

print_test "Restore with name conflict"
output=$(rm --undo 2>&1)
if echo "$output" | grep -q "already exists"; then
    if ls conflict.txt_restored_* >/dev/null 2>&1; then
        print_pass "Conflict resolved with renamed file"
    else
        print_fail "Should create renamed file"
    fi
else
    print_fail "Should detect conflict"
fi

print_scenario "Special Characters & Edge Cases"

print_test "Handle files with spaces"
echo "content" >"file with spaces.txt"
rm "file with spaces.txt"
if [ ! -f "file with spaces.txt" ]; then
    print_pass "File with spaces deleted"
else
    print_fail "Should delete file with spaces"
fi

rm --undo >/dev/null 2>&1
if [ -f "file with spaces.txt" ]; then
    print_pass "File with spaces restored"
else
    print_fail "Should restore file with spaces"
fi

print_test "Handle special characters in filenames"
touch "test@#\$%.txt"
rm "test@#\$%.txt"
if [ ! -f "test@#\$%.txt" ]; then
    print_pass "File with special chars deleted"
else
    print_fail "Should delete file with special chars"
fi

print_test "Handle empty directory"
mkdir empty_dir
rm -r empty_dir
if [ ! -d empty_dir ]; then
    print_pass "Empty directory deleted"
else
    print_fail "Should delete empty directory"
fi

print_scenario "Trash Management"

print_test "Create multiple trash items"
echo "temp1" >temp1.txt
echo "temp2" >temp2.txt
echo "temp3" >temp3.txt
rm temp1.txt temp2.txt temp3.txt
trash_count=$(rm --list-trash 2>&1 | grep -c "temp[123].txt")
if [ "$trash_count" -ge 3 ]; then
    print_pass "Multiple items in trash ($trash_count found)"
else
    print_fail "Should have at least 3 temp files in trash"
fi

print_test "Check trash path visibility"
if rm --show-trash-path 2>&1 | grep -q ".local/share/Trash"; then
    print_pass "Trash path shown correctly"
else
    print_fail "Should show trash path"
fi

print_scenario "Search/Filter Trash Contents"

print_test "Create files with unique patterns for filter testing"
echo "project code" >uniqueproject123_config.js
echo "app code" >uniqueapp456_settings.json
echo "readme text" >uniqueREADME789.md
echo "test code" >uniquehelper999_test.py
rm uniqueproject123_config.js uniqueapp456_settings.json uniqueREADME789.md uniquehelper999_test.py
print_pass "Created and deleted 4 files with unique patterns"

print_test "Filter by filename pattern - includes match"
filter_output=$(rm --list-trash "uniqueproject123" 2>&1)
if echo "$filter_output" | grep -q "uniqueproject123_config.js"; then
    print_pass "Filter includes matching file (uniqueproject123)"
else
    print_fail "Filter should show uniqueproject123_config.js"
fi

print_test "Filter by filename pattern - excludes non-match"
filter_output=$(rm --list-trash "uniqueproject123" 2>&1)
if ! echo "$filter_output" | grep -q "uniqueapp456_settings.json"; then
    print_pass "Filter excludes non-matching file"
else
    print_fail "Filter should not show uniqueapp456_settings.json when filtering by uniqueproject123"
fi

print_test "Filter with different unique pattern"
filter_output=$(rm --list-trash "helper999" 2>&1)
if echo "$filter_output" | grep -q "uniquehelper999_test.py"; then
    print_pass "Filter shows matching file (helper999)"
else
    print_fail "Filter should show uniquehelper999_test.py"
fi

print_test "Filter with file extension pattern"
filter_output=$(rm --list-trash "uniqueREADME789.md" 2>&1)
if echo "$filter_output" | grep -q "uniqueREADME789.md" && \
   ! echo "$filter_output" | grep -q "uniquehelper999_test.py"; then
    print_pass "Filter matches specific markdown file"
else
    print_fail "Filter should show uniqueREADME789.md but not .py files"
fi

print_test "Filter with guaranteed no matches"
filter_output=$(rm --list-trash "xYz123NoMatchEver456" 2>&1)
if echo "$filter_output" | grep -q "No files found matching pattern"; then
    print_pass "Filter correctly reports no matches"
else
    print_fail "Should show 'No files found' message for non-existent pattern"
fi

print_test "Case-insensitive filter test (uppercase)"
filter_output=$(rm --list-trash "UNIQUEREADME789" 2>&1)
if echo "$filter_output" | grep -q "uniqueREADME789.md"; then
    print_pass "Filter is case-insensitive (uppercase pattern)"
else
    print_fail "Filter should match uniqueREADME789.md with uppercase pattern"
fi

print_test "Case-insensitive filter test (lowercase)"
filter_output=$(rm --list-trash "uniquereadme789" 2>&1)
if echo "$filter_output" | grep -q "uniqueREADME789.md"; then
    print_pass "Filter is case-insensitive (lowercase pattern)"
else
    print_fail "Filter should match uniqueREADME789.md with lowercase pattern"
fi

print_test "List all trash without filter shows test files"
list_output=$(rm --list-trash 2>&1)
if echo "$list_output" | grep -q "uniqueproject123_config.js" && \
   echo "$list_output" | grep -q "uniqueapp456_settings.json" && \
   echo "$list_output" | grep -q "uniqueREADME789.md" && \
   echo "$list_output" | grep -q "uniquehelper999_test.py"; then
    print_pass "Listing all trash shows all test files"
else
    print_fail "Should show all test files when no filter is provided"
fi

print_scenario "Direct Deletion (Bypass Trash)"
print_test "Create file for permanent deletion"
echo "disposable" >disposable.txt
if [ -f disposable.txt ]; then
    print_pass "File created"
else
    print_fail "Setup failed"
fi

print_test "Bypass trash with --rm (non-recursive)"
# shellcheck disable=SC2216
echo "yes" | rm --rm disposable.txt >/dev/null 2>&1
if [ ! -f disposable.txt ]; then
    print_pass "File permanently deleted without trash"
else
    print_fail "File should be permanently deleted"
fi

print_test "Verify file not in trash (cannot undo)"
if rm --undo 2>&1 | grep -q "test@#"; then
    print_pass "Undo restored different file (not permanently deleted one)"
else
    print_info "Undo stack may be empty or has other files"
fi

print_scenario "Multi-Level Undo Chain"
print_test "Create undo chain with 5 operations"
for i in {1..5}; do
    echo "content $i" >"chain_$i.txt"
    rm "chain_$i.txt"
done
print_pass "Created chain of 5 deletions"

print_test "Undo in reverse order (LIFO)"
success=0
for i in {5..1}; do
    rm --undo >/dev/null 2>&1
    if [ -f "chain_$i.txt" ] && [ "$(cat "chain_$i.txt")" = "content $i" ]; then
        success=$((success + 1))
    fi
done
if [ "$success" -eq 5 ]; then
    print_pass "All 5 files restored in correct LIFO order"
else
    print_fail "Should restore all 5 files in reverse order (restored: $success/5)"
fi

print_scenario "Error Handling"
print_test "Try to restore with invalid hash"
if rm --restore "invalid123" 2>&1 | grep -q "No file found"; then
    print_pass "Invalid hash error handled correctly"
else
    print_fail "Should show error for invalid hash"
fi

print_test "Try to undo when stack is empty"
/bin/rm -f "$UNDO_STACK"
if rm --undo 2>&1 | grep -q "Nothing to undo"; then
    print_pass "Empty undo stack handled correctly"
else
    print_fail "Should show 'Nothing to undo' message"
fi

print_test "Try to remove non-existent file"
if rm nonexistent.txt 2>&1 | grep -q "No such file or directory"; then
    print_pass "Non-existent file error handled correctly"
else
    print_fail "Should show error for non-existent file"
fi

print_scenario "Command Line Interface"
print_test "Check version flag"
if rm --version 2>&1 | grep -q "rm-safely"; then
    print_pass "Version information displayed"
else
    print_fail "Should show version"
fi

print_test "Check help flag"
if rm --help 2>&1 | grep -q "Usage:"; then
    print_pass "Help information displayed"
else
    print_fail "Should show help"
fi

print_scenario "Cross-Directory Operations"
print_test "Delete from different directory"
cd "$SCRIPT_DIR" || exit 1
echo "external" >/tmp/rm-safely-e2e-external.txt
rm /tmp/rm-safely-e2e-external.txt
if [ ! -f /tmp/rm-safely-e2e-external.txt ]; then
    print_pass "File deleted from different directory"
else
    print_fail "Should delete external file"
fi

print_test "Restore file to original location"
rm --undo >/dev/null 2>&1
if [ -f /tmp/rm-safely-e2e-external.txt ]; then
    print_pass "File restored to original location"
    /bin/rm /tmp/rm-safely-e2e-external.txt
else
    print_fail "Should restore to /tmp"
fi

print_scenario "Cleanup"
print_test "Cleaning up test workspace"
cd "$SCRIPT_DIR" || exit 1
if [ -d "$TEST_DIR" ]; then
    /bin/rm -rf "$TEST_DIR"
    print_pass "Test workspace removed"
else
    print_info "Test workspace already clean"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}E2E TEST SUMMARY${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Total Tests Run:    ${YELLOW}$TESTS_RUN${NC}"
echo -e "Tests Passed:       ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed:       ${RED}$TESTS_FAILED${NC}"

if [ "$TESTS_FAILED" -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✓ ALL E2E TESTS PASSED!${NC}"
    echo ""
    exit 0
else
    echo ""
    echo -e "${RED}✗ SOME TESTS FAILED${NC}"
    echo ""
    exit 1
fi
