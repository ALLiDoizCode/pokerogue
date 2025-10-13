#!/bin/bash

# Game startup script for TypeScript reference implementation
# Launches development server for testing and validation

set -e

echo "Starting TypeScript Reference Game Instance..."

# Navigate to typescript-reference directory
cd "$(dirname "$0")/.."

# Ensure dependencies are installed
if [ ! -d "node_modules" ]; then
    echo "Installing dependencies..."
    npm install
fi

# Start the game development server
echo "Launching TypeScript reference game server..."
echo "Access at: http://localhost:5173"
npm run start:game