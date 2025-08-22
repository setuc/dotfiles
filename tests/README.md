# Azure VM Automation Test Suite

Comprehensive testing infrastructure for the Azure VM automation project, ensuring security, reliability, and performance.

## Overview

This test suite provides multiple layers of testing for both Bash functions and Ansible roles used in Azure VM automation:

- **Unit Tests**: Test individual functions and components
- **Integration Tests**: Verify Bash-Ansible integration
- **Security Tests**: Validate security controls and compliance
- **End-to-End Tests**: Test complete workflows
- **Performance Benchmarks**: Measure operation performance

## Test Structure

```
tests/
├── azure-vm-automation/       # Core automation tests
│   ├── test-bash-functions.sh # Unit tests for bash functions
│   ├── test-integration.sh    # Integration tests
│   └── mock-azure-cli.sh      # Mock Azure CLI for testing
├── security/                  # Security validation tests
│   ├── test-nsg-rules.sh      # NSG configuration tests
│   ├── test-ip-restriction.sh # IP restriction tests
│   └── test-ssh-access.sh     # SSH security tests
├── e2e/                       # End-to-end tests
│   ├── test-vm-create.sh      # VM creation workflow
│   ├── test-vm-lifecycle.sh   # VM lifecycle operations
│   └── test-security-compliance.sh # Security compliance
├── utils/                     # Test utilities
│   ├── test-helpers.sh        # Common test functions
│   ├── assert.sh              # Assertion library
│   └── cleanup.sh             # Cleanup utilities
└── run-tests.sh               # Main test runner

.github/workflows/
└── azure-vm-tests.yml         # CI/CD pipeline

ansible/roles/azure-vm/molecule/
└── default/                   # Molecule tests for Ansible role
    ├── molecule.yml           # Test configuration
    ├── converge.yml           # Test playbook
    └── verify.yml             # Verification tests
```

## Running Tests

### Quick Start

```bash
# Run all tests
./tests/run-tests.sh

# Run specific test suite
./tests/run-tests.sh unit
./tests/run-tests.sh security
./tests/run-tests.sh e2e

# Run with options
./tests/run-tests.sh -v unit          # Verbose output
./tests/run-tests.sh -c all           # Clean before running
./tests/run-tests.sh -r security      # Generate report
./tests/run-tests.sh -f all           # Fast mode (skip slow tests)
```

### Individual Test Execution

```bash
# Run specific test file
./tests/azure-vm-automation/test-bash-functions.sh
./tests/security/test-nsg-rules.sh
./tests/e2e/test-vm-create.sh
```

### Molecule Tests

```bash
cd ansible/roles/azure-vm
molecule test
```

## Test Categories

### 1. Unit Tests

Test individual functions in isolation:

- Bash function validation
- Parameter handling
- Error conditions
- Mock Azure CLI responses

**Example:**
```bash
./tests/azure-vm-automation/test-bash-functions.sh
```

### 2. Integration Tests

Verify component interactions:

- Bash-Ansible integration
- Configuration consistency
- Template rendering
- Variable passing

**Example:**
```bash
./tests/azure-vm-automation/test-integration.sh
```

### 3. Security Tests

Validate security controls:

- **NSG Rules**: Verify Network Security Group configurations
- **IP Restrictions**: Test IP allowlisting and detection
- **SSH Security**: Validate SSH hardening and access controls

**Example:**
```bash
./tests/security/test-nsg-rules.sh
./tests/security/test-ip-restriction.sh
./tests/security/test-ssh-access.sh
```

### 4. End-to-End Tests

Test complete workflows:

- **VM Creation**: Full VM provisioning with security
- **VM Lifecycle**: Start, stop, restart, delete operations
- **Security Compliance**: CIS benchmarks and custom policies

**Example:**
```bash
./tests/e2e/test-vm-create.sh
./tests/e2e/test-vm-lifecycle.sh
./tests/e2e/test-security-compliance.sh
```

## Test Utilities

### Test Helpers

Common functions for test setup and execution:

```bash
source tests/utils/test-helpers.sh

# Setup test environment
setup_test_environment "my-test"

# Run test with timing
run_test "Test Name" test_function

# Generate report
generate_test_report "report.txt" "My Test Suite"
```

### Assertions

Comprehensive assertion library:

```bash
source tests/utils/assert.sh

# String assertions
assert_equals "expected" "$actual"
assert_contains "$output" "substring"

# Numeric assertions
assert_gt 10 "$value"
assert_le "$count" 100

# File assertions
assert_file_exists "/path/to/file"
assert_file_contains "config.txt" "setting=value"

# Command assertions
assert_command_exists "az"
assert_exit_code 0 "command"
```

### Cleanup

Automatic cleanup of test resources:

```bash
source tests/utils/cleanup.sh

# Register cleanup task
register_cleanup "rm -rf /tmp/test-*"

# Execute all cleanup tasks
execute_cleanup

# Full cleanup
full_test_cleanup
```

## CI/CD Integration

Tests run automatically via GitHub Actions:

- **On Push**: To main/develop branches
- **On PR**: All pull requests
- **Scheduled**: Daily at 2 AM UTC
- **Manual**: Via workflow dispatch

### GitHub Actions Workflow

The CI/CD pipeline includes:

1. **Static Analysis**: ShellCheck, ansible-lint, yamllint
2. **Unit Tests**: Function testing with mocks
3. **Integration Tests**: Component interaction testing
4. **Security Tests**: Security validation and scanning
5. **Molecule Tests**: Ansible role testing
6. **Performance Benchmarks**: Operation timing

## Mock Azure CLI

The test suite includes a comprehensive mock Azure CLI for testing without real Azure resources:

```bash
# Use in tests
export PATH="$(pwd)/tests/azure-vm-automation:$PATH"
source bash/functions/azure/vm-automation.sh

# Mock will respond to Azure commands
az vm list
az network nsg rule create
```

## Security Focus

Special emphasis on security testing:

- ✅ IP restriction validation
- ✅ NSG rule verification
- ✅ SSH hardening checks
- ✅ Compliance validation (CIS, custom policies)
- ✅ No VM creation without security controls

## Test Reports

Tests generate detailed reports:

- **HTML Reports**: Detailed test results with styling
- **Text Summaries**: Quick overview of results
- **Compliance Reports**: Security compliance status
- **Performance Metrics**: Operation timing data

Reports are saved in the project root or `/tmp` directory.

## Best Practices

1. **Always run tests before deployment**
2. **Use mocks for external dependencies**
3. **Test both success and failure scenarios**
4. **Validate security controls in every test**
5. **Clean up test resources**

## Troubleshooting

### Common Issues

1. **Missing dependencies**:
   ```bash
   sudo apt-get install jq bc curl
   ```

2. **Permission errors**:
   ```bash
   chmod +x tests/**/*.sh
   ```

3. **Mock not found**:
   ```bash
   export PATH="$(pwd)/tests/azure-vm-automation:$PATH"
   ```

### Debug Mode

Run tests with debug output:

```bash
./tests/run-tests.sh -d unit
DEBUG=true ./tests/security/test-nsg-rules.sh
```

### Cleanup

If tests leave artifacts:

```bash
source tests/utils/cleanup.sh
full_test_cleanup
# or for aggressive cleanup
emergency_cleanup
```

## Contributing

When adding new features:

1. Write unit tests for new functions
2. Add integration tests for interactions
3. Include security tests for any security-related features
4. Update E2E tests if workflows change
5. Ensure all tests pass locally before pushing

## Test Coverage Goals

- Unit test coverage: > 80%
- Security test coverage: 100% for critical paths
- E2E test coverage: All major workflows
- Performance regression detection

## Future Enhancements

- [ ] Add test coverage reporting
- [ ] Implement mutation testing
- [ ] Add load testing for scalability
- [ ] Create visual test dashboards
- [ ] Add chaos testing scenarios