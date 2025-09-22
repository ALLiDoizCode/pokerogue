#!/bin/bash

# Test execution script for TypeScript reference implementation
# Runs isolated tests for parity validation

set -e

echo "Running TypeScript Reference Tests..."

# Navigate to typescript-reference directory
cd "$(dirname "$0")/.."

# Ensure dependencies are installed
if [ ! -d "node_modules" ]; then
    echo "Installing dependencies..."
    npm install
fi

# Run TypeScript reference tests
echo "Executing TypeScript reference test suite..."
npm run test:reference

echo "TypeScript reference tests completed successfully!"