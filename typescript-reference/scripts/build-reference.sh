#!/bin/bash

# Build script for TypeScript reference implementation
# Used for testing isolation and parity validation

set -e

echo "Building TypeScript Reference Implementation..."

# Navigate to typescript-reference directory
cd "$(dirname "$0")/.."

# Install dependencies if node_modules doesn't exist
if [ ! -d "node_modules" ]; then
    echo "Installing TypeScript reference dependencies..."
    npm install
fi

# Type check
echo "Running TypeScript type checking..."
npm run typecheck

# Build the reference implementation
echo "Building TypeScript reference..."
npm run build:reference

echo "TypeScript reference build completed successfully!"