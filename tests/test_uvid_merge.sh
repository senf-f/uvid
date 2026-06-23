#!/bin/bash
# Tests for uvid-merge.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MERGE="$SCRIPT_DIR/../uvid-merge.sh"

TESTS_PASSED=0
TESTS_FAILED=0
ORIG_DIR="$(pwd)"

setup() {
    TEST_DIR=$(mktemp -d)
    CANON_DIR="$TEST_DIR/canon"
    INC_DIR="$TEST_DIR/incoming"
    mkdir -p "$CANON_DIR" "$INC_DIR"
    cp "$MERGE" "$CANON_DIR/uvid-merge.sh"
    chmod +x "$CANON_DIR/uvid-merge.sh"
}

teardown() {
    cd "$ORIG_DIR"
    rm -rf "$TEST_DIR"
}

run_merge() {
    "$CANON_DIR/uvid-merge.sh" "$INC_DIR" > /dev/null
}

assert_file_equals() {
    local file="$1"
    local expected="$2"
    local msg="$3"
    local actual
    actual=$(cat "$file")
    if [ "$expected" = "$actual" ]; then
        echo "  PASS: $msg"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  FAIL: $msg"
        echo "  expected:"
        echo "$expected" | sed 's/^/    /'
        echo "  got:"
        echo "$actual" | sed 's/^/    /'
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

run_test() {
    local name="$1"
    echo ""
    echo "TEST: $name"
    setup
    "$name"
    teardown
}

# ---- Tests ----

test_first_sync_copies_incoming() {
    printf '[01.04.2026 10:00] first entry\n[01.04.2026 11:00] second entry\n' > "$INC_DIR/2026_uvid.log"
    run_merge
    local expected='[01.04.2026 10:00] first entry
[01.04.2026 11:00] second entry'
    assert_file_equals "$CANON_DIR/2026_uvid.log" "$expected" "canonical is created from incoming"
}

test_new_entries_added_from_incoming() {
    printf '[01.04.2026 10:00] one\n' > "$CANON_DIR/2026_uvid.log"
    printf '[01.04.2026 10:00] one\n[01.04.2026 11:00] two\n' > "$INC_DIR/2026_uvid.log"
    run_merge
    local expected='[01.04.2026 10:00] one
[01.04.2026 11:00] two'
    assert_file_equals "$CANON_DIR/2026_uvid.log" "$expected" "new incoming entry appended"
}

test_exact_duplicates_dedup() {
    printf '[01.04.2026 10:00] shared\n[01.04.2026 11:00] canonical-only\n' > "$CANON_DIR/2026_uvid.log"
    printf '[01.04.2026 10:00] shared\n[01.04.2026 12:00] incoming-only\n' > "$INC_DIR/2026_uvid.log"
    run_merge
    local expected='[01.04.2026 10:00] shared
[01.04.2026 11:00] canonical-only
[01.04.2026 12:00] incoming-only'
    assert_file_equals "$CANON_DIR/2026_uvid.log" "$expected" "exact duplicate kept once, order preserved"
}

test_edit_propagates_via_timestamp() {
    printf '[01.04.2026 10:00:00] original text [auth] (src) {laptop}\n' > "$CANON_DIR/2026_uvid.log"
    printf '[01.04.2026 10:00:00] edited text [auth] (src) {laptop}\n' > "$INC_DIR/2026_uvid.log"
    run_merge
    local expected='[01.04.2026 10:00:00] edited text [auth] (src) {laptop}'
    assert_file_equals "$CANON_DIR/2026_uvid.log" "$expected" "incoming edit overrides canonical for matching timestamp+device"
}

test_deletes_do_not_propagate() {
    printf '[01.04.2026 10:00] keep\n[01.04.2026 11:00] was deleted on client\n' > "$CANON_DIR/2026_uvid.log"
    printf '[01.04.2026 10:00] keep\n' > "$INC_DIR/2026_uvid.log"
    run_merge
    local expected='[01.04.2026 10:00] keep
[01.04.2026 11:00] was deleted on client'
    assert_file_equals "$CANON_DIR/2026_uvid.log" "$expected" "deleted-on-client entry persists in canonical"
}

test_order_preserved_across_months() {
    printf '[15.06.2025 10:00] june\n[01.07.2025 09:00] july\n[31.12.2025 23:00] december\n[01.01.2026 01:00] new year\n' > "$INC_DIR/2025_uvid.log"
    run_merge
    local expected='[15.06.2025 10:00] june
[01.07.2025 09:00] july
[31.12.2025 23:00] december
[01.01.2026 01:00] new year'
    assert_file_equals "$CANON_DIR/2025_uvid.log" "$expected" "chronological order preserved (no lex-sort scrambling)"
}

test_multiple_files_merged() {
    printf '[01.01.2025 10:00] twentyfive\n' > "$CANON_DIR/2025_uvid.log"
    printf '[01.01.2025 10:00] twentyfive\n[02.01.2025 10:00] twentyfive-new\n' > "$INC_DIR/2025_uvid.log"
    printf '[01.04.2026 10:00] twentysix\n' > "$INC_DIR/2026_uvid.log"
    run_merge
    assert_file_equals "$CANON_DIR/2025_uvid.log" '[01.01.2025 10:00] twentyfive
[02.01.2025 10:00] twentyfive-new' "2025 file merged"
    assert_file_equals "$CANON_DIR/2026_uvid.log" '[01.04.2026 10:00] twentysix' "2026 file created"
}

test_empty_incoming_dir() {
    printf '[01.04.2026 10:00] untouched\n' > "$CANON_DIR/2026_uvid.log"
    run_merge
    local expected='[01.04.2026 10:00] untouched'
    assert_file_equals "$CANON_DIR/2026_uvid.log" "$expected" "empty incoming leaves canonical untouched"
}

test_missing_incoming_dir_fails() {
    local output
    output=$("$CANON_DIR/uvid-merge.sh" "$TEST_DIR/does-not-exist" 2>&1 || true)
    if [[ "$output" == *"Usage:"* ]]; then
        echo "  PASS: missing incoming dir shows usage"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  FAIL: missing incoming dir should show usage"
        echo "    got: $output"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_same_timestamp_different_device_both_survive() {
    printf '[01.04.2026 10:00:05] entry A [.] (-) {laptop}\n' > "$CANON_DIR/04-2026_uvid.log"
    printf '[01.04.2026 10:00:05] entry B [.] (-) {phone}\n' > "$INC_DIR/04-2026_uvid.log"
    run_merge
    local expected='[01.04.2026 10:00:05] entry A [.] (-) {laptop}
[01.04.2026 10:00:05] entry B [.] (-) {phone}'
    assert_file_equals "$CANON_DIR/04-2026_uvid.log" "$expected" "same timestamp different device both survive"
}

test_same_timestamp_same_device_incoming_wins() {
    printf '[01.04.2026 10:00:05] original [.] (-) {laptop}\n' > "$CANON_DIR/04-2026_uvid.log"
    printf '[01.04.2026 10:00:05] edited [.] (-) {laptop}\n' > "$INC_DIR/04-2026_uvid.log"
    run_merge
    local expected='[01.04.2026 10:00:05] edited [.] (-) {laptop}'
    assert_file_equals "$CANON_DIR/04-2026_uvid.log" "$expected" "same timestamp same device incoming wins"
}

test_no_device_deduped_by_full_line() {
    printf '[01.04.2026 10:00] same line [.] (-)\n[01.04.2026 11:00] other [.] (-)\n' > "$CANON_DIR/04-2026_uvid.log"
    printf '[01.04.2026 10:00] same line [.] (-)\n[01.04.2026 10:00] different text [.] (-)\n' > "$INC_DIR/04-2026_uvid.log"
    run_merge
    local expected='[01.04.2026 10:00] same line [.] (-)
[01.04.2026 11:00] other [.] (-)
[01.04.2026 10:00] different text [.] (-)'
    assert_file_equals "$CANON_DIR/04-2026_uvid.log" "$expected" "no-device entries deduped by full line"
}

test_mixed_format_old_and_new() {
    printf '[01.04.2026 10:00] old format [.] (-)\n[01.04.2026 10:00:30] new format [.] (-) {laptop}\n' > "$CANON_DIR/04-2026_uvid.log"
    printf '[01.04.2026 10:00] old format [.] (-)\n[01.04.2026 10:00:30] new format [.] (-) {laptop}\n[01.04.2026 11:00:00] brand new [.] (-) {phone}\n' > "$INC_DIR/04-2026_uvid.log"
    run_merge
    local expected='[01.04.2026 10:00] old format [.] (-)
[01.04.2026 10:00:30] new format [.] (-) {laptop}
[01.04.2026 11:00:00] brand new [.] (-) {phone}'
    assert_file_equals "$CANON_DIR/04-2026_uvid.log" "$expected" "mixed old/new format entries merge correctly"
}

run_test test_first_sync_copies_incoming
run_test test_new_entries_added_from_incoming
run_test test_exact_duplicates_dedup
run_test test_edit_propagates_via_timestamp
run_test test_deletes_do_not_propagate
run_test test_order_preserved_across_months
run_test test_multiple_files_merged
run_test test_empty_incoming_dir
run_test test_missing_incoming_dir_fails
run_test test_same_timestamp_different_device_both_survive
run_test test_same_timestamp_same_device_incoming_wins
run_test test_no_device_deduped_by_full_line
run_test test_mixed_format_old_and_new

echo ""
echo "======================================"
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"
echo "======================================"

[ "$TESTS_FAILED" -eq 0 ]
