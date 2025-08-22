#!/bin/bash

# Main test runner for Azure VM automation test suite
# Provides a unified interface to run all test categories

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Import test utilities
source "$SCRIPT_DIR/utils/test-helpers.sh"
source "$SCRIPT_DIR/utils/assert.sh"
source "$SCRIPT_DIR/utils/cleanup.sh"

# Test categories
declare -A TEST_SUITES=(
    ["unit"]="Unit Tests"
    ["integration"]="Integration Tests"
    ["security"]="Security Tests"
    ["e2e"]="End-to-End Tests"
    ["all"]="All Tests"
)

# Test suite configuration
declare -A UNIT_TESTS=(
    ["bash-functions"]="$SCRIPT_DIR/azure-vm-automation/test-bash-functions.sh"
)

declare -A INTEGRATION_TESTS=(
    ["bash-ansible"]="$SCRIPT_DIR/azure-vm-automation/test-integration.sh"
)

declare -A SECURITY_TESTS=(
    ["nsg-rules"]="$SCRIPT_DIR/security/test-nsg-rules.sh"
    ["ip-restriction"]="$SCRIPT_DIR/security/test-ip-restriction.sh"
    ["ssh-access"]="$SCRIPT_DIR/security/test-ssh-access.sh"
)

declare -A E2E_TESTS=(
    ["vm-create"]="$SCRIPT_DIR/e2e/test-vm-create.sh"
    ["vm-lifecycle"]="$SCRIPT_DIR/e2e/test-vm-lifecycle.sh"
    ["security-compliance"]="$SCRIPT_DIR/e2e/test-security-compliance.sh"
)

# Test results tracking
SUITE_RESULTS=()
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Display usage
usage() {
    cat << EOF
Azure VM Automation Test Runner

Usage: $0 [OPTIONS] [SUITE]

SUITES:
    unit          Run unit tests
    integration   Run integration tests
    security      Run security tests
    e2e           Run end-to-end tests
    all           Run all test suites (default)

OPTIONS:
    -h, --help    Show this help message
    -v, --verbose Enable verbose output
    -d, --debug   Enable debug output
    -c, --clean   Clean up test artifacts before running
    -f, --fast    Skip slow tests
    -r, --report  Generate detailed test report
    --no-color    Disable colored output

EXAMPLES:
    $0                    # Run all tests
    $0 unit               # Run only unit tests
    $0 -v security        # Run security tests with verbose output
    $0 -c -r all          # Clean, run all tests, and generate report

EOF
    exit 0
}

# Parse command line arguments
parse_args() {
    local suite="all"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                ;;
            -v|--verbose)
                export VERBOSE=true
                shift
                ;;
            -d|--debug)
                export DEBUG=true
                export VERBOSE=true
                shift
                ;;
            -c|--clean)
                CLEAN_BEFORE=true
                shift
                ;;
            -f|--fast)
                export FAST_MODE=true
                shift
                ;;
            -r|--report)
                GENERATE_REPORT=true
                shift
                ;;
            --no-color)
                export NO_COLOR=true
                # Disable colors
                RED=''
                GREEN=''
                YELLOW=''
                BLUE=''
                PURPLE=''
                CYAN=''
                NC=''
                shift
                ;;
            unit|integration|security|e2e|all)
                suite="$1"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                ;;
        esac
    done
    
    echo "$suite"
}

# Run a single test
run_single_test() {
    local test_name="$1"
    local test_path="$2"
    
    echo -e "\n${BLUE}Running $test_name${NC}"
    echo -e "${BLUE}$(printf '=%.0s' {1..50})${NC}"
    
    if [[ ! -f "$test_path" ]]; then
        log_error "Test not found: $test_path"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        SUITE_RESULTS+=("$test_name: NOT FOUND")
        return 1
    fi
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    # Run test in subshell to isolate environment
    if (
        cd "$PROJECT_ROOT"
        bash "$test_path"
    ); then
        log_success "$test_name completed successfully"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        SUITE_RESULTS+=("$test_name: PASSED")
        return 0
    else
        log_error "$test_name failed"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        SUITE_RESULTS+=("$test_name: FAILED")
        return 1
    fi
}

# Run a test suite
run_test_suite() {
    local suite="$1"
    local -n tests=$2
    
    echo -e "\n${PURPLE}${TEST_SUITES[$suite]}${NC}"
    echo -e "${PURPLE}$(printf '=%.0s' {1..60})${NC}"
    
    local suite_start=$(date +%s)
    
    for test_name in "${!tests[@]}"; do
        run_single_test "$test_name" "${tests[$test_name]}" || true
    done
    
    local suite_end=$(date +%s)
    local suite_duration=$((suite_end - suite_start))
    
    echo -e "\n${PURPLE}${TEST_SUITES[$suite]} completed in ${suite_duration}s${NC}"
}

# Generate test report
generate_test_report() {
    local report_file="$PROJECT_ROOT/test-report-$(date +%Y%m%d-%H%M%S).html"
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Azure VM Automation Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background-color: #f5f5f5; }
        .container { background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 3px solid #4CAF50; padding-bottom: 10px; }
        h2 { color: #666; margin-top: 30px; }
        .summary { background-color: #f9f9f9; padding: 20px; border-radius: 5px; margin: 20px 0; }
        .passed { color: #4CAF50; font-weight: bold; }
        .failed { color: #f44336; font-weight: bold; }
        .metric { display: inline-block; margin: 10px 20px 10px 0; }
        .metric-value { font-size: 36px; font-weight: bold; }
        .metric-label { font-size: 14px; color: #666; }
        table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        th { background-color: #4CAF50; color: white; padding: 12px; text-align: left; }
        td { padding: 12px; border-bottom: 1px solid #ddd; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        .test-passed { background-color: #e8f5e9; }
        .test-failed { background-color: #ffebee; }
        .footer { margin-top: 40px; padding-top: 20px; border-top: 1px solid #ddd; color: #666; font-size: 14px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Azure VM Automation Test Report</h1>
        <p>Generated: $(date)</p>
        
        <div class="summary">
            <h2>Test Summary</h2>
            <div class="metric">
                <div class="metric-value">$TOTAL_TESTS</div>
                <div class="metric-label">Total Tests</div>
            </div>
            <div class="metric">
                <div class="metric-value passed">$PASSED_TESTS</div>
                <div class="metric-label">Passed</div>
            </div>
            <div class="metric">
                <div class="metric-value failed">$FAILED_TESTS</div>
                <div class="metric-label">Failed</div>
            </div>
            <div class="metric">
                <div class="metric-value">$(if [[ $TOTAL_TESTS -gt 0 ]]; then echo "scale=1; $PASSED_TESTS * 100 / $TOTAL_TESTS" | bc; else echo 0; fi)%</div>
                <div class="metric-label">Success Rate</div>
            </div>
        </div>
        
        <h2>Test Results</h2>
        <table>
            <tr>
                <th>Test Suite</th>
                <th>Test Name</th>
                <th>Result</th>
            </tr>
EOF
    
    # Add test results
    for result in "${SUITE_RESULTS[@]}"; do
        local test_name="${result%:*}"
        local test_result="${result#*: }"
        local row_class=""
        
        if [[ "$test_result" == "PASSED" ]]; then
            row_class="test-passed"
        elif [[ "$test_result" == "FAILED" ]]; then
            row_class="test-failed"
        fi
        
        # Determine suite from test name
        local suite="Unknown"
        for s in "${!TEST_SUITES[@]}"; do
            if [[ "$s" != "all" ]]; then
                local -n suite_tests="${s^^}_TESTS"
                if [[ -n "${suite_tests[$test_name]:-}" ]]; then
                    suite="${TEST_SUITES[$s]}"
                    break
                fi
            fi
        done
        
        cat >> "$report_file" << EOF
            <tr class="$row_class">
                <td>$suite</td>
                <td>$test_name</td>
                <td class="$(echo "$test_result" | tr '[:upper:]' '[:lower:]')">$test_result</td>
            </tr>
EOF
    done
    
    cat >> "$report_file" << EOF
        </table>
        
        <h2>Environment Information</h2>
        <table>
            <tr><td>Operating System</td><td>$(uname -s) $(uname -r)</td></tr>
            <tr><td>Bash Version</td><td>$BASH_VERSION</td></tr>
            <tr><td>Test Location</td><td>$PROJECT_ROOT</td></tr>
            <tr><td>User</td><td>$(whoami)</td></tr>
        </table>
        
        <div class="footer">
            <p>Azure VM Automation Test Suite - $(date +%Y)</p>
        </div>
    </div>
</body>
</html>
EOF
    
    log_info "Test report generated: $report_file"
    
    # Also generate a text summary
    local summary_file="$PROJECT_ROOT/test-summary-$(date +%Y%m%d-%H%M%S).txt"
    cat > "$summary_file" << EOF
Azure VM Automation Test Summary
================================
Date: $(date)

Results:
--------
Total Tests: $TOTAL_TESTS
Passed: $PASSED_TESTS
Failed: $FAILED_TESTS
Success Rate: $(if [[ $TOTAL_TESTS -gt 0 ]]; then echo "scale=1; $PASSED_TESTS * 100 / $TOTAL_TESTS" | bc; else echo 0; fi)%

Test Details:
-------------
$(for result in "${SUITE_RESULTS[@]}"; do echo "$result"; done)

Status: $(if [[ $FAILED_TESTS -eq 0 ]]; then echo "ALL TESTS PASSED"; else echo "SOME TESTS FAILED"; fi)
EOF
    
    log_info "Test summary generated: $summary_file"
}

# Main execution
main() {
    echo -e "${BLUE}Azure VM Automation Test Suite${NC}"
    echo -e "${BLUE}==============================${NC}"
    echo "Date: $(date)"
    echo "Location: $PROJECT_ROOT"
    
    # Parse arguments
    local suite=$(parse_args "$@")
    
    # Setup cleanup trap
    setup_cleanup_trap
    
    # Clean if requested
    if [[ "${CLEAN_BEFORE:-false}" == "true" ]]; then
        echo -e "\n${YELLOW}Cleaning test artifacts...${NC}"
        full_test_cleanup
    fi
    
    # Start timer
    local start_time=$(date +%s)
    
    # Run tests based on suite selection
    case "$suite" in
        unit)
            run_test_suite "unit" UNIT_TESTS
            ;;
        integration)
            run_test_suite "integration" INTEGRATION_TESTS
            ;;
        security)
            run_test_suite "security" SECURITY_TESTS
            ;;
        e2e)
            if [[ "${FAST_MODE:-false}" == "true" ]]; then
                log_warning "Skipping E2E tests in fast mode"
                skip_test "E2E Tests" "Fast mode enabled"
            else
                run_test_suite "e2e" E2E_TESTS
            fi
            ;;
        all)
            run_test_suite "unit" UNIT_TESTS
            run_test_suite "integration" INTEGRATION_TESTS
            run_test_suite "security" SECURITY_TESTS
            
            if [[ "${FAST_MODE:-false}" != "true" ]]; then
                run_test_suite "e2e" E2E_TESTS
            else
                log_warning "Skipping E2E tests in fast mode"
            fi
            ;;
    esac
    
    # Stop timer
    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))
    
    # Display summary
    echo -e "\n${BLUE}Test Execution Summary${NC}"
    echo -e "${BLUE}======================${NC}"
    echo "Total Duration: ${total_duration}s"
    echo "Total Tests: $TOTAL_TESTS"
    echo -e "${GREEN}Passed: $PASSED_TESTS${NC}"
    echo -e "${RED}Failed: $FAILED_TESTS${NC}"
    echo -e "Success Rate: $(if [[ $TOTAL_TESTS -gt 0 ]]; then echo "scale=1; $PASSED_TESTS * 100 / $TOTAL_TESTS" | bc; else echo 0; fi)%"
    
    # Generate report if requested
    if [[ "${GENERATE_REPORT:-false}" == "true" ]]; then
        generate_test_report
    fi
    
    # Cleanup status
    echo -e "\n${BLUE}Cleanup Status${NC}"
    cleanup_status_report
    
    # Exit with appropriate code
    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "\n${GREEN}All tests passed successfully!${NC}"
        exit 0
    else
        echo -e "\n${RED}Some tests failed. Please review the results above.${NC}"
        exit 1
    fi
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi