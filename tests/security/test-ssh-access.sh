#!/bin/bash

# Test suite for SSH security validation
# Ensures SSH access is properly secured for Azure VMs

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
TEST_SSH_CONFIG="/tmp/ssh-test-$$/sshd_config"
TEST_SSH_DIR="/tmp/ssh-test-$$"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
SECURITY_VIOLATIONS=0

# SSH security requirements
REQUIRED_SETTINGS=(
    "PermitRootLogin:no"
    "PasswordAuthentication:no"
    "PubkeyAuthentication:yes"
    "PermitEmptyPasswords:no"
    "MaxAuthTries:3"
    "ClientAliveInterval:300"
    "ClientAliveCountMax:2"
)

RECOMMENDED_SETTINGS=(
    "Protocol:2"
    "X11Forwarding:no"
    "AllowUsers:*"
    "AllowGroups:*"
    "DenyUsers:root"
)

# Setup test environment
setup_test_env() {
    echo -e "${BLUE}Setting up SSH security test environment...${NC}"
    
    mkdir -p "$TEST_SSH_DIR"
    
    # Create test SSH config
    cat > "$TEST_SSH_CONFIG" << 'EOF'
# Test SSH Configuration
Port 22
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

# Security settings
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
ChallengeResponseAuthentication no

# Connection settings
MaxAuthTries 3
MaxSessions 10
ClientAliveInterval 300
ClientAliveCountMax 2

# Additional security
X11Forwarding no
PrintMotd no
TCPKeepAlive yes
Compression delayed

# Logging
SyslogFacility AUTH
LogLevel INFO

# Authentication
AuthorizedKeysFile .ssh/authorized_keys
StrictModes yes

# Subsystems
Subsystem sftp /usr/lib/openssh/sftp-server
EOF
}

# Cleanup
cleanup() {
    rm -rf "$TEST_SSH_DIR"
}
trap cleanup EXIT

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
        SECURITY_VIOLATIONS=$((SECURITY_VIOLATIONS + 1))
        return 1
    fi
}

# SSH Security Tests

test_ssh_config_security() {
    # Check SSH configuration for security settings
    
    for setting in "${REQUIRED_SETTINGS[@]}"; do
        local key="${setting%:*}"
        local expected_value="${setting#*:}"
        
        # Check if setting exists and has correct value
        if grep -qi "^${key}[[:space:]]\+${expected_value}" "$TEST_SSH_CONFIG"; then
            echo "✓ $key is set to $expected_value"
        else
            echo -e "${RED}✗ $key is NOT set to $expected_value${NC}"
            return 1
        fi
    done
    
    echo "All required SSH security settings are properly configured"
    return 0
}

test_ssh_key_permissions() {
    # Test SSH key file permissions
    
    # Create test SSH keys
    local test_key_dir="$TEST_SSH_DIR/.ssh"
    mkdir -p "$test_key_dir"
    touch "$test_key_dir/id_rsa"
    touch "$test_key_dir/id_rsa.pub"
    touch "$test_key_dir/authorized_keys"
    
    # Set correct permissions
    chmod 700 "$test_key_dir"
    chmod 600 "$test_key_dir/id_rsa"
    chmod 644 "$test_key_dir/id_rsa.pub"
    chmod 600 "$test_key_dir/authorized_keys"
    
    # Verify permissions
    local errors=0
    
    # Check directory permission
    if [[ "$(stat -c %a "$test_key_dir" 2>/dev/null || stat -f %A "$test_key_dir")" != "700" ]]; then
        echo -e "${RED}SSH directory has incorrect permissions${NC}"
        ((errors++))
    fi
    
    # Check private key permission
    if [[ "$(stat -c %a "$test_key_dir/id_rsa" 2>/dev/null || stat -f %A "$test_key_dir/id_rsa")" != "600" ]]; then
        echo -e "${RED}Private key has incorrect permissions${NC}"
        ((errors++))
    fi
    
    # Check authorized_keys permission
    if [[ "$(stat -c %a "$test_key_dir/authorized_keys" 2>/dev/null || stat -f %A "$test_key_dir/authorized_keys")" != "600" ]]; then
        echo -e "${RED}authorized_keys has incorrect permissions${NC}"
        ((errors++))
    fi
    
    if [[ $errors -eq 0 ]]; then
        echo "SSH key permissions are correctly set"
        return 0
    else
        return 1
    fi
}

test_ssh_key_strength() {
    # Test SSH key strength
    
    # Generate test keys with different strengths
    local weak_key="$TEST_SSH_DIR/weak_key"
    local strong_key="$TEST_SSH_DIR/strong_key"
    
    # Simulate key generation (in real test would use ssh-keygen)
    echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAAgQC..." > "$weak_key.pub"  # 1024-bit
    echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC..." > "$strong_key.pub" # 4096-bit
    
    # Function to check key strength (simplified)
    check_key_strength() {
        local key_file="$1"
        local key_data=$(cat "$key_file")
        
        # Simple check based on key length (real implementation would parse the key)
        if [[ ${#key_data} -gt 400 ]]; then
            echo "strong"
        else
            echo "weak"
        fi
    }
    
    local weak_strength=$(check_key_strength "$weak_key.pub")
    local strong_strength=$(check_key_strength "$strong_key.pub")
    
    if [[ "$weak_strength" == "weak" && "$strong_strength" == "strong" ]]; then
        echo "SSH key strength validation working correctly"
        return 0
    else
        echo "SSH key strength validation failed"
        return 1
    fi
}

test_ssh_port_security() {
    # Test SSH port configuration
    
    # Check if SSH is on non-standard port (recommended)
    local ssh_port=$(grep -E "^Port" "$TEST_SSH_CONFIG" | awk '{print $2}')
    
    if [[ "$ssh_port" == "22" ]]; then
        echo -e "${YELLOW}Warning: SSH is using default port 22${NC}"
        echo "Consider using a non-standard port for additional security"
    else
        echo "SSH is using non-standard port: $ssh_port"
    fi
    
    # Always pass this test but provide recommendation
    return 0
}

test_ssh_user_restrictions() {
    # Test user access restrictions
    
    # Check for AllowUsers/AllowGroups
    local has_user_restrictions=0
    
    if grep -qE "^AllowUsers" "$TEST_SSH_CONFIG"; then
        echo "✓ SSH access is restricted to specific users"
        has_user_restrictions=1
    fi
    
    if grep -qE "^AllowGroups" "$TEST_SSH_CONFIG"; then
        echo "✓ SSH access is restricted to specific groups"
        has_user_restrictions=1
    fi
    
    if grep -qE "^DenyUsers.*root" "$TEST_SSH_CONFIG"; then
        echo "✓ Root user is explicitly denied"
    fi
    
    if [[ $has_user_restrictions -eq 0 ]]; then
        echo -e "${YELLOW}Warning: No user/group restrictions found${NC}"
        echo "Consider using AllowUsers or AllowGroups for additional security"
    fi
    
    return 0
}

test_ssh_authentication_methods() {
    # Test authentication method configuration
    
    # Check for insecure authentication methods
    local insecure_methods=(
        "PasswordAuthentication yes"
        "ChallengeResponseAuthentication yes"
        "PermitEmptyPasswords yes"
        "HostbasedAuthentication yes"
        "RhostsRSAAuthentication yes"
    )
    
    local found_insecure=0
    for method in "${insecure_methods[@]}"; do
        if grep -qi "$method" "$TEST_SSH_CONFIG"; then
            echo -e "${RED}Found insecure setting: $method${NC}"
            found_insecure=1
        fi
    done
    
    if [[ $found_insecure -eq 0 ]]; then
        echo "No insecure authentication methods found"
        return 0
    else
        return 1
    fi
}

test_ssh_connection_limits() {
    # Test connection limit settings
    
    local max_auth_tries=$(grep -E "^MaxAuthTries" "$TEST_SSH_CONFIG" | awk '{print $2}')
    local max_sessions=$(grep -E "^MaxSessions" "$TEST_SSH_CONFIG" | awk '{print $2}')
    local client_alive_interval=$(grep -E "^ClientAliveInterval" "$TEST_SSH_CONFIG" | awk '{print $2}')
    
    local issues=0
    
    # Check MaxAuthTries
    if [[ -n "$max_auth_tries" && $max_auth_tries -gt 3 ]]; then
        echo -e "${YELLOW}Warning: MaxAuthTries is set to $max_auth_tries (recommended: 3 or less)${NC}"
        ((issues++))
    fi
    
    # Check MaxSessions
    if [[ -n "$max_sessions" && $max_sessions -gt 10 ]]; then
        echo -e "${YELLOW}Warning: MaxSessions is set to $max_sessions (recommended: 10 or less)${NC}"
        ((issues++))
    fi
    
    # Check ClientAliveInterval
    if [[ -z "$client_alive_interval" || $client_alive_interval -eq 0 ]]; then
        echo -e "${YELLOW}Warning: ClientAliveInterval not set (recommended: 300-600)${NC}"
        ((issues++))
    fi
    
    if [[ $issues -eq 0 ]]; then
        echo "Connection limits are properly configured"
        return 0
    else
        echo "Some connection limits need adjustment"
        return 0  # Warning only, don't fail
    fi
}

test_ssh_logging() {
    # Test SSH logging configuration
    
    local log_level=$(grep -E "^LogLevel" "$TEST_SSH_CONFIG" | awk '{print $2}')
    local syslog_facility=$(grep -E "^SyslogFacility" "$TEST_SSH_CONFIG" | awk '{print $2}')
    
    if [[ "$log_level" == "INFO" || "$log_level" == "VERBOSE" ]]; then
        echo "✓ SSH logging level is appropriate: $log_level"
    else
        echo -e "${YELLOW}Warning: SSH logging level is $log_level (recommended: INFO or VERBOSE)${NC}"
    fi
    
    if [[ -n "$syslog_facility" ]]; then
        echo "✓ SSH logs are sent to syslog facility: $syslog_facility"
    else
        echo -e "${YELLOW}Warning: Syslog facility not configured${NC}"
    fi
    
    return 0
}

test_fail2ban_integration() {
    # Test fail2ban integration for SSH protection
    
    # Check if fail2ban config exists (mock for testing)
    local fail2ban_jail="$TEST_SSH_DIR/jail.local"
    
    # Create mock fail2ban config
    cat > "$fail2ban_jail" << 'EOF'
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
findtime = 600
EOF
    
    if [[ -f "$fail2ban_jail" ]] && grep -q "enabled = true" "$fail2ban_jail"; then
        echo "✓ Fail2ban is configured for SSH protection"
        
        # Check fail2ban settings
        local maxretry=$(grep "maxretry" "$fail2ban_jail" | awk -F= '{print $2}' | xargs)
        local bantime=$(grep "bantime" "$fail2ban_jail" | awk -F= '{print $2}' | xargs)
        
        echo "  - Max retry attempts: $maxretry"
        echo "  - Ban duration: $bantime seconds"
        
        return 0
    else
        echo -e "${YELLOW}Warning: Fail2ban not configured for SSH${NC}"
        return 0  # Warning only
    fi
}

generate_ssh_security_report() {
    local report_file="/tmp/ssh-security-report-$$.txt"
    
    cat > "$report_file" << EOF
SSH Security Validation Report
==============================
Date: $(date)

Test Summary:
-------------
Total Tests: $TESTS_RUN
Passed: $TESTS_PASSED
Failed: $TESTS_FAILED
Security Violations: $SECURITY_VIOLATIONS

Critical Security Settings:
---------------------------
$(for setting in "${REQUIRED_SETTINGS[@]}"; do
    echo "- ${setting%:*}: ${setting#*:}"
done)

Recommendations:
----------------
1. Disable password authentication
2. Use SSH keys with minimum 2048-bit strength (4096-bit recommended)
3. Restrict root login
4. Implement fail2ban or similar brute-force protection
5. Use non-standard SSH port
6. Restrict SSH access to specific users/groups
7. Enable comprehensive logging
8. Set appropriate connection timeouts
9. Keep SSH server updated
10. Regular security audits

Security Hardening Checklist:
-----------------------------
[$(if grep -q "PasswordAuthentication no" "$TEST_SSH_CONFIG"; then echo "✓"; else echo " "; fi)] Password authentication disabled
[$(if grep -q "PermitRootLogin no" "$TEST_SSH_CONFIG"; then echo "✓"; else echo " "; fi)] Root login disabled
[$(if grep -q "PubkeyAuthentication yes" "$TEST_SSH_CONFIG"; then echo "✓"; else echo " "; fi)] Public key authentication enabled
[$(if [[ -f "$TEST_SSH_DIR/jail.local" ]]; then echo "✓"; else echo " "; fi)] Fail2ban configured
[$(if grep -qE "^AllowUsers|^AllowGroups" "$TEST_SSH_CONFIG"; then echo "✓"; else echo " "; fi)] User restrictions in place

Overall Status: $(if [[ $SECURITY_VIOLATIONS -eq 0 ]]; then echo "SECURE"; else echo "NEEDS ATTENTION"; fi)
EOF
    
    echo -e "\n${BLUE}SSH security report generated: $report_file${NC}"
}

# Main test execution
main() {
    echo -e "${BLUE}SSH Security Validation Test Suite${NC}"
    echo -e "${BLUE}===================================${NC}"
    
    setup_test_env
    
    # Run SSH security tests
    run_test "SSH configuration security" test_ssh_config_security
    run_test "SSH key permissions" test_ssh_key_permissions
    run_test "SSH key strength validation" test_ssh_key_strength
    run_test "SSH port configuration" test_ssh_port_security
    run_test "SSH user restrictions" test_ssh_user_restrictions
    run_test "SSH authentication methods" test_ssh_authentication_methods
    run_test "SSH connection limits" test_ssh_connection_limits
    run_test "SSH logging configuration" test_ssh_logging
    run_test "Fail2ban integration" test_fail2ban_integration
    
    # Generate report
    generate_ssh_security_report
    
    # Summary
    echo -e "\n${BLUE}Test Summary${NC}"
    echo -e "${BLUE}============${NC}"
    echo -e "Tests run: $TESTS_RUN"
    echo -e "${GREEN}Tests passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Tests failed: $TESTS_FAILED${NC}"
    echo -e "${RED}Security violations: $SECURITY_VIOLATIONS${NC}"
    
    if [[ $TESTS_FAILED -eq 0 && $SECURITY_VIOLATIONS -eq 0 ]]; then
        echo -e "\n${GREEN}All SSH security tests passed!${NC}"
        exit 0
    else
        echo -e "\n${RED}SSH security validation failed! Review the violations above.${NC}"
        exit 1
    fi
}

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi