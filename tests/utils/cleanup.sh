#!/bin/bash

# Test cleanup utilities for Azure VM automation tests
# Provides functions to clean up test resources and restore system state

set -euo pipefail

# Import test helpers if available
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/test-helpers.sh" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/test-helpers.sh"
else
    # Define logging functions if not imported
    log_info() { echo "[INFO] $*"; }
    log_warning() { echo "[WARNING] $*"; }
    log_error() { echo "[ERROR] $*" >&2; }
    log_debug() { [[ "${DEBUG:-false}" == "true" ]] && echo "[DEBUG] $*"; }
fi

# Cleanup tracking
CLEANUP_TASKS=()
CLEANUP_ERRORS=0

# Register cleanup task
register_cleanup() {
    local task="$1"
    CLEANUP_TASKS+=("$task")
    log_debug "Registered cleanup task: $task"
}

# Execute all cleanup tasks
execute_cleanup() {
    local force="${1:-false}"
    
    if [[ ${#CLEANUP_TASKS[@]} -eq 0 ]]; then
        log_debug "No cleanup tasks registered"
        return 0
    fi
    
    log_info "Executing ${#CLEANUP_TASKS[@]} cleanup tasks..."
    
    # Execute tasks in reverse order (LIFO)
    for ((i=${#CLEANUP_TASKS[@]}-1; i>=0; i--)); do
        local task="${CLEANUP_TASKS[$i]}"
        log_debug "Executing cleanup: $task"
        
        if eval "$task"; then
            log_debug "Cleanup successful: $task"
        else
            ((CLEANUP_ERRORS++))
            log_error "Cleanup failed: $task"
            
            if [[ "$force" != "true" ]]; then
                log_warning "Stopping cleanup due to error (use force=true to continue)"
                return 1
            fi
        fi
    done
    
    # Clear tasks after execution
    CLEANUP_TASKS=()
    
    if [[ $CLEANUP_ERRORS -gt 0 ]]; then
        log_warning "Cleanup completed with $CLEANUP_ERRORS errors"
        return 1
    else
        log_info "All cleanup tasks completed successfully"
        return 0
    fi
}

# File system cleanup
cleanup_test_files() {
    local test_dir="${1:-/tmp}"
    local pattern="${2:-test-*}"
    
    log_info "Cleaning up test files matching: $test_dir/$pattern"
    
    local count=0
    while IFS= read -r -d '' file; do
        if rm -rf "$file" 2>/dev/null; then
            ((count++))
            log_debug "Removed: $file"
        else
            log_error "Failed to remove: $file"
        fi
    done < <(find "$test_dir" -maxdepth 1 -name "$pattern" -print0 2>/dev/null)
    
    log_info "Cleaned up $count test files/directories"
}

cleanup_temp_files() {
    cleanup_test_files "/tmp" "azure-vm-test-*"
    cleanup_test_files "/tmp" "e2e-*"
    cleanup_test_files "/tmp" "test-*"
}

# Process cleanup
cleanup_mock_processes() {
    local process_pattern="${1:-mock}"
    
    log_info "Cleaning up processes matching: $process_pattern"
    
    local pids=$(pgrep -f "$process_pattern" 2>/dev/null || true)
    if [[ -n "$pids" ]]; then
        for pid in $pids; do
            if kill "$pid" 2>/dev/null; then
                log_debug "Killed process: $pid"
            else
                log_debug "Process already terminated: $pid"
            fi
        done
        
        # Wait for processes to terminate
        sleep 1
        
        # Force kill if still running
        pids=$(pgrep -f "$process_pattern" 2>/dev/null || true)
        if [[ -n "$pids" ]]; then
            for pid in $pids; do
                kill -9 "$pid" 2>/dev/null || true
                log_warning "Force killed process: $pid"
            done
        fi
    else
        log_debug "No processes found matching: $process_pattern"
    fi
}

# Environment cleanup
cleanup_environment_variables() {
    local prefix="${1:-TEST_}"
    
    log_info "Cleaning up environment variables with prefix: $prefix"
    
    local count=0
    while IFS= read -r var; do
        if [[ -n "$var" ]]; then
            unset "$var"
            ((count++))
            log_debug "Unset: $var"
        fi
    done < <(compgen -v | grep "^$prefix")
    
    log_info "Cleaned up $count environment variables"
}

restore_path() {
    if [[ -n "${ORIGINAL_PATH:-}" ]]; then
        export PATH="$ORIGINAL_PATH"
        unset ORIGINAL_PATH
        log_info "Restored original PATH"
    else
        log_debug "No original PATH to restore"
    fi
}

# Mock cleanup
cleanup_mocks() {
    local mock_dir="${1:-/tmp/mocks}"
    
    if [[ -d "$mock_dir" ]]; then
        if rm -rf "$mock_dir"; then
            log_info "Removed mock directory: $mock_dir"
        else
            log_error "Failed to remove mock directory: $mock_dir"
            return 1
        fi
    else
        log_debug "Mock directory not found: $mock_dir"
    fi
}

# Azure resource cleanup (for real resources)
cleanup_azure_resources() {
    local resource_group="${1:-}"
    local dry_run="${2:-true}"
    
    if [[ -z "$resource_group" ]]; then
        log_warning "No resource group specified for cleanup"
        return 0
    fi
    
    log_info "Cleaning up Azure resources in group: $resource_group"
    
    if [[ "$dry_run" == "true" ]]; then
        log_warning "DRY RUN - No actual resources will be deleted"
        
        # List resources that would be deleted
        if command -v az &> /dev/null; then
            echo "Resources that would be deleted:"
            az resource list --resource-group "$resource_group" --query "[].{name:name, type:type}" -o table 2>/dev/null || true
        fi
    else
        log_warning "DELETING Azure resource group: $resource_group"
        
        if command -v az &> /dev/null; then
            if az group delete --name "$resource_group" --yes --no-wait 2>/dev/null; then
                log_info "Resource group deletion initiated: $resource_group"
            else
                log_error "Failed to delete resource group: $resource_group"
                return 1
            fi
        else
            log_warning "Azure CLI not available - skipping resource cleanup"
        fi
    fi
}

# SSH cleanup
cleanup_ssh_keys() {
    local ssh_dir="${1:-$HOME/.ssh}"
    local key_pattern="${2:-test-*}"
    
    log_info "Cleaning up test SSH keys matching: $ssh_dir/$key_pattern"
    
    local count=0
    for key_file in "$ssh_dir"/$key_pattern; do
        if [[ -f "$key_file" ]]; then
            if rm -f "$key_file" "$key_file.pub" 2>/dev/null; then
                ((count++))
                log_debug "Removed SSH key: $key_file"
            else
                log_error "Failed to remove SSH key: $key_file"
            fi
        fi
    done
    
    log_info "Cleaned up $count SSH key pairs"
}

cleanup_ssh_config() {
    local ssh_config="${1:-$HOME/.ssh/config}"
    local marker="${2:-# TEST ENTRY}"
    
    if [[ ! -f "$ssh_config" ]]; then
        log_debug "SSH config not found: $ssh_config"
        return 0
    fi
    
    log_info "Cleaning up test entries from SSH config"
    
    # Create backup
    cp "$ssh_config" "$ssh_config.bak"
    
    # Remove test entries (between markers)
    awk -v marker="$marker" '
        $0 ~ marker " START" { skip = 1; next }
        $0 ~ marker " END" { skip = 0; next }
        !skip { print }
    ' "$ssh_config.bak" > "$ssh_config"
    
    log_info "Cleaned up SSH config (backup: $ssh_config.bak)"
}

# Log cleanup
cleanup_test_logs() {
    local log_dir="${1:-/tmp}"
    local log_pattern="${2:-test-*.log}"
    
    cleanup_test_files "$log_dir" "$log_pattern"
}

# Report cleanup
cleanup_test_reports() {
    local report_dir="${1:-/tmp}"
    local report_pattern="${2:-*-report-*.txt}"
    
    cleanup_test_files "$report_dir" "$report_pattern"
}

# Network cleanup
cleanup_network_resources() {
    # Clean up any test network namespaces
    if [[ -n "$(ip netns list 2>/dev/null | grep '^test-')" ]]; then
        log_info "Cleaning up test network namespaces"
        
        while IFS= read -r netns; do
            if [[ "$netns" =~ ^test- ]]; then
                if sudo ip netns delete "$netns" 2>/dev/null; then
                    log_debug "Removed network namespace: $netns"
                else
                    log_error "Failed to remove network namespace: $netns"
                fi
            fi
        done < <(ip netns list 2>/dev/null | awk '{print $1}')
    fi
}

# Docker cleanup (if used in tests)
cleanup_docker_resources() {
    local container_prefix="${1:-test-}"
    local image_prefix="${2:-test/}"
    
    if ! command -v docker &> /dev/null; then
        log_debug "Docker not available - skipping Docker cleanup"
        return 0
    fi
    
    log_info "Cleaning up Docker resources"
    
    # Stop and remove test containers
    local containers=$(docker ps -a --filter "name=^${container_prefix}" -q 2>/dev/null || true)
    if [[ -n "$containers" ]]; then
        echo "$containers" | xargs docker rm -f 2>/dev/null || true
        log_info "Removed test containers"
    fi
    
    # Remove test images
    local images=$(docker images "${image_prefix}*" -q 2>/dev/null || true)
    if [[ -n "$images" ]]; then
        echo "$images" | xargs docker rmi -f 2>/dev/null || true
        log_info "Removed test images"
    fi
}

# Full cleanup function
full_test_cleanup() {
    local force="${1:-false}"
    
    log_info "Starting full test cleanup..."
    
    # Execute all cleanup functions
    cleanup_temp_files
    cleanup_mock_processes
    cleanup_environment_variables "TEST_"
    cleanup_environment_variables "MOCK_"
    restore_path
    cleanup_mocks
    cleanup_ssh_keys "$HOME/.ssh" "test-*"
    cleanup_test_logs
    cleanup_test_reports
    cleanup_network_resources
    cleanup_docker_resources
    
    # Execute registered cleanup tasks
    execute_cleanup "$force"
    
    log_info "Full test cleanup completed"
}

# Cleanup status report
cleanup_status_report() {
    echo "Cleanup Status Report"
    echo "===================="
    echo "Cleanup errors: $CLEANUP_ERRORS"
    echo "Pending tasks: ${#CLEANUP_TASKS[@]}"
    
    if [[ ${#CLEANUP_TASKS[@]} -gt 0 ]]; then
        echo ""
        echo "Pending cleanup tasks:"
        for task in "${CLEANUP_TASKS[@]}"; do
            echo "  - $task"
        done
    fi
    
    echo ""
    echo "Temp files: $(find /tmp -name "test-*" -o -name "azure-vm-test-*" 2>/dev/null | wc -l)"
    echo "Mock processes: $(pgrep -f "mock" 2>/dev/null | wc -l)"
    
    if [[ $CLEANUP_ERRORS -eq 0 && ${#CLEANUP_TASKS[@]} -eq 0 ]]; then
        echo ""
        echo "Status: CLEAN"
    else
        echo ""
        echo "Status: NEEDS CLEANUP"
    fi
}

# Emergency cleanup (aggressive)
emergency_cleanup() {
    log_warning "Performing emergency cleanup - this may affect running tests!"
    
    # Kill all test processes
    pkill -f "test-" 2>/dev/null || true
    pkill -f "mock" 2>/dev/null || true
    
    # Remove all test files
    find /tmp -name "test-*" -o -name "e2e-*" -o -name "azure-vm-*" | xargs rm -rf 2>/dev/null || true
    
    # Clear environment
    while IFS= read -r var; do
        unset "$var" 2>/dev/null || true
    done < <(compgen -v | grep -E "^(TEST_|MOCK_|AZURE_TEST_)")
    
    log_warning "Emergency cleanup completed"
}

# Export cleanup functions
export -f register_cleanup execute_cleanup
export -f cleanup_test_files cleanup_temp_files
export -f cleanup_mock_processes
export -f cleanup_environment_variables restore_path
export -f cleanup_mocks
export -f cleanup_azure_resources
export -f cleanup_ssh_keys cleanup_ssh_config
export -f cleanup_test_logs cleanup_test_reports
export -f cleanup_network_resources cleanup_docker_resources
export -f full_test_cleanup
export -f cleanup_status_report emergency_cleanup

# Set up trap for cleanup on script exit
setup_cleanup_trap() {
    trap 'execute_cleanup true' EXIT INT TERM
}

# Display cleanup info if sourced directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Test Cleanup Utilities Loaded"
    echo "============================"
    echo "Available functions:"
    echo "  - register_cleanup: Register a cleanup task"
    echo "  - execute_cleanup: Execute all registered tasks"
    echo "  - cleanup_temp_files: Clean temporary test files"
    echo "  - cleanup_mock_processes: Kill mock processes"
    echo "  - cleanup_environment_variables: Unset test variables"
    echo "  - full_test_cleanup: Perform complete cleanup"
    echo "  - cleanup_status_report: Show cleanup status"
    echo "  - emergency_cleanup: Aggressive cleanup (use with caution)"
    echo ""
    echo "Use setup_cleanup_trap() to automatically cleanup on exit"
fi