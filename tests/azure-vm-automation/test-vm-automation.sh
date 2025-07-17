#!/bin/bash

# Test script for Azure VM automation functions
# This script verifies that functions are properly loaded and can handle various scenarios

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Test function
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_result="${3:-0}"  # Default expect success (0)
    
    echo -e "${YELLOW}Testing: $test_name${NC}"
    
    # Run the test command
    eval "$test_command"
    local result=$?
    
    if [[ $result -eq $expected_result ]]; then
        echo -e "${GREEN}✓ PASSED${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAILED (expected $expected_result, got $result)${NC}"
        ((TESTS_FAILED++))
    fi
    echo
}

# Source the VM automation functions
echo -e "${YELLOW}Loading VM automation functions...${NC}"
source "$(dirname "${BASH_SOURCE[0]}")/vm-automation-loader.sh"

echo -e "\n${YELLOW}=== Starting VM Automation Tests ===${NC}\n"

# Test 1: Check if functions are loaded
run_test "Functions loaded" "type azvm_start &> /dev/null"

# Test 2: Check requirements function
run_test "Requirements check" "_check_requirements"

# Test 3: Environment detection
run_test "Environment detection" "_detect_environment &> /dev/null"

# Test 4: Test VM listing (dry run - won't actually call Azure)
run_test "VM list function exists" "type azvm_list &> /dev/null"

# Test 5: Check if subscription function is available
run_test "Subscription function available" "type azs &> /dev/null"

# Test 6: Verify all main functions are exported
echo -e "${YELLOW}Checking exported functions...${NC}"
for func in azvm_start azvm_stop azvm_delete azvm_status azvm_get_ip azvm_ssh azvm_list; do
    if type $func &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} $func"
        ((TESTS_PASSED++))
    else
        echo -e "  ${RED}✗${NC} $func"
        ((TESTS_FAILED++))
    fi
done
echo

# Test 7: Check alias loading
echo -e "${YELLOW}Checking if aliases would be available...${NC}"
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/../../aliases/azure.aliases" ]]; then
    echo -e "${GREEN}✓ Azure aliases file found${NC}"
    ((TESTS_PASSED++))
    
    # Count VM-related aliases
    vm_alias_count=$(grep -c "azvm" "$(dirname "${BASH_SOURCE[0]}")/../../aliases/azure.aliases")
    echo -e "  Found $vm_alias_count VM-related aliases"
else
    echo -e "${RED}✗ Azure aliases file not found${NC}"
    ((TESTS_FAILED++))
fi
echo

# Test 8: Standalone mode test
echo -e "${YELLOW}Testing standalone mode...${NC}"
(
    # Subshell to isolate environment
    unset -f azvm_start 2>/dev/null
    bash "$(dirname "${BASH_SOURCE[0]}")/vm-automation-loader.sh" > /dev/null 2>&1
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ Standalone mode works${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ Standalone mode failed${NC}"
        ((TESTS_FAILED++))
    fi
)
echo

# Summary
echo -e "${YELLOW}=== Test Summary ===${NC}"
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"

# Only exit if the script is being run directly, not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}All tests passed! VM automation functions are ready to use.${NC}"
        exit 0
    else
        echo -e "\n${RED}Some tests failed. Please check the output above.${NC}"
        exit 1
    fi
else
    # When sourced, just show the summary without exiting
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}All tests passed! VM automation functions are ready to use.${NC}"
    else
        echo -e "\n${RED}Some tests failed. Please check the output above.${NC}"
    fi
fi