#!/bin/bash
# Tests for uvid.sh
# Usage: ./tests/test_uvid.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UVID="$SCRIPT_DIR/../uvid.sh"
MONTH_YEAR=$(date +'%m-%Y')
LOG_FILE="${MONTH_YEAR}_uvid.log"

TESTS_PASSED=0
TESTS_FAILED=0
ORIG_DIR="$(pwd)"

setup() {
    TEST_DIR=$(mktemp -d)
    export UVID_DIR="$TEST_DIR"
    unset UVID_DEVICE
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

test_search_across_months() {
    echo "[15.06.2025 10:00] old entry" > "06-2025_uvid.log"
    bash "$UVID" "new entry about old things" > /dev/null
    local output=$(bash "$UVID" --search "entry")
    assert_contains "$output" "old entry" "search finds in previous month"
    assert_contains "$output" "new entry about old things" "search finds in current month"
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
    assert_contains "$content" "text [.] (keep me)" "cleared author becomes placeholder"
}

test_edit_text_with_parens_keeps_source() {
    bash "$UVID" "a" -s "src" > /dev/null
    printf "\n1\nb (c)\n\n\n" | bash "$UVID" --edit > /dev/null
    local content=$(cat "$LOG_FILE")
    assert_contains "$content" "b (c) [.] (src)" "parens in edited text stay in text"
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

test_edit_preserves_device_tag() {
    bash "$UVID" --set-device laptop > /dev/null
    bash "$UVID" "original" -a "auth" -s "src" > /dev/null
    # Browse, select 1, change text, keep author, keep source
    printf "\n1\nedited text\n\n\n" | bash "$UVID" --edit > /dev/null
    local content=$(cat "$LOG_FILE")
    assert_contains "$content" "edited text" "text updated"
    assert_contains "$content" "{laptop}" "device tag preserved after edit"
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

test_export_across_months() {
    echo "[15.06.2025 10:00] old entry [OldAuth] (OldSrc)" > "06-2025_uvid.log"
    bash "$UVID" "new entry" > /dev/null
    bash "$UVID" --export > /dev/null
    local export_file="uvid_export_$(date +'%Y-%m-%d').md"
    local content=$(cat "$export_file")
    assert_contains "$content" "old entry" "entry from other month included"
    assert_contains "$content" "new entry" "entry from current month included"
    assert_contains "$content" "2 entries" "count includes both months"
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
    echo "[15.06.2025 10:00] old entry [.] (-)" > "06-2025_uvid.log"
    bash "$UVID" "new entry" > /dev/null
    bash "$UVID" --export --year 2025 > /dev/null
    local export_file="uvid_export_$(date +'%Y-%m-%d').md"
    local content=$(cat "$export_file")
    assert_contains "$content" "old entry" "year filter includes matching year"
    assert_not_contains "$content" "new entry" "year filter excludes other year"
    assert_contains "$content" "2025" "header shows year"
}

test_export_filter_date_range() {
    echo "[01.03.2025 10:00] march entry [.] (-)" > "03-2025_uvid.log"
    echo "[15.06.2025 10:00] june entry [.] (-)" > "06-2025_uvid.log"
    echo "[01.09.2025 10:00] sept entry [.] (-)" > "09-2025_uvid.log"
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

# ---- Export with device ----

test_export_includes_device() {
    bash "$UVID" --set-device laptop > /dev/null
    bash "$UVID" "exported entry" -a "Auth" -s "Src" > /dev/null
    bash "$UVID" --export > /dev/null
    local export_file="uvid_export_$(date +'%Y-%m-%d').md"
    local content=$(cat "$export_file")
    assert_contains "$content" "Device: laptop" "export shows device"
}

test_export_no_device_when_missing() {
    echo "[15.06.2025 10:00] old entry [Auth] (Src)" > "06-2025_uvid.log"
    bash "$UVID" --export > /dev/null
    local export_file="uvid_export_$(date +'%Y-%m-%d').md"
    local content=$(cat "$export_file")
    assert_not_contains "$content" "Device:" "no device line for old entries"
}

# ---- Device ----

test_set_device_creates_file() {
    bash "$UVID" --set-device laptop > /dev/null
    local content=$(cat "$UVID_DIR/.uvid-device")
    assert_equals "laptop" "$content" "device file contains device name"
}

test_set_device_rejects_invalid() {
    local output=$(bash "$UVID" --set-device "bad name" 2>&1)
    assert_contains "$output" "Invalid device name" "rejects name with space"
    assert_equals "false" "$([ -f "$UVID_DIR/.uvid-device" ] && echo true || echo false)" "no file created"
}

test_set_device_rejects_uppercase() {
    local output=$(bash "$UVID" --set-device "MyPC" 2>&1)
    assert_contains "$output" "Invalid device name" "rejects uppercase"
}

test_entry_includes_device_when_set() {
    bash "$UVID" --set-device work > /dev/null
    bash "$UVID" "test entry" > /dev/null
    local content=$(cat "$LOG_FILE")
    assert_contains "$content" "{work}" "entry contains device tag"
}

test_entry_uses_hostname_fallback() {
    bash "$UVID" "test entry" > /dev/null
    local content=$(cat "$LOG_FILE")
    # Device should default to hostname (lowercased) if not explicitly set
    local hostname_lower=$(hostname 2>/dev/null | tr '[:upper:]' '[:lower:]')
    if [[ "$hostname_lower" =~ ^[a-z0-9-]+$ ]]; then
        assert_contains "$content" "{$hostname_lower}" "hostname used as device fallback"
    else
        assert_not_contains "$content" "{" "no device tag if hostname invalid"
    fi
}

test_entry_has_seconds_in_timestamp() {
    bash "$UVID" "test entry" > /dev/null
    local content=$(cat "$LOG_FILE")
    # Timestamp should match [DD.MM.YYYY HH:MM:SS]
    local ts_match=$(echo "$content" | grep -c '\[[0-9]\{2\}\.[0-9]\{2\}\.[0-9]\{4\} [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}\]')
    assert_equals "1" "$ts_match" "timestamp includes seconds"
}

test_device_from_env_var() {
    UVID_DEVICE="from-env" bash "$UVID" "env entry" > /dev/null
    local content=$(cat "$LOG_FILE")
    assert_contains "$content" "{from-env}" "device from env var"
}

test_device_file_overridden_by_env() {
    bash "$UVID" --set-device file-dev > /dev/null
    UVID_DEVICE="env-dev" bash "$UVID" "override entry" > /dev/null
    local content=$(cat "$LOG_FILE")
    assert_contains "$content" "{env-dev}" "env var overrides file"
}

# ---- Display (device stripping) ----

test_list_hides_device_by_default() {
    bash "$UVID" --set-device mypc > /dev/null
    bash "$UVID" "visible text" > /dev/null
    local output=$(bash "$UVID" --list)
    assert_contains "$output" "visible text" "text shown in list"
    assert_not_contains "$output" "{mypc}" "device tag hidden in list"
}

test_list_verbose_shows_device() {
    bash "$UVID" --set-device mypc > /dev/null
    bash "$UVID" "visible text" > /dev/null
    local output=$(bash "$UVID" --list --verbose)
    assert_contains "$output" "{mypc}" "device tag shown with --verbose"
}

test_search_hides_device_by_default() {
    bash "$UVID" --set-device mypc > /dev/null
    bash "$UVID" "searchable text" > /dev/null
    local output=$(bash "$UVID" --search "searchable")
    assert_contains "$output" "searchable text" "text shown in search"
    assert_not_contains "$output" "{mypc}" "device tag hidden in search"
}

test_search_verbose_shows_device() {
    bash "$UVID" --set-device mypc > /dev/null
    bash "$UVID" "searchable text" > /dev/null
    local output=$(bash "$UVID" --search "searchable" --verbose)
    assert_contains "$output" "{mypc}" "device tag shown in search with --verbose"
}

# ---- Entry codec ----

test_codec_matches_fixture() {
    source "$UVID"
    local kind line ts text author source device
    while IFS='|' read -r kind line ts text author source device; do
        [[ -z "$kind" || "$kind" == \#* ]] && continue
        parse_entry "$line"
        assert_equals "$ts|$text|$author|$source|$device" \
            "$p_timestamp|$p_text|$p_author|$p_source|$p_device" "parse: $line"
        if [ "$kind" = "canonical" ]; then
            assert_equals "$line" "$(format_entry "$ts" "$text" "$author" "$source" "$device")" "format: $line"
        fi
    done < "$SCRIPT_DIR/fixtures/entries.txt"
}

test_inline_writes_placeholders() {
    UVID_DEVICE=x bash "$UVID" "bare" > /dev/null
    assert_contains "$(cat "$LOG_FILE")" "bare [.] (-) {x}" "inline entry carries both placeholders"
}

test_inline_text_with_parens_not_read_as_source() {
    bash "$UVID" "idea (see chapter 3)" > /dev/null
    bash "$UVID" --export > /dev/null
    local content=$(cat "uvid_export_$(date +'%Y-%m-%d').md")
    assert_contains "$content" "idea (see chapter 3)" "parens kept in text"
    assert_not_contains "$content" "Source:" "parens not exported as source"
}

test_inline_collapses_newlines() {
    bash "$UVID" $'line one\nline   two' > /dev/null
    assert_equals "1" "$(wc -l < "$LOG_FILE" | tr -d ' ')" "entry stays on one line"
    assert_contains "$(cat "$LOG_FILE")" "line one line two [.]" "whitespace collapsed"
}

test_closing_brackets_stripped_from_fields() {
    bash "$UVID" "t" -a "a]b" -s "c)d" > /dev/null
    assert_contains "$(cat "$LOG_FILE")" "t [ab] (cd)" "closing brackets removed from author/source"
}

test_inline_rejects_unknown_flag() {
    local output=$(bash "$UVID" --lsit)
    assert_contains "$output" "Unknown flag: --lsit" "unknown flag rejected"
    assert_equals "false" "$([ -f "$LOG_FILE" ] && echo true || echo false)" "nothing logged"
}

test_list_hides_placeholders() {
    bash "$UVID" "plain" > /dev/null
    bash "$UVID" "sourced" -s "Blog" > /dev/null
    local output=$(bash "$UVID" --list)
    assert_not_contains "$output" "[.]" "author placeholder hidden"
    assert_not_contains "$output" "(-)" "source placeholder hidden"
    assert_contains "$output" "sourced (Blog)" "real source still shown"
    assert_contains "$(bash "$UVID" --list --verbose)" "plain [.] (-)" "--verbose shows placeholders"
}

test_search_hides_placeholders() {
    bash "$UVID" "findme" > /dev/null
    assert_not_contains "$(bash "$UVID" --search findme)" "[.]" "placeholder hidden in search"
}

# ---- Log store ----

test_all_logs_orders_and_filters() {
    source "$UVID"
    touch 02-2025_uvid.log 01-2026_uvid.log ocr_01-2026_uvid.log 2026_uvid.log 01-2026_uvid.log.bak
    assert_equals "$(all_logs | sed 's#.*/##' | tr '\n' ' ')" "02-2025_uvid.log 01-2026_uvid.log ocr_01-2026_uvid.log " \
        "year before month, streams after main, yearly and .bak ignored"
    assert_equals "$(all_logs 2025 | sed 's#.*/##')" "02-2025_uvid.log" "year filter"
}

test_replace_line_edits_and_deletes() {
    source "$UVID"
    printf 'a\\b\nsame\nsame\nlast' > "$LOG_FILE"
    replace_line "same" 'new\n'
    assert_equals "$(cat "$LOG_FILE")" $'a\\b\nnew\\n\nsame\nlast' "first match replaced, backslashes and unterminated last line kept"
    replace_line "last"
    assert_equals "$(cat "$LOG_FILE")" $'a\\b\nnew\\n\nsame' "delete when no replacement"
    replace_line "missing" && local rc=0 || local rc=1
    assert_equals "$rc" "1" "missing line reports failure"
}

test_list_merges_streams_by_timestamp() {
    local my="${MONTH_YEAR/-/.}"
    echo "[02.$my 09:00:00] main idea [.] (-)" > "$LOG_FILE"
    echo "[01.$my 10:00:00] ocr idea [.] (telegram-ocr)" > "ocr_$LOG_FILE"
    assert_equals "$(bash "$UVID" --list | tail -n 2)" "[01.$my 10:00:00] ocr idea (telegram-ocr)
[02.$my 09:00:00] main idea" "ocr entry listed, ordered by timestamp"
}

test_delete_from_ocr_stream() {
    local my="${MONTH_YEAR/-/.}"
    echo "[02.$my 09:00:00] main idea [.] (-)" > "$LOG_FILE"
    echo "[01.$my 10:00:00] ocr idea [.] (telegram-ocr)" > "ocr_$LOG_FILE"
    printf "\n1\n\n" | bash "$UVID" --delete > /dev/null
    assert_equals "$(cat "ocr_$LOG_FILE")" "" "ocr entry deleted from its own Log file"
    assert_contains "$(cat "$LOG_FILE")" "main idea" "main stream untouched"
}

test_export_orders_across_years() {
    echo "[01.01.2026 10:00] jan26 [.] (-)" > 01-2026_uvid.log
    echo "[01.02.2025 10:00] feb25 [.] (-)" > 02-2025_uvid.log
    bash "$UVID" --export > /dev/null
    assert_equals "$(grep -o 'feb25\|jan26' uvid_export_*.md | tr '\n' ' ')" "feb25 jan26 " "export is chronological across years"
}

# ---- PowerShell adapter (uvid.cmd runs Windows PowerShell 5.1) ----

PS=$(command -v powershell.exe || command -v powershell || true)
run_ps() { "$PS" -NoProfile -ExecutionPolicy Bypass -File "$SCRIPT_DIR/../uvid.ps1" "$@"; }

test_ps_args_survive_hop() {
    UVID_DEVICE=x run_ps "it's \"quoted\" čćž" -s "a b" > /dev/null
    assert_contains "$(cat "$LOG_FILE")" "] it's \"quoted\" čćž [.] (a b) {x}" "quotes and unicode reach bash intact"
}

test_ps_list_matches_bash() {
    bash "$UVID" "psplain" > /dev/null
    # Header differs: MSYS rewrites UVID_DIR to a Windows path on the way through PowerShell.
    assert_equals "$(bash "$UVID" --list 5 | tail -n +2)" "$(run_ps --list 5 | tail -n +2)" "ps --list output matches bash"
}

test_ps_unknown_flag_rejected() {
    assert_contains "$(run_ps --bogus)" "Unknown flag: --bogus" "ps reaches bash flag check"
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
run_test test_search_across_months
run_test test_edit_updates_text
run_test test_edit_preserves_timestamp
run_test test_edit_clears_author_with_space
run_test test_edit_keeps_all_on_empty_input
run_test test_edit_preserves_device_tag
run_test test_delete_removes_entry
run_test test_delete_cancel_with_n
run_test test_delete_default_confirm_is_yes
run_test test_delete_via_search
run_test test_export_creates_file
run_test test_export_contains_entries
run_test test_export_metadata_formatting
run_test test_export_no_entries
run_test test_export_across_months
run_test test_export_filter_search
run_test test_export_filter_author
run_test test_export_filter_author_case_insensitive
run_test test_export_filter_year
run_test test_export_filter_date_range
run_test test_export_filter_combined
run_test test_export_year_and_from_to_exclusive
run_test test_export_from_without_to
run_test test_export_includes_device
run_test test_export_no_device_when_missing
run_test test_set_device_creates_file
run_test test_set_device_rejects_invalid
run_test test_set_device_rejects_uppercase
run_test test_entry_includes_device_when_set
run_test test_entry_uses_hostname_fallback
run_test test_entry_has_seconds_in_timestamp
run_test test_device_from_env_var
run_test test_device_file_overridden_by_env
run_test test_list_hides_device_by_default
run_test test_list_verbose_shows_device
run_test test_search_hides_device_by_default
run_test test_search_verbose_shows_device
run_test test_edit_text_with_parens_keeps_source
run_test test_codec_matches_fixture
run_test test_inline_writes_placeholders
run_test test_inline_text_with_parens_not_read_as_source
run_test test_inline_collapses_newlines
run_test test_closing_brackets_stripped_from_fields
run_test test_inline_rejects_unknown_flag
run_test test_list_hides_placeholders
run_test test_search_hides_placeholders
run_test test_all_logs_orders_and_filters
run_test test_replace_line_edits_and_deletes
run_test test_list_merges_streams_by_timestamp
run_test test_delete_from_ocr_stream
run_test test_export_orders_across_years
if [ -n "$PS" ]; then
    run_test test_ps_args_survive_hop
    run_test test_ps_list_matches_bash
    run_test test_ps_unknown_flag_rejected
else
    echo ""; echo "SKIP: PowerShell parity tests (no powershell on PATH)"
fi

echo ""
echo "======================================"
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"
echo "======================================"

[ "$TESTS_FAILED" -eq 0 ]
