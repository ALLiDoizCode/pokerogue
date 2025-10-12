#!/bin/bash
# Handler Inspection Script
# Usage: ./scripts/inspect-process-handlers.sh <process-name>
# Example: ./scripts/inspect-process-handlers.sh egg-hatching-engine

if [ -z "$1" ]; then
    echo "Usage: $0 <process-name>"
    echo "Example: $0 egg-hatching-engine"
    exit 1
fi

PROCESS_FILE="processes/${1}.lua"

if [ ! -f "$PROCESS_FILE" ]; then
    echo "❌ Process file not found: $PROCESS_FILE"
    exit 1
fi

echo "🔍 Handler Analysis: $PROCESS_FILE"
echo "=================================================="
echo ""

# Extract all handler names and their action responses
echo "📝 Registered Handlers:"
grep -n "Handlers.add" "$PROCESS_FILE" | while read -r line; do
    line_num=$(echo "$line" | cut -d: -f1)
    handler_name=$(echo "$line" | sed -n 's/.*Handlers.add("\([^"]*\)".*/\1/p')
    echo "  - Handler: $handler_name (line $line_num)"
done

echo ""
echo "🎯 Action Response Patterns:"
grep -B 2 -A 10 "Handlers.add" "$PROCESS_FILE" | grep -E "(Action\s*=|hasMatchingTag.*Action)" | head -20

echo ""
echo "=================================================="
