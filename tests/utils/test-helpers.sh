#!/bin/bash

# Common test helper functions for Azure VM automation tests
# Provides reusable functions for test setup, execution, and reporting

set -euo pipefail

# Export test colors
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export PURPLE='\033[0;35m'
export CYAN='\033[0;36m'
export NC='\033[0m' # No Color

# Test result tracking
export TESTS_RUN=0
export TESTS_PASSED=0
export TESTS_FAILED=0
export TESTS_SKIPPED=0

# Test timing
export TEST_START_TIME=""
export TEST_END_TIME=""

# Test output control
export VERBOSE="${VERBOSE:-false}"
export DEBUG="${DEBUG:-false}"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_debug() {
    if [[ "$DEBUG" == "true" ]]; then
        echo -e "${CYAN}[DEBUG]${NC} $*"
    fi
}

# Test execution helpers
run_test() {
    local test_name="$1"
    local test_function="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    echo -e "\n${YELLOW}Running test: $test_name${NC}"
    
    local start_time=$(date +%s.%N)
    
    if $test_function; then
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc)
        
        echo -e "${GREEN}✓ PASSED${NC} (${duration}s)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc)
        
        echo -e "${RED}✗ FAILED${NC} (${duration}s)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

skip_test() {
    local test_name="$1"
    local reason="${2:-No reason provided}"
    
    echo -e "\n${YELLOW}Skipping test: $test_name${NC}"
    echo -e "${YELLOW}⚠ SKIPPED: $reason${NC}"
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
}

# Setup and teardown helpers
create_test_directory() {
    local test_name="${1:-test}"
    local test_dir="/tmp/${test_name}-$$"
    
    mkdir -p "$test_dir"
    echo "$test_dir"
}

cleanup_test_directory() {
    local test_dir="$1"
    
    if [[ -d "$test_dir" ]]; then
        rm -rf "$test_dir"
        log_debug "Cleaned up test directory: $test_dir"
    fi
}

# Mock creation helpers
create_mock_command() {
    local command_name="$1"
    local mock_dir="$2"
    local mock_response="$3"
    
    local mock_path="$mock_dir/$command_name"
    
    cat > "$mock_path" << EOF
#!/bin/bash
echo '$mock_response'
EOF
    
    chmod +x "$mock_path"
    log_debug "Created mock command: $command_name"
}

create_mock_azure_cli() {
    local mock_dir="$1"
    local mock_script="$PROJECT_ROOT/tests/azure-vm-automation/mock-azure-cli.sh"
    
    if [[ -f "$mock_script" ]]; then
        ln -sf "$mock_script" "$mock_dir/az"
        log_debug "Linked mock Azure CLI"
    else
        log_warning "Mock Azure CLI script not found at: $mock_script"
    fi
}

# Environment setup helpers
setup_test_environment() {
    local test_name="${1:-test}"
    
    # Create test directory
    local test_dir=$(create_test_directory "$test_name")
    
    # Create mock directory
    local mock_dir="$test_dir/mocks"
    mkdir -p "$mock_dir"
    
    # Export paths
    export TEST_DIR="$test_dir"
    export MOCK_DIR="$mock_dir"
    export ORIGINAL_PATH="$PATH"
    export PATH="$MOCK_DIR:$PATH"
    
    log_debug "Test environment setup complete"
    echo "$test_dir"
}

teardown_test_environment() {
    # Restore original PATH
    if [[ -n "${ORIGINAL_PATH:-}" ]]; then
        export PATH="$ORIGINAL_PATH"
    fi
    
    # Cleanup test directory
    if [[ -n "${TEST_DIR:-}" ]]; then
        cleanup_test_directory "$TEST_DIR"
    fi
    
    # Unset test variables
    unset TEST_DIR MOCK_DIR ORIGINAL_PATH
    
    log_debug "Test environment torn down"
}

# File and directory helpers
create_test_file() {
    local file_path="$1"
    local content="${2:-Test content}"
    
    mkdir -p "$(dirname "$file_path")"
    echo "$content" > "$file_path"
    log_debug "Created test file: $file_path"
}

create_test_ssh_key() {
    local key_dir="$1"
    local key_name="${2:-id_rsa}"
    
    mkdir -p "$key_dir"
    
    # Create mock private key
    cat > "$key_dir/$key_name" << 'EOF'
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
QyNTUxOQAAACBMOCKPHEXzApFTSz3myAQzfgFqpuD4PG1fCiQlBvxZ9QAAAJBqdB7ranQe
-----END OPENSSH PRIVATE KEY-----
EOF
    
    # Create mock public key
    cat > "$key_dir/${key_name}.pub" << 'EOF'
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEw4Io8cRfMCkVNLPebIBDN+AWqm4Pg8bV8KJCUG/Fn1 test@example.com
EOF
    
    chmod 600 "$key_dir/$key_name"
    chmod 644 "$key_dir/${key_name}.pub"
    
    log_debug "Created test SSH keys in: $key_dir"
}

# Azure resource helpers
generate_test_vm_name() {
    local prefix="${1:-test}"
    echo "${prefix}-vm-$(date +%s)"
}

generate_test_resource_group() {
    local prefix="${1:-test}"
    echo "${prefix}-rg-$(date +%s)"
}

# Validation helpers
validate_json() {
    local json_string="$1"
    
    if echo "$json_string" | jq . >/dev/null 2>&1; then
        return 0
    else
        log_error "Invalid JSON: $json_string"
        return 1
    fi
}

validate_ip_address() {
    local ip="$1"
    
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    else
        log_error "Invalid IP address: $ip"
        return 1
    fi
}

validate_cidr() {
    local cidr="$1"
    
    if [[ $cidr =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        return 0
    else
        log_error "Invalid CIDR: $cidr"
        return 1
    fi
}

# Report generation helpers
generate_test_report() {
    local report_file="${1:-test-report.txt}"
    local test_suite="${2:-Test Suite}"
    
    cat > "$report_file" << EOF
$test_suite Report
$(printf '=%.0s' {1..50})
Date: $(date)
Duration: ${TEST_DURATION:-N/A}

Test Summary:
-------------
Total Tests: $TESTS_RUN
Passed: $TESTS_PASSED
Failed: $TESTS_FAILED
Skipped: $TESTS_SKIPPED

Success Rate: $(if [[ $TESTS_RUN -gt 0 ]]; then echo "scale=2; $TESTS_PASSED * 100 / $TESTS_RUN" | bc; else echo "0"; fi)%

EOF
    
    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo "Status: FAILED" >> "$report_file"
    elif [[ $TESTS_SKIPPED -gt 0 ]]; then
        echo "Status: PASSED WITH SKIPS" >> "$report_file"
    else
        echo "Status: PASSED" >> "$report_file"
    fi
    
    log_info "Test report generated: $report_file"
}

# Test timing helpers
start_test_timer() {
    TEST_START_TIME=$(date +%s)
    log_debug "Test timer started"
}

stop_test_timer() {
    TEST_END_TIME=$(date +%s)
    TEST_DURATION=$((TEST_END_TIME - TEST_START_TIME))
    
    log_debug "Test timer stopped. Duration: ${TEST_DURATION}s"
}

# Network helpers
wait_for_port() {
    local host="$1"
    local port="$2"
    local timeout="${3:-30}"
    
    local count=0
    while ! nc -z "$host" "$port" 2>/dev/null; do
        if [[ $count -ge $timeout ]]; then
            log_error "Timeout waiting for $host:$port"
            return 1
        fi
        sleep 1
        ((count++))
    done
    
    log_debug "Port $host:$port is available"
    return 0
}

# Process helpers
wait_for_process() {
    local process_name="$1"
    local timeout="${2:-30}"
    
    local count=0
    while ! pgrep -f "$process_name" >/dev/null 2>&1; do
        if [[ $count -ge $timeout ]]; then
            log_error "Timeout waiting for process: $process_name"
            return 1
        fi
        sleep 1
        ((count++))
    done
    
    log_debug "Process $process_name is running"
    return 0
}

# Random data generators
generate_random_string() {
    local length="${1:-8}"
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w "$length" | head -n 1
}

generate_random_ip() {
    echo "$((RANDOM % 256)).$((RANDOM % 256)).$((RANDOM % 256)).$((RANDOM % 256))"
}

generate_random_port() {
    echo $((RANDOM % 64512 + 1024))  # Random port between 1024-65535
}

# Export all functions
export -f log_info log_success log_warning log_error log_debug
export -f run_test skip_test
export -f create_test_directory cleanup_test_directory
export -f create_mock_command create_mock_azure_cli
export -f setup_test_environment teardown_test_environment
export -f create_test_file create_test_ssh_key
export -f generate_test_vm_name generate_test_resource_group
export -f validate_json validate_ip_address validate_cidr
export -f generate_test_report
export -f start_test_timer stop_test_timer
export -f wait_for_port wait_for_process
export -f generate_random_string generate_random_ip generate_random_port

# Display helper info if sourced directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Test Helper Functions Loaded"
    echo "=========================="
    echo "Available functions:"
    echo "  - Logging: log_info, log_success, log_warning, log_error, log_debug"
    echo "  - Test execution: run_test, skip_test"
    echo "  - Environment: setup_test_environment, teardown_test_environment"
    echo "  - Mocking: create_mock_command, create_mock_azure_cli"
    echo "  - Validation: validate_json, validate_ip_address, validate_cidr"
    echo "  - Reporting: generate_test_report"
    echo ""
    echo "Set VERBOSE=true for verbose output"
    echo "Set DEBUG=true for debug output"
fi