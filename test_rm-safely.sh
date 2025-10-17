#!/usr/bin/env zsh

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_header() {
    echo -e "\n${YELLOW}=== $1 ===${NC}"
}

print_pass() {
    echo -e "${GREEN}✓${NC} $1"
}

print_fail() {
    echo -e "${RED}✗${NC} $1"
    exit 1
}

TEST_DIR="/tmp/rm-safely-compat-test-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1

print_header "Installing rm-safely"
bash "$OLDPWD/rm-safely" install >/dev/null 2>&1 || true
print_pass "Installation complete"

print_header "Testing in bash"
bash <<'BASH_TEST'
# shellcheck source=/dev/null
source "$HOME/.rm-safely"

# Test basic functionality
echo "test content" > test_bash.txt
rm test_bash.txt
if [ ! -f test_bash.txt ]; then
    echo "PASS: File removed in bash"
else
    echo "FAIL: File not removed in bash"
    exit 1
fi

# Test undo
rm --undo > /dev/null 2>&1
if [ -f test_bash.txt ]; then
    echo "PASS: File restored in bash"
else
    echo "FAIL: File not restored in bash"
    exit 1
fi

# Test list-trash
rm test_bash.txt
if rm --list-trash | grep -q test_bash; then
    echo "PASS: List trash works in bash"
else
    echo "FAIL: List trash failed in bash"
    exit 1
fi
BASH_TEST

if [ $? -eq 0 ]; then
    print_pass "All bash tests passed"
else
    print_fail "Bash tests failed"
fi

if command -v zsh >/dev/null 2>&1; then
    print_header "Testing in zsh"
    zsh <<'ZSH_TEST'
source "$HOME/.rm-safely"

# Test basic functionality
echo "test content" > test_zsh.txt
rm test_zsh.txt
if [ ! -f test_zsh.txt ]; then
    echo "PASS: File removed in zsh"
else
    echo "FAIL: File not removed in zsh"
    exit 1
fi

# Test undo
rm --undo > /dev/null 2>&1
if [ -f test_zsh.txt ]; then
    echo "PASS: File restored in zsh"
else
    echo "FAIL: File not restored in zsh"
    exit 1
fi

# Test list-trash
rm test_zsh.txt
if rm --list-trash | grep -q test_zsh; then
    echo "PASS: List trash works in zsh"
else
    echo "FAIL: List trash failed in zsh"
    exit 1
fi
ZSH_TEST

    if [ $? -eq 0 ]; then
        print_pass "All zsh tests passed"
    else
        print_fail "Zsh tests failed"
    fi
else
    echo -e "${YELLOW}ℹ${NC} zsh not found, skipping zsh tests"
fi

print_header "Cleanup"
cd / || exit 1
rm -rf "$TEST_DIR"
print_pass "Test directory cleaned up"

echo -e "\n${GREEN}All shell compatibility tests passed!${NC}\n"
