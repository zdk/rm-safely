#!/usr/bin/env bash

# Performance benchmark for rm-safely optimizations

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_FILE="$HOME/.rm-safely"
TEST_DIR="$SCRIPT_DIR/benchmark_workspace"
UNDO_STACK="$HOME/.rm-safely-undo-stack"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_result() {
    echo -e "${GREEN}$1${NC}"
}

# Check if rm-safely is installed
if [ ! -f "$HOOK_FILE" ]; then
    echo "Error: rm-safely not installed. Run './rm-safely install' first"
    exit 1
fi

# shellcheck source=/dev/null
source "$HOOK_FILE"

# Clean up any previous test
if [ -d "$TEST_DIR" ]; then
    /bin/rm -rf "$TEST_DIR"
fi
/bin/rm -f "$UNDO_STACK"

mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1

print_header "BENCHMARK 1: Large File Deletion (100 files)"
for i in {1..100}; do
    echo "content $i" > "file_$i.txt"
done

start=$(date +%s%N)
for i in {1..100}; do
    rm "file_$i.txt" >/dev/null 2>&1
done
end=$(date +%s%N)
elapsed=$((($end - $start) / 1000000))
print_result "Time to delete 100 files: ${elapsed}ms"
print_result "Average per file: $((elapsed / 100))ms"

print_header "BENCHMARK 2: Trash Listing with 100 files"
start=$(date +%s%N)
rm --list-trash >/dev/null 2>&1
end=$(date +%s%N)
elapsed=$((($end - $start) / 1000000))
print_result "Time to list 100 files in trash: ${elapsed}ms"

print_header "BENCHMARK 3: Filtered Trash Listing"
start=$(date +%s%N)
rm --list-trash "file_5" >/dev/null 2>&1
end=$(date +%s%N)
elapsed=$((($end - $start) / 1000000))
print_result "Time to filter trash (100 files): ${elapsed}ms"

print_header "BENCHMARK 4: Hash Generation and Restore"
hash=$(rm --list-trash 2>&1 | grep "file_50" | head -1 | awk '{print $1}')
start=$(date +%s%N)
rm --restore "$hash" >/dev/null 2>&1
end=$(date +%s%N)
elapsed=$((($end - $start) / 1000000))
print_result "Time to find and restore 1 file from 99: ${elapsed}ms"

print_header "BENCHMARK 5: Undo Stack Operations (50 undos)"
start=$(date +%s%N)
for i in {1..50}; do
    rm --undo >/dev/null 2>&1
done
end=$(date +%s%N)
elapsed=$((($end - $start) / 1000000))
print_result "Time for 50 undo operations: ${elapsed}ms"
print_result "Average per undo: $((elapsed / 50))ms"

print_header "BENCHMARK 6: Multiple File Deletion in Single Command"
for i in {1..50}; do
    echo "batch $i" > "batch_$i.txt"
done

start=$(date +%s%N)
rm batch_*.txt >/dev/null 2>&1
end=$(date +%s%N)
elapsed=$((($end - $start) / 1000000))
print_result "Time to delete 50 files in one command: ${elapsed}ms"
print_result "Average per file: $((elapsed / 50))ms"

print_header "BENCHMARK 7: Get All Trash Dirs Performance"
start=$(date +%s%N)
for i in {1..100}; do
    # Simulate what happens internally
    trash_dirs=$(rm --show-trash-path 2>&1)
done
end=$(date +%s%N)
elapsed=$((($end - $start) / 1000000))
print_result "Time for 100 trash dir lookups: ${elapsed}ms"
print_result "Average per lookup: $((elapsed / 100))ms"

# Cleanup
print_header "Cleanup"
cd "$SCRIPT_DIR" || exit 1
if [ -d "$TEST_DIR" ]; then
    /bin/rm -rf "$TEST_DIR"
    echo "Benchmark workspace removed"
fi

echo ""
echo -e "${GREEN}✓ PERFORMANCE BENCHMARKS COMPLETE${NC}"
echo ""
