#!/bin/bash

# HyperBeam Local Testing Environment - Startup Script
set -e

echo "Starting HyperBeam Local Testing Environment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
HTTP_PORT=${HTTP_PORT:-8080}
WEBSOCKET_PORT=${WEBSOCKET_PORT:-8081}
NODE_NAME=${NODE_NAME:-hyperbeam_local}

# Check if environment is built
check_build() {
    echo -e "${BLUE}Checking build status...${NC}"
    
    if [ ! -f "hyperbeam-local/_build/default/lib/hyperbeam_local/ebin/hyperbeam_local.app" ]; then
        echo -e "${YELLOW}Environment not built. Running build script...${NC}"
        ./scripts/build_devices.sh
    else
        echo -e "${GREEN}Build check passed${NC}"
    fi
}

# Create configuration files
create_config() {
    echo -e "${BLUE}Creating configuration files...${NC}"
    
    mkdir -p config
    
    # System configuration
    cat > config/sys.config << EOF
[
  {hyperbeam_local, [
    {http_port, ${HTTP_PORT}},
    {websocket_port, ${WEBSOCKET_PORT}},
    {max_message_history, 1000}
  ]},
  {kernel, [
    {logger_level, info},
    {logger, [
      {handler, default, logger_std_h,
       #{config => #{type => standard_io},
         formatter => {logger_formatter,
                      #{single_line => true,
                        time_offset => "Z"}}}}
    ]}
  ]}
].
EOF

    # VM arguments
    cat > config/vm.args << EOF
+K true
+A30
+P 1048576
-name ${NODE_NAME}@127.0.0.1
-setcookie hyperbeam_local_cookie
-kernel inet_dist_listen_min 9100
-kernel inet_dist_listen_max 9155
EOF

    echo -e "${GREEN}Configuration files created${NC}"
}

# Start the node
start_node() {
    echo -e "${BLUE}Starting HyperBeam Local node...${NC}"
    
    cd hyperbeam-local
    
    # Export ERL_LIBS to include device modules
    export ERL_LIBS="../devices:$ERL_LIBS"
    
    # Start the node
    echo -e "${GREEN}HyperBeam Local Testing Environment${NC}"
    echo -e "${GREEN}====================================${NC}"
    echo -e "${BLUE}HTTP API: http://localhost:${HTTP_PORT}${NC}"
    echo -e "${BLUE}WebSocket: ws://localhost:${WEBSOCKET_PORT}${NC}"
    echo -e "${BLUE}Node: ${NODE_NAME}@127.0.0.1${NC}"
    echo ""
    echo -e "${YELLOW}Available API endpoints:${NC}"
    echo -e "  GET  /api/devices           - List all devices"
    echo -e "  GET  /api/devices/{name}    - Get device info"
    echo -e "  POST /api/message           - Send message to device"
    echo -e "  GET  /api/processes         - List all processes"
    echo -e "  POST /api/processes         - Create new process"
    echo -e "  POST /api/processes/{id}/messages - Send message to process"
    echo -e "  GET  /api/debug/system/status     - System status"
    echo -e "  GET  /api/debug/messages/recent   - Recent messages"
    echo ""
    echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
    echo ""
    
    # Start with shell
    rebar3 shell --config ../config/sys.config --name hyperbeam_local@127.0.0.1 --setcookie hyperbeam_local_cookie
}

# Health check function
health_check() {
    echo -e "${BLUE}Running health check...${NC}"
    
    sleep 5  # Give the server time to start
    
    if curl -s "http://localhost:${HTTP_PORT}/api/debug/system/status" > /dev/null; then
        echo -e "${GREEN}Health check passed - Server is responding${NC}"
    else
        echo -e "${RED}Health check failed - Server not responding${NC}"
    fi
}

# Cleanup function
cleanup() {
    echo -e "${YELLOW}Shutting down HyperBeam Local Testing Environment...${NC}"
    
    # Kill any background processes
    jobs -p | xargs -r kill
    
    echo -e "${GREEN}Cleanup complete${NC}"
    exit 0
}

# Signal handlers
trap cleanup SIGINT SIGTERM

# Main execution
main() {
    echo -e "${GREEN}=== HyperBeam Local Testing Environment Startup ===${NC}"
    
    # Run startup checks and configuration
    check_build
    create_config
    
    # Start the node (this will block)
    start_node
}

# Check for command line arguments
case "${1:-}" in
    --health-check)
        health_check
        exit 0
        ;;
    --help|-h)
        echo "HyperBeam Local Testing Environment Startup Script"
        echo ""
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --health-check    Run health check against running server"
        echo "  --help, -h        Show this help message"
        echo ""
        echo "Environment variables:"
        echo "  HTTP_PORT         HTTP API port (default: 8080)"
        echo "  WEBSOCKET_PORT    WebSocket port (default: 8081)"
        echo "  NODE_NAME         Erlang node name (default: hyperbeam_local)"
        exit 0
        ;;
    "")
        # No arguments, run main
        main
        ;;
    *)
        echo -e "${RED}Unknown option: $1${NC}"
        echo "Use --help for usage information"
        exit 1
        ;;
esac