#!/bin/bash

# Integrity validation script for TypeScript reference implementation
# Generates and validates SHA-256 checksums for critical game logic files

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REFERENCE_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$REFERENCE_DIR")"
CHECKSUMS_FILE="$REFERENCE_DIR/checksums.sha256"

echo "TypeScript Reference Integrity Validation"

# Navigate to project root directory to access main codebase
cd "$PROJECT_ROOT"

# Detect OS and use appropriate checksum command
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    SHASUM_CMD="shasum -a 256"
    SHASUM_CHECK_CMD="shasum -a 256 --check"
else
    # Linux
    SHASUM_CMD="sha256sum"
    SHASUM_CHECK_CMD="sha256sum --check"
fi

# Function to generate checksums
generate_checksums() {
    echo "Generating checksums for critical game logic files..."

    # Create checksums for all TypeScript source files
    find src -name "*.ts" -type f | sort | xargs $SHASUM_CMD > "$CHECKSUMS_FILE"

    echo "Checksums generated in: $CHECKSUMS_FILE"
    echo "Total files: $(wc -l < "$CHECKSUMS_FILE")"
}

# Function to validate checksums
validate_checksums() {
    if [ ! -f "$CHECKSUMS_FILE" ]; then
        echo "Error: Checksums file not found. Run with --generate first."
        exit 1
    fi

    echo "Validating checksums for TypeScript reference..."

    if $SHASUM_CHECK_CMD "$CHECKSUMS_FILE" --quiet 2>/dev/null || $SHASUM_CHECK_CMD "$CHECKSUMS_FILE" --status 2>/dev/null; then
        echo "✅ All checksums valid - TypeScript reference integrity confirmed"
        return 0
    else
        echo "❌ Checksum validation failed - TypeScript reference has been modified"
        echo "Run '$SHASUM_CHECK_CMD $CHECKSUMS_FILE' for detailed information"
        return 1
    fi
}

# Handle command line arguments
case "${1:-}" in
    --generate)
        generate_checksums
        ;;
    --validate)
        validate_checksums
        ;;
    *)
        echo "Usage: $0 [--generate|--validate]"
        echo "  --generate    Generate checksums for all TypeScript files"
        echo "  --validate    Validate current files against stored checksums"
        exit 1
        ;;
esac