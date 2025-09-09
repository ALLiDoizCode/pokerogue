# HyperBeam Local Testing Environment - User Guide

## Overview

This guide provides comprehensive instructions for using the HyperBeam Local Testing Environment to develop, test, and debug NIFs (Native Implemented Functions) and processes locally before deploying to the AO network.

## Quick Start

### 1. Build the Environment

```bash
# Build Rust NIFs and compile Erlang application
./scripts/build_devices.sh
```

### 2. Test the Application

```bash
# Test that everything compiles and starts correctly
cd hyperbeam-local
erl -pa _build/default/lib/*/ebin -eval "application:ensure_all_started(hyperbeam_local), timer:sleep(2000), application:stop(hyperbeam_local), init:stop()" -noshell
```

Expected output: Clean startup and shutdown with dependency stop messages.

### 3. Interactive Development

```bash
# Start interactive Erlang shell with HyperBeam loaded
cd hyperbeam-local
erl -pa _build/default/lib/*/ebin
```

In the Erlang shell:
```erlang
% Start the application
application:ensure_all_started(hyperbeam_local).

% Test basic functionality
hb_message_router:route_message(#{<<"target">> => <<"rust_template_device">>, <<"data">> => <<"test">>}).

% Check running processes
hb_process_manager:list_processes().

% Stop the application
application:stop(hyperbeam_local).
```

## Architecture Components

### Core Modules

- **hb_local_app**: Main application with HTTP server setup
- **hb_local_sup**: Supervisor managing all components
- **hb_message_router**: Routes messages between devices and processes
- **hb_device_registry**: Manages device lifecycle and registration
- **hb_process_manager**: Handles AO process simulation and management
- **hb_http_handler**: HTTP API for external interaction

### Device Development

The template Rust device (`devices/rust_template_device/`) provides three example functions:
- `hello_world()`: Returns a greeting string
- `add_numbers(a, b)`: Adds two integers
- `echo_string(input)`: Echoes back input with prefix

### HTTP API Endpoints

All endpoints return JSON responses.

#### System Endpoints
- `GET /api/debug/system/status`: System health and status
- `GET /api/devices`: List registered devices
- `GET /api/processes`: List running processes

#### Messaging Endpoints
- `POST /api/message`: Send message to device or process
  ```json
  {
    "target": "device_name_or_process_id",
    "data": "message_content", 
    "action": "optional_action"
  }
  ```

#### Process Management
- `POST /api/processes`: Spawn new AO process
  ```json
  {
    "name": "process_name",
    "code": "lua_code_string"
  }
  ```
- `GET /api/processes/{id}`: Get process state
- `DELETE /api/processes/{id}`: Terminate process

## Testing Workflows

### Device Testing

1. **Modify Rust Code**: Edit `devices/rust_template_device/src/lib.rs`
2. **Rebuild**: Run `./scripts/build_devices.sh`
3. **Test Functions**: Use the HTTP API or Erlang shell to call functions

### Process Testing

1. **Create Lua Process**: Use the `/api/processes` endpoint
2. **Send Messages**: Use `/api/message` with the process ID
3. **Monitor State**: Check process state with `/api/processes/{id}`

### Message Flow Testing

1. **Direct Device Messages**: Send to device names (e.g., "rust_template_device")
2. **Process Messages**: Send to process IDs (generated UUIDs)
3. **System Messages**: Use special targets like "ping" for health checks

## Development Patterns

### Adding New Rust NIFs

1. **Create Function**: Add new `#[rustler::nif]` functions to `lib.rs`
2. **Update Init**: Add function to `rustler::init!` macro
3. **Create Wrapper**: Add Erlang wrapper in corresponding device module
4. **Register Device**: Ensure device is registered in the device registry
5. **Test**: Use HTTP API or shell to test new functionality

### Creating Custom Devices

1. **Copy Template**: Use `rust_template_device` as starting point
2. **Implement Behavior**: Implement `hb_device` behavior in Erlang module
3. **Build Configuration**: Update `Cargo.toml` for dependencies
4. **Integration**: Register device in the device registry

### Process Development

1. **Lua Code**: Write AO-compatible Lua handlers
2. **Testing**: Use the process manager to spawn and test locally
3. **Message Handling**: Test message patterns before AO deployment

## Troubleshooting

### Common Issues

1. **Rust Version Conflicts**: Ensure Rust 1.82+ is installed
   ```bash
   rustup update
   ```

2. **NIF Loading Errors**: Check that `.dylib` files are in `priv/` directory
   ```bash
   ls -la hyperbeam-local/priv/
   ```

3. **Application Won't Start**: Check for dependency issues
   ```bash
   cd hyperbeam-local
   rebar3 compile
   ```

4. **HTTP API Not Responding**: Verify Cowboy is starting correctly in logs

### Debugging Commands

```bash
# Check compilation errors
cd hyperbeam-local && rebar3 compile

# Verify NIFs are built
ls -la devices/rust_template_device/target/release/
ls -la hyperbeam-local/priv/

# Test minimal startup
erl -pa hyperbeam-local/_build/default/lib/*/ebin -eval "application:ensure_all_started(hyperbeam_local)" -noshell

# Interactive debugging
cd hyperbeam-local && erl -pa _build/default/lib/*/ebin
```

## File Structure

```
hyperbeam-local/           # Main Erlang application
├── src/                   # Erlang source modules
├── include/               # Header files
├── priv/                  # Native libraries (.dylib)
└── _build/               # Compiled artifacts

devices/                   # Device implementations
└── rust_template_device/ # Example Rust NIF device
    ├── Cargo.toml
    └── src/lib.rs

scripts/                   # Build and utility scripts
├── build_devices.sh      # Main build script
├── start_simple.sh       # Interactive startup
├── start_daemon.sh       # Background startup
└── test_hyperbeam_api.sh # API testing

docs/                      # Documentation
├── hyperbeam-local-testing-architecture.md
└── hyperbeam-testing-guide.md  # This file
```

## Next Steps

After successfully running the local testing environment:

1. **Develop Custom Devices**: Create domain-specific Rust NIFs
2. **Test Process Interactions**: Simulate multi-process AO scenarios  
3. **Performance Testing**: Benchmark message throughput and latency
4. **AO Integration**: Deploy tested components to the AO network
5. **Production Setup**: Use official HyperBeam deployment for production

## References

- [HyperBeam Documentation](https://hyperbeam.arweave.net/build/introduction/what-is-hyperbeam.html)
- [Rust HyperBeam Tutorial](https://blog.decent.land/rust-hb-tutorial/)
- [AO Documentation](https://ao.arweave.dev/)
- [Rustler Documentation](https://docs.rs/rustler/latest/rustler/)
- [Cowboy HTTP Server](https://ninenines.eu/docs/en/cowboy/2.9/guide/)

This local testing environment provides a complete development workflow for HyperBeam applications without requiring AO network deployment during development.