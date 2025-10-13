#!/bin/bash

# HyperBeam Local Testing Environment - Test Runner
set -e

echo "Running HyperBeam Local Testing Environment tests..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SERVER_URL="http://localhost:8080"
TIMEOUT=30

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Helper functions
log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

log_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

# Test if server is running
check_server() {
    log_test "Checking if server is running..."
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    if curl -s "$SERVER_URL/api/debug/system/status" > /dev/null; then
        log_pass "Server is responding"
        return 0
    else
        log_fail "Server is not responding at $SERVER_URL"
        return 1
    fi
}

# Test system status endpoint
test_system_status() {
    log_test "Testing system status endpoint..."
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    local response=$(curl -s "$SERVER_URL/api/debug/system/status")
    
    if echo "$response" | grep -q "success"; then
        log_pass "System status endpoint working"
        log_info "Response: $(echo "$response" | jq -c .)"
    else
        log_fail "System status endpoint failed"
        echo "Response: $response"
    fi
}

# Test device listing
test_device_listing() {
    log_test "Testing device listing..."
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    local response=$(curl -s "$SERVER_URL/api/devices")
    
    if echo "$response" | grep -q "success"; then
        log_pass "Device listing working"
        local device_count=$(echo "$response" | jq '.data | length')
        log_info "Found $device_count devices"
    else
        log_fail "Device listing failed"
        echo "Response: $response"
    fi
}

# Test device message sending
test_device_messaging() {
    log_test "Testing device messaging..."
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    local message_data='{
        "target": "rust_template_device",
        "action": "compute",
        "data": "test computation data"
    }'
    
    local response=$(curl -s -X POST "$SERVER_URL/api/message" \
        -H "Content-Type: application/json" \
        -d "$message_data")
    
    if echo "$response" | grep -q "success"; then
        log_pass "Device messaging working"
        log_info "Response: $(echo "$response" | jq -c '.data.reply.data.status')"
    else
        log_fail "Device messaging failed"
        echo "Response: $response"
    fi
}

# Test process creation
test_process_creation() {
    log_test "Testing process creation..."
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    local process_code='
    Handlers = Handlers or {_list = {}, add = function(self, name, matcher, handler) table.insert(self._list, {name=name, matcher=matcher, handler=handler}) end}
    ao = ao or {id = "test", send = function(msg) print("Send: " .. msg.Data) end}
    
    Handlers:add("Test", function(msg) return msg.Action == "Test" end, function(msg)
        ao.send({Target = msg.From, Data = "Test response", Action = "TestResponse"})
    end)
    '
    
    local process_data=$(cat <<EOF
{
    "name": "test_process",
    "code": $(echo "$process_code" | jq -R -s .)
}
EOF
)
    
    local response=$(curl -s -X POST "$SERVER_URL/api/processes" \
        -H "Content-Type: application/json" \
        -d "$process_data")
    
    if echo "$response" | grep -q "success"; then
        log_pass "Process creation working"
        local process_id=$(echo "$response" | jq -r '.data.process_id')
        log_info "Created process: $process_id"
        
        # Store process ID for later tests
        echo "$process_id" > /tmp/test_process_id
    else
        log_fail "Process creation failed"
        echo "Response: $response"
    fi
}

# Test process messaging
test_process_messaging() {
    log_test "Testing process messaging..."
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    if [ ! -f /tmp/test_process_id ]; then
        log_fail "No test process ID available"
        return 1
    fi
    
    local process_id=$(cat /tmp/test_process_id)
    local message_data='{
        "action": "Test",
        "data": "Hello process!"
    }'
    
    local response=$(curl -s -X POST "$SERVER_URL/api/processes/$process_id/messages" \
        -H "Content-Type: application/json" \
        -d "$message_data")
    
    if echo "$response" | grep -q "success"; then
        log_pass "Process messaging working"
    else
        log_fail "Process messaging failed"
        echo "Response: $response"
    fi
}

# Test process listing
test_process_listing() {
    log_test "Testing process listing..."
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    local response=$(curl -s "$SERVER_URL/api/processes")
    
    if echo "$response" | grep -q "success"; then
        log_pass "Process listing working"
        local process_count=$(echo "$response" | jq '.data | length')
        log_info "Found $process_count processes"
    else
        log_fail "Process listing failed"
        echo "Response: $response"
    fi
}

# Test message history
test_message_history() {
    log_test "Testing message history..."
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    local response=$(curl -s "$SERVER_URL/api/debug/messages/recent?limit=5")
    
    if echo "$response" | grep -q "success"; then
        log_pass "Message history working"
        local message_count=$(echo "$response" | jq '.data | length')
        log_info "Found $message_count recent messages"
    else
        log_fail "Message history failed"
        echo "Response: $response"
    fi
}

# Load test with multiple concurrent requests
test_load() {
    log_test "Running load test..."
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    log_info "Sending 10 concurrent requests..."
    
    local pids=()
    for i in {1..10}; do
        (
            curl -s "$SERVER_URL/api/debug/system/status" > /dev/null
            echo "Request $i completed"
        ) &
        pids+=($!)
    done
    
    # Wait for all requests to complete
    for pid in "${pids[@]}"; do
        wait $pid
    done
    
    log_pass "Load test completed"
}

# Cleanup function
cleanup() {
    log_info "Cleaning up test artifacts..."
    rm -f /tmp/test_process_id
}

# Main test execution
run_tests() {
    echo -e "${GREEN}=== HyperBeam Local Testing Environment Test Suite ===${NC}"
    
    # Check prerequisites
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}curl is required for testing${NC}"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}jq is required for JSON parsing in tests${NC}"
        exit 1
    fi
    
    # Run tests
    check_server || exit 1
    
    test_system_status
    test_device_listing
    test_device_messaging
    test_process_creation
    test_process_messaging
    test_process_listing  
    test_message_history
    test_load
    
    # Cleanup
    cleanup
    
    # Report results
    echo ""
    echo -e "${GREEN}=== Test Results ===${NC}"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    echo -e "${BLUE}Total:  $TESTS_TOTAL${NC}"
    echo ""
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}All tests passed! 🎉${NC}"
        exit 0
    else
        echo -e "${RED}Some tests failed. Check the output above for details.${NC}"
        exit 1
    fi
}

# Handle script arguments
case "${1:-}" in
    --server-check)
        check_server
        exit $?
        ;;
    --help|-h)
        echo "HyperBeam Local Testing Environment Test Runner"
        echo ""
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --server-check    Only check if server is running"
        echo "  --help, -h        Show this help message"
        echo ""
        echo "Environment variables:"
        echo "  SERVER_URL        Server URL (default: http://localhost:8080)"
        echo "  TIMEOUT           Request timeout (default: 30)"
        exit 0
        ;;
    "")
        run_tests
        ;;
    *)
        echo -e "${RED}Unknown option: $1${NC}"
        echo "Use --help for usage information"
        exit 1
        ;;
esac