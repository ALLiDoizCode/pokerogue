#!/bin/bash

# Simple HyperBeam Local Testing Environment Startup
set -e

echo "Starting HyperBeam Local Testing Environment (Simple Mode)..."

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

cd hyperbeam-local

echo -e "${GREEN}HyperBeam Local Testing Environment${NC}"
echo -e "${GREEN}====================================${NC}"
echo -e "${BLUE}HTTP API: http://localhost:8080${NC}"
echo -e "${BLUE}Starting with manual supervision...${NC}"
echo ""

# Start Erlang with our application in a way that works
erl -pa _build/default/lib/*/ebin \
    -eval "application:ensure_all_started(hyperbeam_local)." \
    -eval "io:format('HyperBeam Local node started successfully!~n')." \
    -eval "io:format('HTTP API available at http://localhost:8080~n')." \
    -eval "io:format('Press Ctrl+C to stop~n')."