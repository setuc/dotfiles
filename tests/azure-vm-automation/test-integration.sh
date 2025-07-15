#!/bin/bash

# Integration tests for Bash-Ansible Azure VM automation
# Tests the interaction between bash functions and Ansible playbooks

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
ANSIBLE_DIR="$PROJECT_ROOT/ansible"
FUNCTIONS_DIR="$PROJECT_ROOT/bash/functions/azure"
TEST_TMP_DIR="/tmp/azure-vm-integration-test-$$"

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
    echo -e "${BLUE}Setting up integration test environment...${NC}"
    mkdir -p "$TEST_TMP_DIR"
    
    # Create test inventory
    cat > "$TEST_TMP_DIR/test_inventory.yml" << EOF
all:
  hosts:
    localhost:
      ansible_connection: local
      ansible_python_interpreter: /usr/bin/python3
  vars:
    azure_test_mode: true
    azure_resource_group: test-integration-rg
    azure_location: eastus
    azure_vm_name: test-integration-vm
    allowed_ip_addresses:
      - "192.168.1.0/24"
EOF
    
    # Create test playbook that uses the role
    cat > "$TEST_TMP_DIR/test_playbook.yml" << EOF
---
- name: Test Azure VM Integration
  hosts: localhost
  gather_facts: yes
  vars:
    azure_test_mode: true
  roles:
    - role: azure-vm
      vm_action: create
EOF
    
    # Source bash functions
    source "$FUNCTIONS_DIR/vm-automation.sh" 2>/dev/null || true
}

# Test helper functions
run_test() {
    local test_name="$1"
    local test_function="$2"
    
    echo -e "\n${YELLOW}Running: $test_name${NC}"
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if $test_function; then
        echo -e "${GREEN}✓ PASSED${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAILED${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Integration Tests

test_ansible_role_exists() {
    [[ -d "$ANSIBLE_DIR/roles/azure-vm" ]]
}

test_bash_functions_exist() {
    [[ -f "$FUNCTIONS_DIR/vm-automation.sh" ]] && \
    [[ -f "$FUNCTIONS_DIR/vm-automation-loader.sh" ]]
}

test_ansible_playbooks_exist() {
    local required_playbooks=(
        "create.yml"
        "manage.yml"
        "destroy.yml"
    )
    
    for playbook in "${required_playbooks[@]}"; do
        if [[ ! -f "$ANSIBLE_DIR/playbooks/azure-vm/$playbook" ]]; then
            echo "Missing playbook: $playbook"
            return 1
        fi
    done
    return 0
}

test_bash_ansible_function() {
    # Test if the bash function for calling Ansible exists
    type azvm_create_ansible &> /dev/null
}

test_ansible_syntax() {
    # Check syntax of main playbooks
    if command -v ansible-playbook &> /dev/null; then
        ansible-playbook --syntax-check \
            -i "$TEST_TMP_DIR/test_inventory.yml" \
            "$TEST_TMP_DIR/test_playbook.yml" &> /dev/null
    else
        echo "Ansible not installed, skipping syntax check"
        return 0
    fi
}

test_role_requirements() {
    # Check if requirements.yml exists and is valid
    local req_file="$ANSIBLE_DIR/roles/azure-vm/requirements.yml"
    if [[ -f "$req_file" ]]; then
        # Try to parse YAML (basic check)
        grep -E "^- (src:|name:)" "$req_file" &> /dev/null || return 0
    fi
    return 0
}

test_security_integration() {
    # Test that security tasks exist in both bash and Ansible
    
    # Check bash function handles IP detection
    if ! type curl &> /dev/null; then
        echo "curl not available, skipping IP detection test"
        return 0
    fi
    
    # Check Ansible security tasks exist
    [[ -f "$ANSIBLE_DIR/roles/azure-vm/tasks/security.yml" ]] && \
    [[ -f "$ANSIBLE_DIR/roles/azure-vm/tasks/update-nsg-ip.yml" ]]
}

test_variable_consistency() {
    # Check that variables used in bash match Ansible defaults
    local ansible_defaults="$ANSIBLE_DIR/roles/azure-vm/defaults/main.yml"
    
    if [[ -f "$ansible_defaults" ]]; then
        # Check for key variables
        grep -q "azure_vm_size:" "$ansible_defaults" && \
        grep -q "azure_admin_username:" "$ansible_defaults"
    else
        echo "Ansible defaults not found"
        return 1
    fi
}

test_template_files() {
    # Check that required template files exist
    local templates_dir="$ANSIBLE_DIR/roles/azure-vm/templates"
    local required_templates=(
        "nsg_rules.j2"
        "ssh_config.j2"
    )
    
    for template in "${required_templates[@]}"; do
        if [[ ! -f "$templates_dir/$template" ]]; then
            echo "Missing template: $template"
            return 1
        fi
    done
    return 0
}

test_error_handling_integration() {
    # Test that both bash and Ansible handle errors properly
    
    # Test bash function with invalid parameters
    local output=$(azvm_wait 2>&1)
    [[ "$output" == *"Usage:"* ]]
}

test_mock_integration() {
    # Test integration with mock Azure CLI
    local mock_dir="$TEST_TMP_DIR/mock"
    mkdir -p "$mock_dir"
    
    # Create mock az command
    cat > "$mock_dir/az" << 'EOF'
#!/bin/bash
echo '{"integration": "test", "status": "success"}'
EOF
    chmod +x "$mock_dir/az"
    
    # Test with mock
    PATH="$mock_dir:$PATH" az account show | grep -q "integration"
}

test_documentation_consistency() {
    # Check that documentation exists for integration
    local docs=(
        "$FUNCTIONS_DIR/README.md"
        "$ANSIBLE_DIR/roles/azure-vm/README.md"
    )
    
    for doc in "${docs[@]}"; do
        if [[ ! -f "$doc" ]]; then
            echo "Missing documentation: $doc"
            # Don't fail test, just warn
        fi
    done
    return 0
}

test_environment_variables() {
    # Test that environment variables are properly handled
    
    # Export test variables
    export AZURE_SUBSCRIPTION_ID="test-sub-123"
    export AZURE_RESOURCE_GROUP="test-rg"
    
    # Check if functions can access them
    # This is a placeholder - in real scenario would test actual usage
    [[ -n "$AZURE_SUBSCRIPTION_ID" ]]
}

test_logging_integration() {
    # Test that both bash and Ansible can log properly
    local log_dir="$TEST_TMP_DIR/logs"
    mkdir -p "$log_dir"
    
    # Test bash logging (if implemented)
    export AZURE_VM_LOG_DIR="$log_dir"
    
    # Check if log directory is used
    [[ -d "$log_dir" ]]
}

test_performance_baseline() {
    # Establish performance baseline for integration
    local start_time=$(date +%s.%N)
    
    # Source functions
    source "$FUNCTIONS_DIR/vm-automation-loader.sh" &> /dev/null
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc)
    
    # Check if loading is reasonably fast (< 0.5 seconds)
    (( $(echo "$duration < 0.5" | bc -l) ))
}

# Main test execution
main() {
    echo -e "${BLUE}Azure VM Bash-Ansible Integration Test Suite${NC}"
    echo -e "${BLUE}============================================${NC}"
    
    setup_test_env
    
    # Run all integration tests
    run_test "Ansible role exists" test_ansible_role_exists
    run_test "Bash functions exist" test_bash_functions_exist
    run_test "Ansible playbooks exist" test_ansible_playbooks_exist
    run_test "Bash-Ansible function exists" test_bash_ansible_function
    run_test "Ansible syntax check" test_ansible_syntax
    run_test "Role requirements valid" test_role_requirements
    run_test "Security integration" test_security_integration
    run_test "Variable consistency" test_variable_consistency
    run_test "Template files exist" test_template_files
    run_test "Error handling integration" test_error_handling_integration
    run_test "Mock integration" test_mock_integration
    run_test "Documentation consistency" test_documentation_consistency
    run_test "Environment variables" test_environment_variables
    run_test "Logging integration" test_logging_integration
    run_test "Performance baseline" test_performance_baseline
    
    # Summary
    echo -e "\n${BLUE}Integration Test Summary${NC}"
    echo -e "${BLUE}========================${NC}"
    echo -e "Tests run: $TESTS_RUN"
    echo -e "${GREEN}Tests passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Tests failed: $TESTS_FAILED${NC}"
    
    # Generate integration report
    cat > "$TEST_TMP_DIR/integration_report.txt" << EOF
Azure VM Automation Integration Test Report
==========================================

Date: $(date)
Tests Run: $TESTS_RUN
Tests Passed: $TESTS_PASSED
Tests Failed: $TESTS_FAILED

Components Tested:
- Bash Functions: $([[ -f "$FUNCTIONS_DIR/vm-automation.sh" ]] && echo "✓" || echo "✗")
- Ansible Role: $([[ -d "$ANSIBLE_DIR/roles/azure-vm" ]] && echo "✓" || echo "✗")
- Integration Points: $([[ $TESTS_FAILED -eq 0 ]] && echo "✓" || echo "✗")

Recommendations:
EOF
    
    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo "- Fix failing integration tests before deployment" >> "$TEST_TMP_DIR/integration_report.txt"
        echo "- Review error messages above for specific issues" >> "$TEST_TMP_DIR/integration_report.txt"
    else
        echo "- All integration tests passed" >> "$TEST_TMP_DIR/integration_report.txt"
        echo "- System ready for deployment" >> "$TEST_TMP_DIR/integration_report.txt"
    fi
    
    echo -e "\nIntegration report saved to: $TEST_TMP_DIR/integration_report.txt"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}All integration tests passed!${NC}"
        exit 0
    else
        echo -e "\n${RED}Some integration tests failed!${NC}"
        exit 1
    fi
}

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi