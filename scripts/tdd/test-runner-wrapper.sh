#!/bin/bash

# TDD Test Runner Wrapper
# Unified interface for running tests with coverage and reporting

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
COVERAGE_DIR="$PROJECT_ROOT/testing/coverage"
REPORTS_DIR="$PROJECT_ROOT/testing/reports"

# Default options
WATCH_MODE=false
COVERAGE=false
GENERATE_REPORT=false
OPEN_DASHBOARD=false
PROFILE=false
RUNNER=""
TEST_PATTERN=""
VERBOSE=false
DRY_RUN=false

# Usage function
usage() {
    echo "TDD Test Runner Wrapper"
    echo ""
    echo "Usage: $0 [OPTIONS] [TEST_PATTERN]"
    echo ""
    echo "Options:"
    echo "  -w, --watch         Enable watch mode for continuous testing"
    echo "  -c, --coverage      Collect coverage data"
    echo "  -r, --report        Generate coverage and test reports"
    echo "  -d, --dashboard     Open TDD dashboard after tests"
    echo "  -p, --profile       Enable performance profiling"
    echo "  -v, --verbose       Verbose output"
    echo "  --dry-run          Show commands without executing"
    echo "  --runner RUNNER    Specify test runner (aolite, aos-local, parity, all)"
    echo "  -h, --help         Show this help message"
    echo ""
    echo "Test Runners:"
    echo "  aolite             Unit tests with AO globals (default)"
    echo "  aos-local          Integration tests with message flow"
    echo "  parity             TypeScript-AO parity validation"
    echo "  all                All test suites"
    echo ""
    echo "Examples:"
    echo "  $0 --runner aolite                           # Run all unit tests"
    echo "  $0 --runner aos-local --coverage             # Integration tests with coverage"
    echo "  $0 --watch testing/unit/battle-engine.test.lua  # Watch specific test file"
    echo "  $0 --coverage --report --dashboard           # Full test run with reports"
    echo "  $0 --runner all --profile                    # Performance profiling"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -w|--watch)
            WATCH_MODE=true
            shift
            ;;
        -c|--coverage)
            COVERAGE=true
            shift
            ;;
        -r|--report)
            GENERATE_REPORT=true
            shift
            ;;
        -d|--dashboard)
            OPEN_DASHBOARD=true
            shift
            ;;
        -p|--profile)
            PROFILE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --runner)
            RUNNER="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
        *)
            TEST_PATTERN="$1"
            shift
            ;;
    esac
done

# Set default runner if not specified
if [ -z "$RUNNER" ]; then
    if [ -n "$TEST_PATTERN" ]; then
        # Determine runner based on test file location
        if [[ "$TEST_PATTERN" == *"/integration/"* ]]; then
            RUNNER="aos-local"
        elif [[ "$TEST_PATTERN" == *"/parity/"* ]]; then
            RUNNER="parity"
        else
            RUNNER="aolite"
        fi
    else
        RUNNER="aolite"
    fi
fi

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_verbose() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}🔍 $1${NC}"
    fi
}

# Execute command with dry-run support
execute_command() {
    local cmd="$1"
    local description="$2"
    
    if [ -n "$description" ]; then
        log_info "$description"
    fi
    
    log_verbose "Command: $cmd"
    
    if [ "$DRY_RUN" = true ]; then
        echo "DRY RUN: $cmd"
    else
        eval "$cmd"
    fi
}

# Setup environment
setup_environment() {
    log_info "Setting up test environment..."
    
    # Create directories if they don't exist
    execute_command "mkdir -p '$COVERAGE_DIR'" "Creating coverage directory"
    execute_command "mkdir -p '$REPORTS_DIR'" "Creating reports directory"
    
    # Change to project root
    cd "$PROJECT_ROOT"
    
    log_verbose "Working directory: $(pwd)"
    log_verbose "Runner: $RUNNER"
    log_verbose "Test pattern: $TEST_PATTERN"
    log_verbose "Coverage: $COVERAGE"
    log_verbose "Watch mode: $WATCH_MODE"
}

# Initialize coverage collection
init_coverage() {
    if [ "$COVERAGE" = true ]; then
        log_info "Initializing coverage collection..."
        execute_command "lua scripts/coverage/lua-coverage-collector.lua init" "Initializing coverage collector"
    fi
}

# Run tests with specified runner
run_tests() {
    local runner="$1"
    local pattern="$2"
    
    case "$runner" in
        aolite)
            run_aolite_tests "$pattern"
            ;;
        aos-local)
            run_aos_local_tests "$pattern"
            ;;
        parity)
            run_parity_tests "$pattern"
            ;;
        all)
            run_all_tests "$pattern"
            ;;
        *)
            log_error "Unknown test runner: $runner"
            exit 1
            ;;
    esac
}

# Run aolite tests (unit tests)
run_aolite_tests() {
    local pattern="$1"
    log_info "Running aolite unit tests..."
    
    local cmd="npm run test:aolite"
    if [ -n "$pattern" ]; then
        cmd="$cmd -- '$pattern'"
    fi
    
    if [ "$WATCH_MODE" = true ]; then
        cmd="$cmd --watch"
    fi
    
    if [ "$PROFILE" = true ]; then
        cmd="$cmd --profile"
    fi
    
    execute_command "$cmd" "Executing aolite tests"
}

# Run aos-local tests (integration tests)
run_aos_local_tests() {
    local pattern="$1"
    log_info "Running aos-local integration tests..."
    
    local cmd="npm run test:aos-local"
    if [ -n "$pattern" ]; then
        cmd="$cmd -- '$pattern'"
    fi
    
    if [ "$PROFILE" = true ]; then
        cmd="$cmd --profile"
    fi
    
    execute_command "$cmd" "Executing aos-local tests"
}

# Run parity tests
run_parity_tests() {
    local pattern="$1"
    log_info "Running TypeScript-AO parity tests..."
    
    local cmd="npm run test:parity"
    if [ -n "$pattern" ]; then
        cmd="$cmd -- '$pattern'"
    fi
    
    execute_command "$cmd" "Executing parity tests"
}

# Run all test suites
run_all_tests() {
    local pattern="$1"
    log_info "Running all test suites..."
    
    local cmd="npm run test:all"
    if [ -n "$pattern" ]; then
        log_warning "Pattern ignored for 'all' runner - running complete test suite"
    fi
    
    execute_command "$cmd" "Executing all tests"
}

# Generate coverage report
generate_coverage_report() {
    if [ "$COVERAGE" = true ]; then
        log_info "Generating coverage report..."
        execute_command "lua scripts/coverage/lua-coverage-collector.lua report '$COVERAGE_DIR/coverage-report.json'" "Collecting coverage data"
        execute_command "node scripts/coverage/coverage-reporter.js '$COVERAGE_DIR/coverage-report.json'" "Generating coverage reports"
        log_success "Coverage report generated in $COVERAGE_DIR"
    fi
}

# Generate test reports
generate_test_reports() {
    if [ "$GENERATE_REPORT" = true ]; then
        log_info "Generating test reports..."
        
        # Generate test documentation
        execute_command "find testing/ -name '*.test.lua' -exec lua scripts/generators/test-doc-generator.lua generate {} \;" "Generating test documentation"
        
        # Generate test summary
        execute_command "node tools/issue-linker/test-issue-mapper.js report > '$REPORTS_DIR/test-summary.json'" "Generating test summary"
        
        log_success "Test reports generated in $REPORTS_DIR"
    fi
}

# Open TDD dashboard
open_dashboard() {
    if [ "$OPEN_DASHBOARD" = true ]; then
        log_info "Opening TDD dashboard..."
        
        if command -v open >/dev/null 2>&1; then
            execute_command "open 'tools/dashboard/index.html'" "Opening dashboard in browser"
        elif command -v xdg-open >/dev/null 2>&1; then
            execute_command "xdg-open 'tools/dashboard/index.html'" "Opening dashboard in browser"
        else
            log_warning "Cannot open browser automatically. Please open tools/dashboard/index.html manually"
        fi
    fi
}

# Watch mode implementation
run_watch_mode() {
    if [ "$WATCH_MODE" = true ]; then
        log_info "Starting watch mode..."
        log_info "Watching for changes in test files and source files..."
        log_info "Press Ctrl+C to stop watching"
        
        # Use fswatch if available, otherwise fall back to basic polling
        if command -v fswatch >/dev/null 2>&1; then
            fswatch -o testing/ ao-processes/ processes/ | while read event; do
                log_info "Files changed, running tests..."
                run_tests "$RUNNER" "$TEST_PATTERN"
                if [ "$COVERAGE" = true ]; then
                    generate_coverage_report
                fi
            done
        else
            log_warning "fswatch not found, using basic polling (install fswatch for better performance)"
            
            while true; do
                sleep 5
                # Basic change detection would go here
                # For now, just run tests every 30 seconds
                log_info "Running periodic test check..."
                run_tests "$RUNNER" "$TEST_PATTERN"
                if [ "$COVERAGE" = true ]; then
                    generate_coverage_report
                fi
                sleep 25
            done
        fi
    fi
}

# Validate test environment
validate_environment() {
    log_info "Validating test environment..."
    
    # Check if npm is installed
    if ! command -v npm >/dev/null 2>&1; then
        log_error "npm is not installed"
        exit 1
    fi
    
    # Check if lua is installed
    if ! command -v lua >/dev/null 2>&1; then
        log_error "lua is not installed"
        exit 1
    fi
    
    # Check if node is installed
    if ! command -v node >/dev/null 2>&1; then
        log_error "node is not installed"
        exit 1
    fi
    
    # Check if package.json exists
    if [ ! -f "package.json" ]; then
        log_error "package.json not found - run from project root"
        exit 1
    fi
    
    # Check if test scripts exist
    if ! npm run | grep -q "test:aolite"; then
        log_warning "test:aolite script not found in package.json"
    fi
    
    log_success "Environment validation passed"
}

# Performance profiling
run_with_profiling() {
    if [ "$PROFILE" = true ]; then
        log_info "Performance profiling enabled"
        
        local start_time=$(date +%s.%N)
        run_tests "$RUNNER" "$TEST_PATTERN"
        local end_time=$(date +%s.%N)
        
        local duration=$(echo "$end_time - $start_time" | bc)
        log_success "Test execution completed in ${duration}s"
        
        # Save profiling data
        echo "{\"runner\":\"$RUNNER\",\"duration\":$duration,\"timestamp\":\"$(date -Iseconds)\"}" > "$REPORTS_DIR/profile-$(date +%s).json"
    else
        run_tests "$RUNNER" "$TEST_PATTERN"
    fi
}

# Cleanup function
cleanup() {
    log_info "Cleaning up..."
    
    # Kill any background processes
    jobs -p | xargs -r kill
    
    log_success "Cleanup completed"
}

# Trap cleanup on exit
trap cleanup EXIT

# Main execution
main() {
    # Print header
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    TDD Test Runner Wrapper                  ║"
    echo "║                                                              ║"
    echo "║  Unified interface for running tests with coverage          ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Validate environment
    validate_environment
    
    # Setup environment
    setup_environment
    
    # Initialize coverage if enabled
    init_coverage
    
    # Run tests
    if [ "$WATCH_MODE" = true ]; then
        run_watch_mode
    else
        if [ "$PROFILE" = true ]; then
            run_with_profiling
        else
            run_tests "$RUNNER" "$TEST_PATTERN"
        fi
    fi
    
    # Generate reports
    generate_coverage_report
    generate_test_reports
    
    # Open dashboard
    open_dashboard
    
    log_success "Test run completed successfully!"
}

# Run main function
main "$@"