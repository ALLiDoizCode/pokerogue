#!/bin/bash

# Test HyperBeam Local API
set -e

echo "Testing HyperBeam Local API..."

cd hyperbeam-local

echo "Starting HyperBeam in background..."
erl -pa _build/default/lib/*/ebin \
    -eval "application:ensure_all_started(hyperbeam_local), io:format('HyperBeam started on http://localhost:8080~n')" \
    -noshell \
    -detached \
    -name hyperbeam_test@127.0.0.1

echo "Waiting for startup..."
sleep 3

echo ""
echo "Testing API endpoints:"
echo "====================="

echo ""
echo "1. System Status:"
curl -s http://localhost:8080/api/debug/system/status | python3 -m json.tool 2>/dev/null || echo "Failed to get system status"

echo ""
echo "2. Device List:"
curl -s http://localhost:8080/api/devices | python3 -m json.tool 2>/dev/null || echo "Failed to get device list"

echo ""
echo "3. Process List:"
curl -s http://localhost:8080/api/processes | python3 -m json.tool 2>/dev/null || echo "Failed to get process list"

echo ""
echo "4. Test Echo Message:"
curl -s -X POST http://localhost:8080/api/message \
  -H "Content-Type: application/json" \
  -d '{"target": "rust_template_device", "data": "Hello HyperBeam!", "action": "Echo"}' | python3 -m json.tool 2>/dev/null || echo "Failed to send message"

echo ""
echo "Test complete!"
echo ""
echo "To stop: pkill -f hyperbeam_test"