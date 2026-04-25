#!/bin/bash
# Tests for uvid.sh
# Usage: ./tests/test_uvid.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UVID="$SCRIPT_DIR/../uvid.sh"
YEAR=$(date +'%Y')
LOG_FILE="${YEAR}_uvid.log"

TESTS_PASSED=0
TESTS_FAILED=0
ORIG_DIR="$(pwd)"

setup() {
    TEST_DIR=$(mktemp -d)
    export UVID_DIR="$TEST_DIR"
    cd "$TEST_DIR"
}

teardown() {
    cd "$ORIG_DIR"
    rm -rf "$TEST_DIR"
}

strip_ansi() {
    echo "$1" | sed 's/\x1b\[[0-9;]*[mK]//g'
}

assert_contains() {
    local haystack=$(strip_ansi "$1")
    local needle="$2"
    local msg="$3"
    if [[ "$haystack" == *"$needle"* ]]; then
        echo "  PASS: $msg"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  FAIL: $msg"
        echo "    expected to contain: $needle"
        echo "    got: $haystack"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_not_contains() {
    local haystack=$(strip_ansi "$1")
    local needle="$2"
    local msg="$3"
    if [[ "$haystack" != *"$needle"* ]]; then
        echo "  PASS: $msg"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  FAIL: $msg"
        echo "    expected NOT to contain: $needle"
        echo "    got: $haystack"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local msg="$3"
    if [ "$expected" = "$actual" ]; then
        echo "  PASS: $msg"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  FAIL: $msg"
        echo "    expected: $expected"
        echo "    got:      $actual"
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

# ---- Log writing (inline) ----

test_inline_text_only() {
    bash "$UVID" "some insight" > /dev/null
    local content=$(cat "$LOG_FILE")
    assert_contains "$content" "some insight" "text is written to log"
    assert_contains "$content" "[$(date +'%d.%m.%Y')" "timestamp present"
}

test_inline_with_author_and_source() {
    bash "$UVID" "quoted text" -a "John Doe" -s "Book Title" > /dev/null
    local content=$(cat "$LOG_FILE")
    assert_contains "$content" "quoted text" "text present"
    assert_contains "$content" "[John Doe]" "author bracket present"
    assert_contains "$content" "(Book Title)" "source paren present"
}

# ---- Log writing (interactive) ----

test_interactive_full() {
    printf "my thought\nBlog\nJane\n" | bash "$UVID" > /dev/null
    local content=$(cat "$LOG_FILE")
    assert_contains "$content" "my thought" "text from interactive"
    assert_contains "$content" "[Jane]" "author from interactive"
    assert_contains "$content" "(Blog)" "source from interactive"
}

test_interactive_defaults() {
    printf "just text\n\n\n" | bash "$UVID" > /dev/null
    local content=$(cat "$LOG_FILE")
    assert_contains "$content" "just text" "text present"
    assert_contains "$content" "[.]" "author defaults to ."
    assert_contains "$content" "(-)" "source defaults to -"
}

# ---- List ----

test_list_default_shows_all_when_under_ten() {
    bash "$UVID" "entry one" > /dev/null
    bash "$UVID" "entry two" > /dev/null
    local output=$(bash "$UVID" --list)
    assert_contains "$output" "entry one" "list contains first entry"
    assert_contains "$output" "entry two" "list contains second entry"
}

test_list_with_count() {
    bash "$UVID" "a1" > /dev/null
    bash "$UVID" "a2" > /dev/null
    bash "$UVID" "a3" > /dev/null
    local output=$(bash "$UVID" --list 1)
    assert_contains "$output" "a3" "list 1 shows last entry"
    assert_not_contains "$output" "a1" "list 1 does not show first entry"
}

test_list_no_log_file() {
    local output=$(bash "$UVID" --list)
    assert_contains "$output" "No log file found" "message when no log exists"
}

# ---- Search ----

test_search_finds_match() {
    bash "$UVID" "apple pie recipe" > /dev/null
    bash "$UVID" "banana bread" > /dev/null
    local output=$(bash "$UVID" --search "apple")
    assert_contains "$output" "apple pie recipe" "search finds matching entry"
    assert_not_contains "$output" "banana bread" "search excludes non-match"
}

test_search_case_insensitive() {
    bash "$UVID" "Hello World" > /dev/null
    local output=$(bash "$UVID" --search "hello")
    assert_contains "$output" "Hello World" "search is case insensitive"
}

test_search_across_years() {
    echo "[15.06.2025 10:00] old entry" > "2025_uvid.log"
    bash "$UVID" "new entry about old things" > /dev/null
    local output=$(bash "$UVID" --search "entry")
    assert_contains "$output" "old entry" "search finds in previous year"
    assert_contains "$output" "new entry about old things" "search finds in current year"
}

# ---- Edit ----

test_edit_updates_text() {
    bash "$UVID" "original text" -a "author" -s "source" > /dev/null
    # Browse (Enter=b), select 1, new text, keep author, keep source
    printf "\n1\nupdated text\n\n\n" | bash "$UVID" --edit > /dev/null
    local content=$(cat "$LOG_FILE")
    assert_contains "$content" "updated text" "text is updated"
    assert_not_contains "$content" "original text" "original text removed"
    assert_contains "$content" "[author]" "author preserved"
    assert_contains "$content" "(source)" "source preserved"
}

test_edit_preserves_timestamp() {
    # Create entry with a specific timestamp we can check for
    echo "[15.03.2025 09:30] fixed entry [a] (s)" > "$LOG_FILE"
    # Need browse to look at current year, so use search to find entry
    printf "s\nfixed\n1\nchanged entry\n\n\n" | bash "$UVID" --edit > /dev/null
    local content=$(cat "$LOG_FILE")
    assert_contains "$content" "[15.03.2025 09:30]" "original timestamp kept"
    assert_contains "$content" "changed entry" "text updated"
}

test_edit_clears_author_with_space() {
    bash "$UVID" "text" -a "to remove" -s "keep me" > /dev/null
    # Keep text (empty), clear author (space), keep source (empty)
    printf "\n1\n\n \n\n" | bash "$UVID" --edit > /dev/null
    local content=$(cat "$LOG_FILE")
    assert_not_contains "$content" "[to remove]" "author cleared"
    assert_contains "$content" "(keep me)" "source preserved"
}

test_edit_keeps_all_on_empty_input() {
    bash "$UVID" "untouched" -a "same author" -s "same source" > /dev/null
    # Browse, select 1, all Enter
    printf "\n1\n\n\n\n" | bash "$UVID" --edit > /dev/null
    local content=$(cat "$LOG_FILE")
    assert_contains "$content" "untouched" "text preserved"
    assert_contains "$content" "[same author]" "author preserved"
    assert_contains "$content" "(same source)" "source preserved"
}

# ---- Delete ----

test_delete_removes_entry() {
    bash "$UVID" "entry to remove" > /dev/null
    bash "$UVID" "entry to keep" > /dev/null
    # Browse, select 1 (oldest first in tail order), confirm with Enter (default y)
    printf "\n1\n\n" | bash "$UVID" --delete > /dev/null
    local content=$(cat "$LOG_FILE")
    assert_not_contains "$content" "entry to remove" "first entry removed"
    assert_contains "$content" "entry to keep" "second entry remains"
}

test_delete_cancel_with_n() {
    bash "$UVID" "should remain" > /dev/null
    # Browse, select 1, type n to cancel
    printf "\n1\nn\n" | bash "$UVID" --delete > /dev/null
    local content=$(cat "$LOG_FILE")
    assert_contains "$content" "should remain" "entry still present after cancel"
}

test_delete_default_confirm_is_yes() {
    bash "$UVID" "goodbye" > /dev/null
    # Browse, select 1, Enter = default yes
    printf "\n1\n\n" | bash "$UVID" --delete > /dev/null
    local line_count=$(wc -l < "$LOG_FILE" | tr -d ' ')
    assert_equals "0" "$line_count" "log file is empty after delete"
}

test_delete_via_search() {
    bash "$UVID" "alpha entry" > /dev/null
    bash "$UVID" "beta entry" > /dev/null
    # Search mode, search for "alpha", select 1, confirm
    printf "s\nalpha\n1\n\n" | bash "$UVID" --delete > /dev/null
    local content=$(cat "$LOG_FILE")
    assert_not_contains "$content" "alpha entry" "alpha entry deleted"
    assert_contains "$content" "beta entry" "beta entry remains"
}

# ---- Export ----

test_export_creates_file() {
    bash "$UVID" "first entry" -a "Author" -s "Source" > /dev/null
    bash "$UVID" "second entry" > /dev/null
    bash "$UVID" --export > /dev/null
    local export_file="uvid_export_$(date +'%Y-%m-%d').md"
    assert_equals "true" "$([ -f "$export_file" ] && echo true || echo false)" "export file created"
}

test_export_contains_entries() {
    bash "$UVID" "first entry" -a "Author" -s "Source" > /dev/null
    bash "$UVID" "second entry" > /dev/null
    bash "$UVID" --export > /dev/null
    local export_file="uvid_export_$(date +'%Y-%m-%d').md"
    local content=$(cat "$export_file")
    assert_contains "$content" "# Uvid Export" "header present"
    assert_contains "$content" "2 entries" "entry count in header"
    assert_contains "$content" "**[" "entry formatted with bold timestamp"
    assert_contains "$content" "first entry" "first entry present"
    assert_contains "$content" "second entry" "second entry present"
}

test_export_metadata_formatting() {
    bash "$UVID" "with both" -a "John" -s "Blog" > /dev/null
    bash "$UVID" "with author only" -a "Jane" > /dev/null
    bash "$UVID" "with source only" -s "Book" > /dev/null
    bash "$UVID" "with defaults" > /dev/null
    bash "$UVID" --export > /dev/null
    local export_file="uvid_export_$(date +'%Y-%m-%d').md"
    local content=$(cat "$export_file")
    assert_contains "$content" "Author: John | Source: Blog" "both author and source shown with pipe"
    assert_contains "$content" "Author: Jane" "author-only line present"
    assert_not_contains "$content" "Author: Jane |" "no pipe when only author"
    assert_contains "$content" "Source: Book" "source-only line present"
    assert_not_contains "$content" "Author: ." "default author excluded"
    assert_not_contains "$content" "Source: -" "default source excluded"
}

test_export_no_entries() {
    local output=$(bash "$UVID" --export)
    local export_file="uvid_export_$(date +'%Y-%m-%d').md"
    assert_contains "$output" "No entries" "no-match message shown"
    assert_equals "false" "$([ -f "$export_file" ] && echo true || echo false)" "no file created when no entries"
}

test_export_across_years() {
    echo "[15.06.2025 10:00] old entry [OldAuth] (OldSrc)" > "2025_uvid.log"
    bash "$UVID" "new entry" > /dev/null
    bash "$UVID" --export > /dev/null
    local export_file="uvid_export_$(date +'%Y-%m-%d').md"
    local content=$(cat "$export_file")
    assert_contains "$content" "old entry" "entry from 2025 included"
    assert_contains "$content" "new entry" "entry from current year included"
    assert_contains "$content" "2 entries" "count includes both years"
}

test_export_filter_search() {
    bash "$UVID" "apple pie recipe" > /dev/null
    bash "$UVID" "banana bread" > /dev/null
    bash "$UVID" --export --search "apple" > /dev/null
    local export_file="uvid_export_$(date +'%Y-%m-%d').md"
    local content=$(cat "$export_file")
    assert_contains "$content" "apple pie recipe" "search filter includes match"
    assert_not_contains "$content" "banana bread" "search filter excludes non-match"
    assert_contains "$content" "1 entries" "count reflects filter"
    assert_contains "$content" '"apple"' "header shows search term"
}

test_export_filter_author() {
    bash "$UVID" "entry one" -a "Plato" > /dev/null
    bash "$UVID" "entry two" -a "Aristotle" > /dev/null
    bash "$UVID" --export --author "Plato" > /dev/null
    local export_file="uvid_export_$(date +'%Y-%m-%d').md"
    local content=$(cat "$export_file")
    assert_contains "$content" "entry one" "author filter includes match"
    assert_not_contains "$content" "entry two" "author filter excludes non-match"
    assert_contains "$content" "Plato" "header shows author"
}

test_export_filter_author_case_insensitive() {
    bash "$UVID" "entry one" -a "Plato" > /dev/null
    bash "$UVID" --export --author "plato" > /dev/null
    local export_file="uvid_export_$(date +'%Y-%m-%d').md"
    local content=$(cat "$export_file")
    assert_contains "$content" "entry one" "author filter is case insensitive"
}

test_export_filter_year() {
    echo "[15.06.2025 10:00] old entry [.] (-)" > "2025_uvid.log"
    bash "$UVID" "new entry" > /dev/null
    bash "$UVID" --export --year 2025 > /dev/null
    local export_file="uvid_export_$(date +'%Y-%m-%d').md"
    local content=$(cat "$export_file")
    assert_contains "$content" "old entry" "year filter includes matching year"
    assert_not_contains "$content" "new entry" "year filter excludes other year"
    assert_contains "$content" "2025" "header shows year"
}

test_export_filter_date_range() {
    echo "[01.03.2025 10:00] march entry [.] (-)" > "2025_uvid.log"
    echo "[15.06.2025 10:00] june entry [.] (-)" >> "2025_uvid.log"
    echo "[01.09.2025 10:00] sept entry [.] (-)" >> "2025_uvid.log"
    bash "$UVID" --export --from "01.01.2025" --to "30.06.2025" > /dev/null
    local export_file="uvid_export_$(date +'%Y-%m-%d').md"
    local content=$(cat "$export_file")
    assert_contains "$content" "march entry" "date range includes march"
    assert_contains "$content" "june entry" "date range includes june"
    assert_not_contains "$content" "sept entry" "date range excludes september"
    assert_contains "$content" "2 entries" "count reflects date filter"
}

test_export_filter_combined() {
    bash "$UVID" "alpha by plato" -a "Plato" > /dev/null
    bash "$UVID" "beta by plato" -a "Plato" > /dev/null
    bash "$UVID" "alpha by jane" -a "Jane" > /dev/null
    bash "$UVID" --export --search "alpha" --author "Plato" > /dev/null
    local export_file="uvid_export_$(date +'%Y-%m-%d').md"
    local content=$(cat "$export_file")
    assert_contains "$content" "alpha by plato" "combined filter includes match"
    assert_not_contains "$content" "beta by plato" "combined filter excludes search miss"
    assert_not_contains "$content" "alpha by jane" "combined filter excludes author miss"
    assert_contains "$content" "1 entries" "count reflects combined filter"
}

test_export_year_and_from_to_exclusive() {
    local output=$(bash "$UVID" --export --year 2025 --from "01.01.2025" --to "31.12.2025" 2>&1)
    assert_contains "$output" "cannot be combined" "year + from/to error message"
}

test_export_from_without_to() {
    local output=$(bash "$UVID" --export --from "01.01.2025" 2>&1)
    assert_contains "$output" "must both be provided" "from without to error message"
}

# ---- Run all ----

run_test test_inline_text_only
run_test test_inline_with_author_and_source
run_test test_interactive_full
run_test test_interactive_defaults
run_test test_list_default_shows_all_when_under_ten
run_test test_list_with_count
run_test test_list_no_log_file
run_test test_search_finds_match
run_test test_search_case_insensitive
run_test test_search_across_years
run_test test_edit_updates_text
run_test test_edit_preserves_timestamp
run_test test_edit_clears_author_with_space
run_test test_edit_keeps_all_on_empty_input
run_test test_delete_removes_entry
run_test test_delete_cancel_with_n
run_test test_delete_default_confirm_is_yes
run_test test_delete_via_search
run_test test_export_creates_file
run_test test_export_contains_entries
run_test test_export_metadata_formatting
run_test test_export_no_entries
run_test test_export_across_years
run_test test_export_filter_search
run_test test_export_filter_author
run_test test_export_filter_author_case_insensitive
run_test test_export_filter_year
run_test test_export_filter_date_range
run_test test_export_filter_combined
run_test test_export_year_and_from_to_exclusive
run_test test_export_from_without_to

echo ""
echo "======================================"
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"
echo "======================================"

[ "$TESTS_FAILED" -eq 0 ]
