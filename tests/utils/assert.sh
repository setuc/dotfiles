#!/bin/bash

# Assertion functions for test suites
# Provides a comprehensive set of assertions for bash testing

set -euo pipefail

# Import test helpers if available
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/test-helpers.sh" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/test-helpers.sh"
else
    # Define colors if not imported
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m'
fi

# Assertion counters
ASSERTIONS_RUN=0
ASSERTIONS_PASSED=0
ASSERTIONS_FAILED=0

# Core assertion function
_assert() {
    local assertion_type="$1"
    local expected="$2"
    local actual="$3"
    local message="${4:-Assertion failed}"
    local operator="${5:-==}"
    
    ASSERTIONS_RUN=$((ASSERTIONS_RUN + 1))
    
    local result=false
    case "$operator" in
        "==")
            [[ "$actual" == "$expected" ]] && result=true
            ;;
        "!=")
            [[ "$actual" != "$expected" ]] && result=true
            ;;
        "-eq")
            [[ "$actual" -eq "$expected" ]] && result=true
            ;;
        "-ne")
            [[ "$actual" -ne "$expected" ]] && result=true
            ;;
        "-gt")
            [[ "$actual" -gt "$expected" ]] && result=true
            ;;
        "-ge")
            [[ "$actual" -ge "$expected" ]] && result=true
            ;;
        "-lt")
            [[ "$actual" -lt "$expected" ]] && result=true
            ;;
        "-le")
            [[ "$actual" -le "$expected" ]] && result=true
            ;;
        "=~")
            [[ "$actual" =~ $expected ]] && result=true
            ;;
    esac
    
    if [[ "$result" == true ]]; then
        ASSERTIONS_PASSED=$((ASSERTIONS_PASSED + 1))
        [[ "${VERBOSE:-false}" == "true" ]] && echo -e "${GREEN}✓${NC} $message"
        return 0
    else
        ASSERTIONS_FAILED=$((ASSERTIONS_FAILED + 1))
        echo -e "${RED}✗ $assertion_type failed: $message${NC}"
        echo -e "  Expected: $expected"
        echo -e "  Actual: $actual"
        return 1
    fi
}

# String assertions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Values should be equal}"
    
    _assert "assert_equals" "$expected" "$actual" "$message" "=="
}

assert_not_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Values should not be equal}"
    
    _assert "assert_not_equals" "$expected" "$actual" "$message" "!="
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-String should contain substring}"
    
    ASSERTIONS_RUN=$((ASSERTIONS_RUN + 1))
    
    if [[ "$haystack" == *"$needle"* ]]; then
        ASSERTIONS_PASSED=$((ASSERTIONS_PASSED + 1))
        [[ "${VERBOSE:-false}" == "true" ]] && echo -e "${GREEN}✓${NC} $message"
        return 0
    else
        ASSERTIONS_FAILED=$((ASSERTIONS_FAILED + 1))
        echo -e "${RED}✗ assert_contains failed: $message${NC}"
        echo -e "  String: $haystack"
        echo -e "  Should contain: $needle"
        return 1
    fi
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-String should not contain substring}"
    
    ASSERTIONS_RUN=$((ASSERTIONS_RUN + 1))
    
    if [[ "$haystack" != *"$needle"* ]]; then
        ASSERTIONS_PASSED=$((ASSERTIONS_PASSED + 1))
        [[ "${VERBOSE:-false}" == "true" ]] && echo -e "${GREEN}✓${NC} $message"
        return 0
    else
        ASSERTIONS_FAILED=$((ASSERTIONS_FAILED + 1))
        echo -e "${RED}✗ assert_not_contains failed: $message${NC}"
        echo -e "  String: $haystack"
        echo -e "  Should not contain: $needle"
        return 1
    fi
}

assert_matches() {
    local string="$1"
    local pattern="$2"
    local message="${3:-String should match pattern}"
    
    _assert "assert_matches" "$pattern" "$string" "$message" "=~"
}

assert_empty() {
    local value="$1"
    local message="${2:-Value should be empty}"
    
    ASSERTIONS_RUN=$((ASSERTIONS_RUN + 1))
    
    if [[ -z "$value" ]]; then
        ASSERTIONS_PASSED=$((ASSERTIONS_PASSED + 1))
        [[ "${VERBOSE:-false}" == "true" ]] && echo -e "${GREEN}✓${NC} $message"
        return 0
    else
        ASSERTIONS_FAILED=$((ASSERTIONS_FAILED + 1))
        echo -e "${RED}✗ assert_empty failed: $message${NC}"
        echo -e "  Value: '$value' (length: ${#value})"
        return 1
    fi
}

assert_not_empty() {
    local value="$1"
    local message="${2:-Value should not be empty}"
    
    ASSERTIONS_RUN=$((ASSERTIONS_RUN + 1))
    
    if [[ -n "$value" ]]; then
        ASSERTIONS_PASSED=$((ASSERTIONS_PASSED + 1))
        [[ "${VERBOSE:-false}" == "true" ]] && echo -e "${GREEN}✓${NC} $message"
        return 0
    else
        ASSERTIONS_FAILED=$((ASSERTIONS_FAILED + 1))
        echo -e "${RED}✗ assert_not_empty failed: $message${NC}"
        echo -e "  Value is empty"
        return 1
    fi
}

# Numeric assertions
assert_eq() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Numbers should be equal}"
    
    _assert "assert_eq" "$expected" "$actual" "$message" "-eq"
}

assert_ne() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Numbers should not be equal}"
    
    _assert "assert_ne" "$expected" "$actual" "$message" "-ne"
}

assert_gt() {
    local expected="$1"
    local actual="$2"
    local message="${3:-$actual should be greater than $expected}"
    
    _assert "assert_gt" "$expected" "$actual" "$message" "-gt"
}

assert_ge() {
    local expected="$1"
    local actual="$2"
    local message="${3:-$actual should be greater than or equal to $expected}"
    
    _assert "assert_ge" "$expected" "$actual" "$message" "-ge"
}

assert_lt() {
    local expected="$1"
    local actual="$2"
    local message="${3:-$actual should be less than $expected}"
    
    _assert "assert_lt" "$expected" "$actual" "$message" "-lt"
}

assert_le() {
    local expected="$1"
    local actual="$2"
    local message="${3:-$actual should be less than or equal to $expected}"
    
    _assert "assert_le" "$expected" "$actual" "$message" "-le"
}

# Boolean assertions
assert_true() {
    local condition="$1"
    local message="${2:-Condition should be true}"
    
    ASSERTIONS_RUN=$((ASSERTIONS_RUN + 1))
    
    if [[ "$condition" == "true" || "$condition" == "1" || "$condition" == "yes" ]]; then
        ASSERTIONS_PASSED=$((ASSERTIONS_PASSED + 1))
        [[ "${VERBOSE:-false}" == "true" ]] && echo -e "${GREEN}✓${NC} $message"
        return 0
    else
        ASSERTIONS_FAILED=$((ASSERTIONS_FAILED + 1))
        echo -e "${RED}✗ assert_true failed: $message${NC}"
        echo -e "  Value: $condition"
        return 1
    fi
}

assert_false() {
    local condition="$1"
    local message="${2:-Condition should be false}"
    
    ASSERTIONS_RUN=$((ASSERTIONS_RUN + 1))
    
    if [[ "$condition" == "false" || "$condition" == "0" || "$condition" == "no" || -z "$condition" ]]; then
        ASSERTIONS_PASSED=$((ASSERTIONS_PASSED + 1))
        [[ "${VERBOSE:-false}" == "true" ]] && echo -e "${GREEN}✓${NC} $message"
        return 0
    else
        ASSERTIONS_FAILED=$((ASSERTIONS_FAILED + 1))
        echo -e "${RED}✗ assert_false failed: $message${NC}"
        echo -e "  Value: $condition"
        return 1
    fi
}

# File system assertions
assert_file_exists() {
    local file_path="$1"
    local message="${2:-File should exist: $file_path}"
    
    ASSERTIONS_RUN=$((ASSERTIONS_RUN + 1))
    
    if [[ -f "$file_path" ]]; then
        ASSERTIONS_PASSED=$((ASSERTIONS_PASSED + 1))
        [[ "${VERBOSE:-false}" == "true" ]] && echo -e "${GREEN}✓${NC} $message"
        return 0
    else
        ASSERTIONS_FAILED=$((ASSERTIONS_FAILED + 1))
        echo -e "${RED}✗ assert_file_exists failed: $message${NC}"
        echo -e "  File not found: $file_path"
        return 1
    fi
}

assert_file_not_exists() {
    local file_path="$1"
    local message="${2:-File should not exist: $file_path}"
    
    ASSERTIONS_RUN=$((ASSERTIONS_RUN + 1))
    
    if [[ ! -f "$file_path" ]]; then
        ASSERTIONS_PASSED=$((ASSERTIONS_PASSED + 1))
        [[ "${VERBOSE:-false}" == "true" ]] && echo -e "${GREEN}✓${NC} $message"
        return 0
    else
        ASSERTIONS_FAILED=$((ASSERTIONS_FAILED + 1))
        echo -e "${RED}✗ assert_file_not_exists failed: $message${NC}"
        echo -e "  File exists: $file_path"
        return 1
    fi
}

assert_dir_exists() {
    local dir_path="$1"
    local message="${2:-Directory should exist: $dir_path}"
    
    ASSERTIONS_RUN=$((ASSERTIONS_RUN + 1))
    
    if [[ -d "$dir_path" ]]; then
        ASSERTIONS_PASSED=$((ASSERTIONS_PASSED + 1))
        [[ "${VERBOSE:-false}" == "true" ]] && echo -e "${GREEN}✓${NC} $message"
        return 0
    else
        ASSERTIONS_FAILED=$((ASSERTIONS_FAILED + 1))
        echo -e "${RED}✗ assert_dir_exists failed: $message${NC}"
        echo -e "  Directory not found: $dir_path"
        return 1
    fi
}

assert_dir_not_exists() {
    local dir_path="$1"
    local message="${2:-Directory should not exist: $dir_path}"
    
    ASSERTIONS_RUN=$((ASSERTIONS_RUN + 1))
    
    if [[ ! -d "$dir_path" ]]; then
        ASSERTIONS_PASSED=$((ASSERTIONS_PASSED + 1))
        [[ "${VERBOSE:-false}" == "true" ]] && echo -e "${GREEN}✓${NC} $message"
        return 0
    else
        ASSERTIONS_FAILED=$((ASSERTIONS_FAILED + 1))
        echo -e "${RED}✗ assert_dir_not_exists failed: $message${NC}"
        echo -e "  Directory exists: $dir_path"
        return 1
    fi
}

assert_file_contains() {
    local file_path="$1"
    local content="$2"
    local message="${3:-File should contain: $content}"
    
    ASSERTIONS_RUN=$((ASSERTIONS_RUN + 1))
    
    if [[ -f "$file_path" ]] && grep -q "$content" "$file_path"; then
        ASSERTIONS_PASSED=$((ASSERTIONS_PASSED + 1))
        [[ "${VERBOSE:-false}" == "true" ]] && echo -e "${GREEN}✓${NC} $message"
        return 0
    else
        ASSERTIONS_FAILED=$((ASSERTIONS_FAILED + 1))
        echo -e "${RED}✗ assert_file_contains failed: $message${NC}"
        if [[ ! -f "$file_path" ]]; then
            echo -e "  File not found: $file_path"
        else
            echo -e "  File: $file_path"
            echo -e "  Does not contain: $content"
        fi
        return 1
    fi
}

assert_file_not_contains() {
    local file_path="$1"
    local content="$2"
    local message="${3:-File should not contain: $content}"
    
    ASSERTIONS_RUN=$((ASSERTIONS_RUN + 1))
    
    if [[ -f "$file_path" ]] && ! grep -q "$content" "$file_path"; then
        ASSERTIONS_PASSED=$((ASSERTIONS_PASSED + 1))
        [[ "${VERBOSE:-false}" == "true" ]] && echo -e "${GREEN}✓${NC} $message"
        return 0
    else
        ASSERTIONS_FAILED=$((ASSERTIONS_FAILED + 1))
        echo -e "${RED}✗ assert_file_not_contains failed: $message${NC}"
        if [[ ! -f "$file_path" ]]; then
            echo -e "  File not found: $file_path"
        else
            echo -e "  File: $file_path"
            echo -e "  Contains: $content"
        fi
        return 1
    fi
}

# Command assertions
assert_command_exists() {
    local command="$1"
    local message="${2:-Command should exist: $command}"
    
    ASSERTIONS_RUN=$((ASSERTIONS_RUN + 1))
    
    if command -v "$command" &> /dev/null; then
        ASSERTIONS_PASSED=$((ASSERTIONS_PASSED + 1))
        [[ "${VERBOSE:-false}" == "true" ]] && echo -e "${GREEN}✓${NC} $message"
        return 0
    else
        ASSERTIONS_FAILED=$((ASSERTIONS_FAILED + 1))
        echo -e "${RED}✗ assert_command_exists failed: $message${NC}"
        echo -e "  Command not found: $command"
        return 1
    fi
}

assert_exit_code() {
    local expected_code="$1"
    local command="$2"
    local message="${3:-Command should exit with code $expected_code}"
    
    ASSERTIONS_RUN=$((ASSERTIONS_RUN + 1))
    
    # Run command and capture exit code
    eval "$command" &> /dev/null
    local actual_code=$?
    
    if [[ $actual_code -eq $expected_code ]]; then
        ASSERTIONS_PASSED=$((ASSERTIONS_PASSED + 1))
        [[ "${VERBOSE:-false}" == "true" ]] && echo -e "${GREEN}✓${NC} $message"
        return 0
    else
        ASSERTIONS_FAILED=$((ASSERTIONS_FAILED + 1))
        echo -e "${RED}✗ assert_exit_code failed: $message${NC}"
        echo -e "  Command: $command"
        echo -e "  Expected exit code: $expected_code"
        echo -e "  Actual exit code: $actual_code"
        return 1
    fi
}

assert_output_contains() {
    local command="$1"
    local expected_output="$2"
    local message="${3:-Command output should contain: $expected_output}"
    
    ASSERTIONS_RUN=$((ASSERTIONS_RUN + 1))
    
    # Run command and capture output
    local actual_output=$(eval "$command" 2>&1)
    
    if [[ "$actual_output" == *"$expected_output"* ]]; then
        ASSERTIONS_PASSED=$((ASSERTIONS_PASSED + 1))
        [[ "${VERBOSE:-false}" == "true" ]] && echo -e "${GREEN}✓${NC} $message"
        return 0
    else
        ASSERTIONS_FAILED=$((ASSERTIONS_FAILED + 1))
        echo -e "${RED}✗ assert_output_contains failed: $message${NC}"
        echo -e "  Command: $command"
        echo -e "  Expected output to contain: $expected_output"
        echo -e "  Actual output: $actual_output"
        return 1
    fi
}

# Array assertions
assert_array_contains() {
    local -n array=$1
    local element="$2"
    local message="${3:-Array should contain: $element}"
    
    ASSERTIONS_RUN=$((ASSERTIONS_RUN + 1))
    
    for item in "${array[@]}"; do
        if [[ "$item" == "$element" ]]; then
            ASSERTIONS_PASSED=$((ASSERTIONS_PASSED + 1))
            [[ "${VERBOSE:-false}" == "true" ]] && echo -e "${GREEN}✓${NC} $message"
            return 0
        fi
    done
    
    ASSERTIONS_FAILED=$((ASSERTIONS_FAILED + 1))
    echo -e "${RED}✗ assert_array_contains failed: $message${NC}"
    echo -e "  Array: [${array[*]}]"
    echo -e "  Missing element: $element"
    return 1
}

assert_array_length() {
    local -n array=$1
    local expected_length="$2"
    local message="${3:-Array should have length: $expected_length}"
    
    ASSERTIONS_RUN=$((ASSERTIONS_RUN + 1))
    
    local actual_length=${#array[@]}
    
    if [[ $actual_length -eq $expected_length ]]; then
        ASSERTIONS_PASSED=$((ASSERTIONS_PASSED + 1))
        [[ "${VERBOSE:-false}" == "true" ]] && echo -e "${GREEN}✓${NC} $message"
        return 0
    else
        ASSERTIONS_FAILED=$((ASSERTIONS_FAILED + 1))
        echo -e "${RED}✗ assert_array_length failed: $message${NC}"
        echo -e "  Expected length: $expected_length"
        echo -e "  Actual length: $actual_length"
        echo -e "  Array: [${array[*]}]"
        return 1
    fi
}

# Special assertions
assert_json_valid() {
    local json_string="$1"
    local message="${2:-JSON should be valid}"
    
    ASSERTIONS_RUN=$((ASSERTIONS_RUN + 1))
    
    if echo "$json_string" | jq . >/dev/null 2>&1; then
        ASSERTIONS_PASSED=$((ASSERTIONS_PASSED + 1))
        [[ "${VERBOSE:-false}" == "true" ]] && echo -e "${GREEN}✓${NC} $message"
        return 0
    else
        ASSERTIONS_FAILED=$((ASSERTIONS_FAILED + 1))
        echo -e "${RED}✗ assert_json_valid failed: $message${NC}"
        echo -e "  Invalid JSON: $json_string"
        return 1
    fi
}

assert_fail() {
    local message="${1:-This assertion should always fail}"
    
    ASSERTIONS_RUN=$((ASSERTIONS_RUN + 1))
    ASSERTIONS_FAILED=$((ASSERTIONS_FAILED + 1))
    
    echo -e "${RED}✗ assert_fail: $message${NC}"
    return 1
}

# Assertion summary
assertion_summary() {
    echo -e "\n${YELLOW}Assertion Summary:${NC}"
    echo -e "Total assertions: $ASSERTIONS_RUN"
    echo -e "${GREEN}Passed: $ASSERTIONS_PASSED${NC}"
    echo -e "${RED}Failed: $ASSERTIONS_FAILED${NC}"
    
    if [[ $ASSERTIONS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}All assertions passed!${NC}"
        return 0
    else
        echo -e "\n${RED}Some assertions failed!${NC}"
        return 1
    fi
}

# Reset assertion counters
reset_assertions() {
    ASSERTIONS_RUN=0
    ASSERTIONS_PASSED=0
    ASSERTIONS_FAILED=0
}

# Export all assertion functions
export -f _assert
export -f assert_equals assert_not_equals assert_contains assert_not_contains
export -f assert_matches assert_empty assert_not_empty
export -f assert_eq assert_ne assert_gt assert_ge assert_lt assert_le
export -f assert_true assert_false
export -f assert_file_exists assert_file_not_exists assert_dir_exists assert_dir_not_exists
export -f assert_file_contains assert_file_not_contains
export -f assert_command_exists assert_exit_code assert_output_contains
export -f assert_array_contains assert_array_length
export -f assert_json_valid assert_fail
export -f assertion_summary reset_assertions

# Display assertion info if sourced directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Assertion Functions Loaded"
    echo "========================="
    echo "Available assertions:"
    echo "  String: assert_equals, assert_contains, assert_matches, assert_empty"
    echo "  Numeric: assert_eq, assert_gt, assert_lt"
    echo "  Boolean: assert_true, assert_false"
    echo "  File: assert_file_exists, assert_file_contains"
    echo "  Command: assert_command_exists, assert_exit_code"
    echo "  Array: assert_array_contains, assert_array_length"
    echo "  Special: assert_json_valid, assert_fail"
    echo ""
    echo "Use assertion_summary() to display results"
    echo "Use reset_assertions() to reset counters"
fi