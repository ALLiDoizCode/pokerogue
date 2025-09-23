#!/bin/bash

# TDD Pre-commit Hook - Enforces test-first development
# Validates that all modified code has corresponding passing tests

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
BYPASS_LOG=".git/tdd-bypass.log"
TEST_MAPPER="scripts/tdd/test-mapper.lua"
SERVER_BYPASS_VALIDATOR="scripts/hooks/server-side-bypass-validator.js"

# Function to log bypass attempts (client-side)
log_bypass() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - TDD bypass by $(git config user.name) for commit $(git rev-parse --short HEAD 2>/dev/null || echo 'uncommitted')" >> "$BYPASS_LOG"
}

# Function to validate server-side bypass
validate_server_bypass() {
    local bypass_reason="$1"
    local user_name=$(git config user.name)
    local repo_name=$(basename $(git rev-parse --show-toplevel))
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
    
    # Construct bypass request
    local bypass_request=$(cat <<EOF
{
    "user": "$user_name",
    "repository": "$repo_name", 
    "justification": "$bypass_reason",
    "timestamp": "$timestamp"
}
EOF
)
    
    echo -e "${YELLOW}🔒 Validating bypass with server-side protection...${NC}"
    
    # Call server-side validator
    if ! command -v node >/dev/null 2>&1; then
        echo -e "${RED}❌ Node.js not available for server-side validation${NC}"
        echo -e "${RED}❌ TDD bypass denied - server-side validation required${NC}"
        return 1
    fi
    
    local validation_result
    if validation_result=$(node "$SERVER_BYPASS_VALIDATOR" validate "$bypass_request" 2>&1); then
        echo -e "${GREEN}✅ Server-side bypass validation passed${NC}"
        
        # Extract bypass token from result
        local bypass_token=$(echo "$validation_result" | node -e "
            const data = JSON.parse(require('fs').readFileSync('/dev/stdin', 'utf8'));
            console.log(data.bypassToken || '');
        ")
        
        if [ -n "$bypass_token" ]; then
            # Store bypass token for verification
            echo "$bypass_token" > ".git/current-bypass-token"
            echo -e "${GREEN}🎫 Bypass token issued and stored${NC}"
            
            # Show bypass conditions
            echo -e "${YELLOW}📋 Bypass approved with conditions:${NC}"
            echo -e "   • Limited time validity (30 minutes)"
            echo -e "   • Requires documentation of changes"
            echo -e "   • Full audit trail maintained"
        fi
        
        return 0
    else
        echo -e "${RED}❌ Server-side bypass validation failed:${NC}"
        echo "$validation_result" | node -e "
            try {
                const data = JSON.parse(require('fs').readFileSync('/dev/stdin', 'utf8'));
                console.log('   Reason: ' + (data.message || data.reason || 'Unknown error'));
                if (data.remainingBypasses !== undefined) {
                    console.log('   Remaining bypasses today: ' + data.remainingBypasses);
                }
                if (data.requiredApprovers) {
                    console.log('   Required approvers: ' + data.requiredApprovers.join(', '));
                }
            } catch (e) {
                console.log('   ' + require('fs').readFileSync('/dev/stdin', 'utf8'));
            }
        "
        return 1
    fi
}

# Enhanced bypass handling with server-side validation
handle_bypass_request() {
    echo -e "\n${YELLOW}🚨 TDD validation failed!${NC}"
    echo -e "${YELLOW}A TDD bypass can be requested, but requires server-side authorization.${NC}"
    echo -e "${YELLOW}Please provide a detailed justification (minimum 50 characters):${NC}"
    
    read -p "Bypass justification: " bypass_reason
    
    if [ ${#bypass_reason} -lt 50 ]; then
        echo -e "${RED}❌ Justification too short. Minimum 50 characters required.${NC}"
        echo -e "${RED}❌ TDD bypass denied${NC}"
        return 1
    fi
    
    if validate_server_bypass "$bypass_reason"; then
        echo -e "${GREEN}✅ TDD bypass authorized. Proceeding with commit.${NC}"
        return 0
    else
        echo -e "${RED}❌ TDD bypass denied by server-side validation${NC}"
        echo -e "\n${YELLOW}Alternative options:${NC}"
        echo -e "   1. Fix the failing tests and retry commit"
        echo -e "   2. Contact an approved admin for emergency override"
        echo -e "   3. Use emergency secret (if available): git commit --no-verify"
        return 1
    fi
}

# Check if --no-verify flag is used (legacy bypass - now with warnings)
if [ "$1" = "--no-verify" ]; then
    echo -e "${RED}⚠️  WARNING: Using legacy --no-verify bypass${NC}"
    echo -e "${RED}⚠️  This bypasses both TDD validation AND server-side protection${NC}"
    echo -e "${RED}⚠️  Consider using the secure bypass mechanism instead${NC}"
    
    # Still log the bypass but mark it as potentially insecure
    log_bypass
    echo "$(date '+%Y-%m-%d %H:%M:%S') - INSECURE BYPASS: --no-verify used by $(git config user.name)" >> "$BYPASS_LOG"
    
    echo -e "${YELLOW}⚠️  Proceeding with legacy bypass (NOT RECOMMENDED)${NC}"
    exit 0
fi

echo -e "${GREEN}🧪 Running TDD validation checks...${NC}"

# Get list of modified Lua files
MODIFIED_LUA_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.lua$' || true)

if [ -z "$MODIFIED_LUA_FILES" ]; then
    echo -e "${GREEN}✓ No Lua files modified${NC}"
    exit 0
fi

# Check if test mapper exists
if [ ! -f "$TEST_MAPPER" ]; then
    echo -e "${YELLOW}⚠️  Test mapper not found. Creating...${NC}"
    mkdir -p scripts/tdd
    # Will create the test mapper in the next step
fi

# Track validation results
VALIDATION_FAILED=false
MISSING_TESTS=""
FAILING_TESTS=""

# Process each modified file
for FILE in $MODIFIED_LUA_FILES; do
    # Skip test files themselves
    if echo "$FILE" | grep -q 'test\|spec'; then
        continue
    fi
    
    # Skip certain directories that don't require tests
    if echo "$FILE" | grep -q 'data/\|templates/\|fixtures/'; then
        continue
    fi
    
    # Determine expected test file location
    if echo "$FILE" | grep -q '^processes/'; then
        TEST_FILE=$(echo "$FILE" | sed 's|^processes/|testing/unit/|' | sed 's|\.lua$|.test.lua|')
    elif echo "$FILE" | grep -q '^ao-processes/'; then
        TEST_FILE=$(echo "$FILE" | sed 's|^ao-processes/|ao-processes/tests/unit/|' | sed 's|\.lua$|.test.lua|')
    else
        TEST_FILE=$(echo "$FILE" | sed 's|\.lua$|.test.lua|')
    fi
    
    # Check if test file exists
    if [ ! -f "$TEST_FILE" ]; then
        echo -e "${RED}✗ Missing test file for: $FILE${NC}"
        echo "  Expected: $TEST_FILE"
        MISSING_TESTS="$MISSING_TESTS\n  - $FILE (missing: $TEST_FILE)"
        VALIDATION_FAILED=true
        continue
    fi
    
    # Run the test file if it exists
    echo -e "  Testing: $TEST_FILE"
    
    # Determine test runner based on location
    if echo "$TEST_FILE" | grep -q '^testing/unit/'; then
        # Run with aolite
        if ! npm run test:aolite -- "$TEST_FILE" > /dev/null 2>&1; then
            echo -e "${RED}✗ Tests failing for: $FILE${NC}"
            FAILING_TESTS="$FAILING_TESTS\n  - $FILE (failing: $TEST_FILE)"
            VALIDATION_FAILED=true
        else
            echo -e "${GREEN}  ✓ Tests passing${NC}"
        fi
    elif echo "$TEST_FILE" | grep -q '^ao-processes/tests/'; then
        # Run with aos-local if it's an integration test, otherwise aolite
        if echo "$TEST_FILE" | grep -q 'integration'; then
            if ! npm run test:aos-local -- "$TEST_FILE" > /dev/null 2>&1; then
                echo -e "${RED}✗ Tests failing for: $FILE${NC}"
                FAILING_TESTS="$FAILING_TESTS\n  - $FILE (failing: $TEST_FILE)"
                VALIDATION_FAILED=true
            else
                echo -e "${GREEN}  ✓ Tests passing${NC}"
            fi
        else
            if ! npm run test:aolite -- "$TEST_FILE" > /dev/null 2>&1; then
                echo -e "${RED}✗ Tests failing for: $FILE${NC}"
                FAILING_TESTS="$FAILING_TESTS\n  - $FILE (failing: $TEST_FILE)"
                VALIDATION_FAILED=true
            else
                echo -e "${GREEN}  ✓ Tests passing${NC}"
            fi
        fi
    fi
done

# Report results
if [ "$VALIDATION_FAILED" = true ]; then
    echo -e "\n${RED}════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}TDD Validation Failed!${NC}"
    
    if [ -n "$MISSING_TESTS" ]; then
        echo -e "\n${YELLOW}Missing test files:${NC}"
        echo -e "$MISSING_TESTS"
        echo -e "\n${YELLOW}To generate test skeletons, run:${NC}"
        echo -e "  npm run tdd:generate-tests"
    fi
    
    if [ -n "$FAILING_TESTS" ]; then
        echo -e "\n${YELLOW}Failing tests:${NC}"
        echo -e "$FAILING_TESTS"
        echo -e "\n${YELLOW}To run tests and see details:${NC}"
        echo -e "  npm test"
    fi
    
    echo -e "${RED}════════════════════════════════════════════════════════${NC}"
    
    # Offer secure bypass option with server-side validation
    echo -e "\n${YELLOW}🔒 SECURE BYPASS OPTION AVAILABLE${NC}"
    echo -e "${YELLOW}Would you like to request a secure TDD bypass? (y/N)${NC}"
    read -p "Request bypass: " request_bypass
    
    if [[ "$request_bypass" =~ ^[Yy]$ ]]; then
        if handle_bypass_request; then
            echo -e "\n${GREEN}✅ Commit proceeding with authorized bypass${NC}"
            exit 0
        else
            echo -e "\n${RED}❌ Bypass denied. Commit blocked.${NC}"
            exit 1
        fi
    fi
    
    echo -e "\n${YELLOW}Alternative options:${NC}"
    echo -e "  1. Fix the failing tests and retry commit"
    echo -e "  2. Generate missing test files: npm run tdd:generate-tests"
    echo -e "  3. Run specific tests: npm test"
    echo -e "  4. Use insecure bypass (NOT RECOMMENDED): git commit --no-verify"
    echo -e "${RED}════════════════════════════════════════════════════════${NC}\n"
    
    exit 1
fi

echo -e "${GREEN}✓ All TDD checks passed!${NC}"
exit 0