#!/bin/bash

# Test suite for Azure VM automation bash functions
# This script tests all VM automation functions with mock data

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FUNCTIONS_DIR="$PROJECT_ROOT/bash/functions/azure"
TEST_TMP_DIR="/tmp/azure-vm-test-$$"
MOCK_DIR="$TEST_TMP_DIR/mocks"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Cleanup function
cleanup() {
    rm -rf "$TEST_TMP_DIR"
}
trap cleanup EXIT

# Setup test environment
setup_test_env() {
    echo -e "${BLUE}Setting up test environment...${NC}"
    mkdir -p "$MOCK_DIR"
    mkdir -p "$TEST_TMP_DIR/ssh"
    
    # Create mock az command
    cat > "$MOCK_DIR/az" << 'EOF'
#!/bin/bash
# Mock Azure CLI for testing

case "$1" in
    "account")
        case "$2" in
            "show")
                echo '{"id": "test-sub-123", "name": "Test Subscription", "state": "Enabled"}'
                ;;
            "list")
                echo '[
                    {"id": "test-sub-123", "name": "AIRS-Setu-Test", "state": "Enabled"},
                    {"id": "test-sub-456", "name": "AIRS-Setu-Prod", "state": "Enabled"}
                ]'
                ;;
            "set")
                echo "Subscription set to: $4"
                ;;
        esac
        ;;
    "vm")
        case "$2" in
            "list")
                if [[ "$*" == *"-d"* ]]; then
                    echo '[
                        {
                            "name": "test-vm-1",
                            "resourceGroup": "test-rg",
                            "powerState": "VM running",
                            "location": "eastus",
                            "publicIps": "1.2.3.4",
                            "privateIps": "10.0.0.4",
                            "hardwareProfile": {"vmSize": "Standard_B2s"}
                        },
                        {
                            "name": "test-vm-2",
                            "resourceGroup": "test-rg",
                            "powerState": "VM deallocated",
                            "location": "westus",
                            "publicIps": "",
                            "privateIps": "10.0.0.5"
                        }
                    ]'
                fi
                ;;
            "show")
                echo '{
                    "name": "test-vm-1",
                    "resourceGroup": "test-rg",
                    "location": "eastus",
                    "hardwareProfile": {"vmSize": "Standard_B2s"},
                    "storageProfile": {"osDisk": {"osType": "Linux"}},
                    "publicIps": "1.2.3.4"
                }'
                ;;
            "start"|"stop"|"deallocate"|"delete")
                echo "VM operation $2 initiated for VM: $4"
                ;;
            "get-instance-view")
                echo '{
                    "name": "test-vm-1",
                    "instanceView": {
                        "statuses": [
                            {"code": "PowerState/running", "displayStatus": "VM running"}
                        ]
                    },
                    "provisioningState": "Succeeded"
                }'
                ;;
            "wait")
                sleep 0.1
                echo "Operation completed"
                ;;
        esac
        ;;
    "network")
        case "$2" in
            "public-ip")
                echo "Public IP created/updated: $6"
                ;;
            "nic")
                echo "NIC updated with public IP"
                ;;
            "nsg")
                case "$3" in
                    "rule")
                        echo '{
                            "name": "AllowSSH",
                            "priority": 100,
                            "sourceAddressPrefix": "192.168.1.0/24",
                            "destinationPortRange": "22"
                        }'
                        ;;
                esac
                ;;
        esac
        ;;
esac
EOF
    chmod +x "$MOCK_DIR/az"
    
    # Create mock jq if needed
    if ! command -v jq &> /dev/null; then
        cat > "$MOCK_DIR/jq" << 'EOF'
#!/bin/bash
# Simple mock jq for testing
cat
EOF
        chmod +x "$MOCK_DIR/jq"
    fi
    
    # Create mock fzf
    cat > "$MOCK_DIR/fzf" << 'EOF'
#!/bin/bash
# Mock fzf - returns first line of input
head -n1
EOF
    chmod +x "$MOCK_DIR/fzf"
    
    # Update PATH
    export PATH="$MOCK_DIR:$PATH"
    
    # Source the functions
    source "$FUNCTIONS_DIR/vm-automation.sh" 2>/dev/null || true
}

# Test helper functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [[ "$expected" == "$actual" ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} $test_name"
        echo -e "  Expected: $expected"
        echo -e "  Actual: $actual"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local test_name="$3"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [[ "$haystack" == *"$needle"* ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} $test_name"
        echo -e "  Expected to contain: $needle"
        echo -e "  Actual: $haystack"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_file_exists() {
    local file="$1"
    local test_name="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [[ -f "$file" ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} $test_name"
        echo -e "  File not found: $file"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test functions
test_environment_detection() {
    echo -e "\n${YELLOW}Testing environment detection...${NC}"
    
    local env=$(_detect_environment)
    assert_equals "dotfiles" "$env" "Environment detection"
}

test_requirements_check() {
    echo -e "\n${YELLOW}Testing requirements check...${NC}"
    
    # Test with all tools available
    _check_requirements
    local result=$?
    assert_equals "0" "$result" "Requirements check with all tools"
    
    # Test with missing tool
    local old_path="$PATH"
    PATH="/usr/bin:/bin"
    _check_requirements 2>/dev/null
    result=$?
    assert_equals "1" "$result" "Requirements check with missing tools"
    PATH="$old_path"
}

test_vm_list() {
    echo -e "\n${YELLOW}Testing VM list function...${NC}"
    
    local output=$(azvm_list 2>&1)
    assert_contains "$output" "Azure VMs:" "VM list header"
    assert_contains "$output" "test-vm-1" "VM list contains test-vm-1"
}

test_vm_status() {
    echo -e "\n${YELLOW}Testing VM status function...${NC}"
    
    # Test all VMs status
    local output=$(azvm_status 2>&1)
    assert_contains "$output" "All VMs Status:" "VM status header for all VMs"
    
    # Test specific VM status
    output=$(azvm_status "test-vm-1" "test-rg" 2>&1)
    assert_contains "$output" "VM Status for: test-vm-1" "VM status header for specific VM"
}

test_vm_start() {
    echo -e "\n${YELLOW}Testing VM start function...${NC}"
    
    local output=$(azvm_start "test-vm-1" "test-rg" 2>&1)
    assert_contains "$output" "Starting VM: test-vm-1" "VM start message"
    assert_contains "$output" "VM start initiated" "VM start confirmation"
}

test_vm_stop() {
    echo -e "\n${YELLOW}Testing VM stop function...${NC}"
    
    # Test deallocate
    local output=$(azvm_stop "test-vm-1" "test-rg" "true" 2>&1)
    assert_contains "$output" "Stopping VM: test-vm-1" "VM stop message"
    assert_contains "$output" "VM deallocate initiated" "VM deallocate confirmation"
    
    # Test stop without deallocate
    output=$(azvm_stop "test-vm-1" "test-rg" "false" 2>&1)
    assert_contains "$output" "will continue to be billed" "VM stop billing warning"
}

test_vm_delete() {
    echo -e "\n${YELLOW}Testing VM delete function...${NC}"
    
    # Test with force flag
    local output=$(azvm_delete "test-vm-1" "test-rg" "true" 2>&1)
    assert_contains "$output" "Deleting VM: test-vm-1" "VM delete message"
    assert_contains "$output" "VM deletion initiated" "VM delete confirmation"
}

test_vm_get_ip() {
    echo -e "\n${YELLOW}Testing VM get IP function...${NC}"
    
    local output=$(azvm_get_ip "test-vm-1" "test-rg" 2>&1)
    assert_contains "$output" "Public IP for test-vm-1: 1.2.3.4" "VM IP retrieval"
    
    # Test VM without public IP
    output=$(azvm_get_ip "test-vm-2" "test-rg" 2>&1)
    assert_contains "$output" "No public IP assigned" "VM without IP message"
}

test_vm_ssh_config() {
    echo -e "\n${YELLOW}Testing VM SSH config generation...${NC}"
    
    # Redirect stdin to provide 'n' answer
    local output=$(echo "n" | azvm_ssh_config "test-vm-1" "test-rg" 2>&1)
    assert_contains "$output" "SSH Config for test-vm-1:" "SSH config header"
    assert_contains "$output" "Host azure-test-vm-1" "SSH config host entry"
    assert_contains "$output" "HostName 1.2.3.4" "SSH config hostname"
}

test_vm_wait() {
    echo -e "\n${YELLOW}Testing VM wait function...${NC}"
    
    local output=$(azvm_wait "test-vm-1" "test-rg" "updated" 2>&1)
    assert_contains "$output" "Waiting for VM test-vm-1" "VM wait message"
    assert_contains "$output" "VM test-vm-1 is now updated" "VM wait completion"
}

test_subscription_function() {
    echo -e "\n${YELLOW}Testing subscription function...${NC}"
    
    # Source the subscription function
    if [[ -f "$FUNCTIONS_DIR/set_azure_subcription.sh" ]]; then
        source "$FUNCTIONS_DIR/set_azure_subcription.sh"
        
        # Test with pattern
        local output=$(echo "AIRS-Setu-Test test-sub-123" | azs "AIRS-Setu-" 2>&1)
        assert_contains "$output" "Switched to subscription" "Subscription switch message"
    else
        echo -e "${YELLOW}Skipping subscription test - file not found${NC}"
    fi
}

test_error_handling() {
    echo -e "\n${YELLOW}Testing error handling...${NC}"
    
    # Test with invalid parameters
    local output=$(azvm_assign_ip 2>&1)
    assert_contains "$output" "Usage:" "Error message for missing parameters"
    
    # Test wait function with missing parameters
    output=$(azvm_wait 2>&1)
    assert_contains "$output" "Usage:" "Wait function usage message"
}

test_interactive_mode() {
    echo -e "\n${YELLOW}Testing interactive mode...${NC}"
    
    # Test VM selection with no input (simulating cancel)
    local output=$(echo "" | azvm_start 2>&1)
    assert_contains "$output" "No VM selected" "Interactive mode cancellation"
}

# Performance test
test_performance() {
    echo -e "\n${YELLOW}Testing performance...${NC}"
    
    local start_time=$(date +%s.%N)
    azvm_list >/dev/null 2>&1
    local end_time=$(date +%s.%N)
    
    local duration=$(echo "$end_time - $start_time" | bc)
    local duration_ms=$(echo "$duration * 1000" | bc | cut -d. -f1)
    
    # Check if operation completed in reasonable time (< 1000ms)
    if [[ $duration_ms -lt 1000 ]]; then
        echo -e "${GREEN}✓${NC} Performance test (${duration_ms}ms)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} Performance test (${duration_ms}ms > 1000ms)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}

# Main test execution
main() {
    echo -e "${BLUE}Azure VM Automation Bash Functions Test Suite${NC}"
    echo -e "${BLUE}=============================================${NC}"
    
    setup_test_env
    
    # Run all tests
    test_environment_detection
    test_requirements_check
    test_vm_list
    test_vm_status
    test_vm_start
    test_vm_stop
    test_vm_delete
    test_vm_get_ip
    test_vm_ssh_config
    test_vm_wait
    test_subscription_function
    test_error_handling
    test_interactive_mode
    test_performance
    
    # Summary
    echo -e "\n${BLUE}Test Summary${NC}"
    echo -e "${BLUE}============${NC}"
    echo -e "Tests run: $TESTS_RUN"
    echo -e "${GREEN}Tests passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Tests failed: $TESTS_FAILED${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "\n${RED}Some tests failed!${NC}"
        exit 1
    fi
}

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi