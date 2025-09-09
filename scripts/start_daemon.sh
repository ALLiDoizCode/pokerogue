#!/bin/bash

# HyperBeam Local Testing Environment Daemon Startup
set -e

echo "Starting HyperBeam Local Testing Environment as daemon..."

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

cd hyperbeam-local

echo -e "${GREEN}HyperBeam Local Testing Environment${NC}"
echo -e "${GREEN}====================================${NC}"
echo -e "${BLUE}HTTP API: http://localhost:8080${NC}"
echo -e "${YELLOW}Starting as background daemon...${NC}"
echo ""

# Start Erlang as a detached daemon
erl -pa _build/default/lib/*/ebin \
    -eval "application:ensure_all_started(hyperbeam_local)" \
    -eval "io:format('HyperBeam Local node started successfully!~n')" \
    -eval "io:format('HTTP API available at http://localhost:8080~n')" \
    -eval "io:format('Daemon PID: ~p~n', [os:getpid()])" \
    -noshell \
    -detached

echo -e "${GREEN}HyperBeam daemon started!${NC}"
echo ""
echo -e "${YELLOW}Available API endpoints:${NC}"
echo -e "  GET  /api/devices           - List all devices"
echo -e "  GET  /api/debug/system/status - System status"
echo ""
echo -e "${BLUE}Test with: curl http://localhost:8080/api/debug/system/status${NC}"
echo ""
echo -e "${YELLOW}To stop, use: pkill -f hyperbeam_local${NC}"