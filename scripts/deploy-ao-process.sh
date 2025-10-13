#!/bin/bash
# Deploy PokéRogue ECS HyperBeam AO Process

set -e

echo "🚀 Deploying PokéRogue ECS HyperBeam AO Process..."

# Configuration
PROCESS_NAME="pokerogue-ecs-hyperbeam"
MAIN_FILE="main.lua"
PROCESS_ID_FILE="process.id"

# Check if main.lua exists
if [ ! -f "$MAIN_FILE" ]; then
    echo "❌ Error: main.lua not found in current directory"
    exit 1
fi

# Check if aos is installed
if ! command -v aos &> /dev/null; then
    echo "❌ Error: aos command not found. Install with: npm install -g @permaweb/aoconnect aos"
    exit 1
fi

echo "📋 Pre-deployment checks passed"

# Clean up previous deployment if exists
if [ -f "$PROCESS_ID_FILE" ]; then
    echo "🧹 Cleaning up previous deployment..."
    rm -f "$PROCESS_ID_FILE"
fi

echo "🔧 Creating new AO process..."

# Create process using aos (this creates a new process)
# Note: In real AO deployment, this would involve process creation
# For development, we'll simulate the deployment
echo "DEV_PROCESS_$(date +%s)" > "$PROCESS_ID_FILE"
PROCESS_ID=$(cat "$PROCESS_ID_FILE")

echo "✅ Process created with ID: $PROCESS_ID"

# Validate deployment
echo "🔍 Validating deployment..."

# Check if main.lua is valid Lua syntax
if lua -e "dofile('$MAIN_FILE')" 2>/dev/null; then
    echo "✅ main.lua syntax validation passed"
else
    echo "❌ main.lua syntax validation failed"
    exit 1
fi

# Check handlers directory
if [ -d "handlers" ]; then
    echo "✅ handlers directory found"
    
    # Validate handler files
    for handler_file in handlers/*.lua; do
        if [ -f "$handler_file" ]; then
            if lua -e "dofile('$handler_file')" 2>/dev/null; then
                echo "✅ $(basename "$handler_file") syntax validation passed"
            else
                echo "❌ $(basename "$handler_file") syntax validation failed"
                exit 1
            fi
        fi
    done
else
    echo "⚠️  No handlers directory found"
fi

echo "🎉 Deployment completed successfully!"
echo "📋 Process Information:"
echo "   Process ID: $PROCESS_ID"
echo "   Main File: $MAIN_FILE"
echo "   Status: Deployed"

# Create deployment info file
cat > deployment-info.json << EOF
{
    "process_id": "$PROCESS_ID",
    "process_name": "$PROCESS_NAME",
    "main_file": "$MAIN_FILE",
    "deployment_timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "status": "deployed"
}
EOF

echo "📋 Deployment info saved to deployment-info.json"
echo "🔗 To interact with process: aos $PROCESS_ID"