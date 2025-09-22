#!/bin/bash

# Integrity validation script for TypeScript reference implementation
# Generates and validates SHA-256 checksums for critical game logic files

set -e

SCRIPT_DIR="$(dirname "$0")"
REFERENCE_DIR="$(dirname "$SCRIPT_DIR")"
CHECKSUMS_FILE="$REFERENCE_DIR/checksums.sha256"

echo "TypeScript Reference Integrity Validation"

# Navigate to typescript-reference directory
cd "$REFERENCE_DIR"

# Function to generate checksums
generate_checksums() {
    echo "Generating checksums for critical game logic files..."
    
    # Create checksums for all TypeScript source files
    find src -name "*.ts" -type f | sort | xargs sha256sum > "$CHECKSUMS_FILE"
    
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
    
    if sha256sum --check "$CHECKSUMS_FILE" --quiet; then
        echo "✅ All checksums valid - TypeScript reference integrity confirmed"
        return 0
    else
        echo "❌ Checksum validation failed - TypeScript reference has been modified"
        echo "Run 'sha256sum --check $CHECKSUMS_FILE' for detailed information"
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