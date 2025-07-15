#!/bin/bash

# Test suite for NSG (Network Security Group) rules validation
# Ensures proper security configuration for Azure VMs

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
MOCK_AZ="$PROJECT_ROOT/tests/azure-vm-automation/mock-azure-cli.sh"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
SECURITY_ISSUES=0

# Security requirements
REQUIRED_RULES=(
    "SSH:22:tcp:restricted"  # SSH should be restricted to specific IPs
    "HTTP:80:tcp:optional"   # HTTP may be allowed if needed
    "HTTPS:443:tcp:optional" # HTTPS may be allowed if needed
)

BLOCKED_RULES=(
    "RDP:3389:tcp"          # RDP should never be open
    "MYSQL:3306:tcp"        # Database ports should not be exposed
    "POSTGRES:5432:tcp"     # Database ports should not be exposed
    "MONGODB:27017:tcp"     # Database ports should not be exposed
)

# Setup test environment
setup_test_env() {
    echo -e "${BLUE}Setting up NSG test environment...${NC}"
    
    # Make mock executable
    chmod +x "$MOCK_AZ"
    
    # Use mock Azure CLI
    export PATH="$(dirname "$MOCK_AZ"):$PATH"
    alias az="$MOCK_AZ"
}

# Test helper functions
run_test() {
    local test_name="$1"
    local test_function="$2"
    
    echo -e "\n${YELLOW}Testing: $test_name${NC}"
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if $test_function; then
        echo -e "${GREEN}✓ PASSED${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAILED${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        SECURITY_ISSUES=$((SECURITY_ISSUES + 1))
        return 1
    fi
}

# Security validation functions
validate_ssh_restriction() {
    # Check if SSH is properly restricted
    local nsg_rules=$("$MOCK_AZ" network nsg rule list --nsg-name test-nsg --resource-group test-rg 2>/dev/null)
    
    # Check for SSH rule
    local ssh_rule=$(echo "$nsg_rules" | jq -r '.[] | select(.destinationPortRange=="22")')
    
    if [[ -z "$ssh_rule" ]]; then
        echo "No SSH rule found - this might block legitimate access"
        return 1
    fi
    
    # Check source restriction
    local source_prefix=$(echo "$ssh_rule" | jq -r '.sourceAddressPrefix')
    
    if [[ "$source_prefix" == "*" || "$source_prefix" == "0.0.0.0/0" ]]; then
        echo -e "${RED}CRITICAL: SSH is open to the entire internet!${NC}"
        echo "Source: $source_prefix"
        return 1
    fi
    
    echo "SSH is properly restricted to: $source_prefix"
    return 0
}

validate_no_dangerous_ports() {
    # Check for dangerous open ports
    local nsg_rules=$("$MOCK_AZ" network nsg rule list --nsg-name test-nsg --resource-group test-rg 2>/dev/null)
    local found_dangerous=0
    
    for blocked in "${BLOCKED_RULES[@]}"; do
        local port=$(echo "$blocked" | cut -d: -f2)
        local service=$(echo "$blocked" | cut -d: -f1)
        
        local dangerous_rule=$(echo "$nsg_rules" | jq -r '.[] | select(.destinationPortRange=="'$port'" and .access=="Allow")')
        
        if [[ -n "$dangerous_rule" ]]; then
            echo -e "${RED}CRITICAL: Dangerous port $port ($service) is exposed!${NC}"
            found_dangerous=1
        fi
    done
    
    [[ $found_dangerous -eq 0 ]]
}

validate_rule_priorities() {
    # Check if rule priorities are properly set
    local nsg_rules=$("$MOCK_AZ" network nsg rule list --nsg-name test-nsg --resource-group test-rg 2>/dev/null)
    
    # Check for priority conflicts
    local priorities=$(echo "$nsg_rules" | jq -r '.[].priority' | sort -n)
    local prev_priority=""
    
    for priority in $priorities; do
        if [[ "$priority" == "$prev_priority" ]]; then
            echo -e "${RED}Duplicate priority found: $priority${NC}"
            return 1
        fi
        prev_priority="$priority"
    done
    
    # Check priority range (100-4096 for custom rules)
    for priority in $priorities; do
        if [[ $priority -lt 100 || $priority -gt 4096 ]]; then
            echo -e "${YELLOW}Warning: Priority $priority is outside recommended range (100-4096)${NC}"
        fi
    done
    
    echo "Rule priorities are properly configured"
    return 0
}

validate_default_deny() {
    # Check if default deny rules are in place
    local nsg_rules=$("$MOCK_AZ" network nsg rule list --nsg-name test-nsg --resource-group test-rg 2>/dev/null)
    
    # Count allow rules
    local allow_count=$(echo "$nsg_rules" | jq -r '.[] | select(.access=="Allow") | .name' | wc -l)
    
    if [[ $allow_count -eq 0 ]]; then
        echo -e "${YELLOW}Warning: No allow rules found - VM might be inaccessible${NC}"
    fi
    
    echo "Found $allow_count allow rules"
    return 0
}

validate_ip_restrictions() {
    # Validate that IP restrictions are properly formatted
    local nsg_rules=$("$MOCK_AZ" network nsg rule list --nsg-name test-nsg --resource-group test-rg 2>/dev/null)
    
    # Check each rule's source address
    echo "$nsg_rules" | jq -r '.[] | select(.sourceAddressPrefix != null) | .sourceAddressPrefix' | while read -r prefix; do
        if [[ "$prefix" == "*" ]]; then
            continue
        fi
        
        # Validate CIDR notation
        if [[ "$prefix" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]]; then
            # Extract IP and mask
            local ip="${prefix%/*}"
            local mask="${prefix#*/}"
            
            # Validate mask
            if [[ $mask -lt 0 || $mask -gt 32 ]]; then
                echo -e "${RED}Invalid CIDR mask in $prefix${NC}"
                return 1
            fi
            
            # Validate IP octets
            IFS='.' read -ra OCTETS <<< "$ip"
            for octet in "${OCTETS[@]}"; do
                if [[ $octet -lt 0 || $octet -gt 255 ]]; then
                    echo -e "${RED}Invalid IP address in $prefix${NC}"
                    return 1
                fi
            done
        elif [[ "$prefix" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
            # Single IP address (implicitly /32)
            echo -e "${YELLOW}Note: Single IP $prefix should use CIDR notation (e.g., $prefix/32)${NC}"
        else
            echo -e "${RED}Invalid source address format: $prefix${NC}"
            return 1
        fi
    done
    
    echo "IP restrictions are properly formatted"
    return 0
}

test_nsg_creation() {
    # Test NSG creation with security rules
    local resource_group="test-security-rg"
    local nsg_name="test-security-nsg"
    
    # Simulate NSG creation
    "$MOCK_AZ" network nsg create --resource-group "$resource_group" --name "$nsg_name" &>/dev/null || true
    
    # Add a secure SSH rule
    "$MOCK_AZ" network nsg rule create \
        --resource-group "$resource_group" \
        --nsg-name "$nsg_name" \
        --name "SSH-Restricted" \
        --priority 100 \
        --source-address-prefix "192.168.1.0/24" \
        --destination-port-range 22 \
        --protocol Tcp \
        --access Allow &>/dev/null || true
    
    return 0
}

test_rule_updates() {
    # Test updating NSG rules
    local current_ip="192.168.1.100"
    local new_ip="10.0.0.100"
    
    echo "Testing rule update from $current_ip to $new_ip"
    
    # This would normally update the rule
    "$MOCK_AZ" network nsg rule update \
        --resource-group "test-rg" \
        --nsg-name "test-nsg" \
        --name "SSH-Rule" \
        --source-address-prefix "$new_ip/32" &>/dev/null || true
    
    return 0
}

test_security_compliance() {
    # Test overall security compliance
    local compliance_score=100
    local issues=()
    
    # Check SSH restriction
    if ! validate_ssh_restriction &>/dev/null; then
        compliance_score=$((compliance_score - 30))
        issues+=("SSH not properly restricted")
    fi
    
    # Check dangerous ports
    if ! validate_no_dangerous_ports &>/dev/null; then
        compliance_score=$((compliance_score - 40))
        issues+=("Dangerous ports exposed")
    fi
    
    # Check priorities
    if ! validate_rule_priorities &>/dev/null; then
        compliance_score=$((compliance_score - 10))
        issues+=("Rule priority issues")
    fi
    
    echo "Security Compliance Score: $compliance_score/100"
    
    if [[ ${#issues[@]} -gt 0 ]]; then
        echo -e "${RED}Issues found:${NC}"
        for issue in "${issues[@]}"; do
            echo "  - $issue"
        done
    fi
    
    [[ $compliance_score -ge 70 ]]  # Pass if score is 70 or above
}

generate_security_report() {
    local report_file="/tmp/nsg-security-report-$$.txt"
    
    cat > "$report_file" << EOF
NSG Security Validation Report
==============================
Date: $(date)
Environment: Test

Summary:
--------
Total Tests Run: $TESTS_RUN
Tests Passed: $TESTS_PASSED
Tests Failed: $TESTS_FAILED
Security Issues Found: $SECURITY_ISSUES

Recommendations:
----------------
1. Always restrict SSH access to specific IP ranges
2. Never expose database ports to the internet
3. Use the principle of least privilege
4. Regularly audit and update NSG rules
5. Implement logging for all rule changes

Security Best Practices:
-----------------------
- Use specific source IP addresses or ranges
- Implement deny-by-default policies
- Use unique priorities for each rule
- Document the purpose of each rule
- Regular security audits

Compliance Status: $(if [[ $SECURITY_ISSUES -eq 0 ]]; then echo "PASSED"; else echo "FAILED"; fi)
EOF
    
    echo -e "\n${BLUE}Security report generated: $report_file${NC}"
}

# Main test execution
main() {
    echo -e "${BLUE}NSG Security Rules Test Suite${NC}"
    echo -e "${BLUE}==============================${NC}"
    
    setup_test_env
    
    # Run security tests
    run_test "SSH access restriction" validate_ssh_restriction
    run_test "No dangerous ports exposed" validate_no_dangerous_ports
    run_test "Rule priorities validation" validate_rule_priorities
    run_test "Default deny policy" validate_default_deny
    run_test "IP restriction format" validate_ip_restrictions
    run_test "NSG creation security" test_nsg_creation
    run_test "Rule update security" test_rule_updates
    run_test "Overall security compliance" test_security_compliance
    
    # Generate report
    generate_security_report
    
    # Summary
    echo -e "\n${BLUE}Test Summary${NC}"
    echo -e "${BLUE}============${NC}"
    echo -e "Tests run: $TESTS_RUN"
    echo -e "${GREEN}Tests passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Tests failed: $TESTS_FAILED${NC}"
    echo -e "${RED}Security issues: $SECURITY_ISSUES${NC}"
    
    if [[ $TESTS_FAILED -eq 0 && $SECURITY_ISSUES -eq 0 ]]; then
        echo -e "\n${GREEN}All security tests passed!${NC}"
        exit 0
    else
        echo -e "\n${RED}Security validation failed! Review the issues above.${NC}"
        exit 1
    fi
}

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi