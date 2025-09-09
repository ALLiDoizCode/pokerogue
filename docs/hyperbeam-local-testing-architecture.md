# PokéRogue HyperBeam Local Testing Environment Architecture

## Introduction

This document outlines a comprehensive local testing environment for HyperBeam NIFs (Native Implemented Functions) and processes, enabling development and testing of Erlang/OTP-based devices with Rust NIFs before deployment to the AO network.

**Objective:** Create a complete local development environment that mirrors HyperBeam's production architecture while providing testing capabilities for custom devices and processes.

## High Level Architecture

### Technical Summary

The HyperBeam local testing environment implements a complete Erlang/OTP node with HyperBeam core functionality, integrating Rust NIFs for performance-critical operations and providing local process testing capabilities. This architecture enables developers to build, test, and debug HyperBeam devices locally before deployment, using the same message-passing patterns and device architecture as production HyperBeam nodes.

### Platform and Infrastructure Choice

**Platform:** Local Development (Erlang/OTP + Rust toolchain)
**Key Services:** 
- Erlang/OTP 27 runtime
- HyperBeam core (edge branch)
- Rust toolchain with Rustler
- Local AO process emulation (aolite)
- Development HTTP server for testing

**Development Host Requirements:** 
- Erlang OTP 27+
- Rust toolchain (latest stable)
- Git, rebar3, Node.js (for tooling)

### Repository Structure

**Structure:** Monorepo with specialized HyperBeam testing components
**Monorepo Tool:** npm workspaces + rebar3 for Erlang components
**Package Organization:** 
- `hyperbeam-local/` - HyperBeam node setup
- `devices/` - Custom device implementations  
- `processes/` - AO process definitions
- `tests/` - Integration and device tests
- `examples/` - Reference implementations

## Tech Stack

| Category | Technology | Version | Purpose | Rationale |
|----------|------------|---------|---------|-----------|
| Runtime Platform | Erlang/OTP | 27+ | HyperBeam execution environment | Required by HyperBeam core architecture |
| Build Tool | rebar3 | Latest | Erlang project management | Standard Erlang build toolchain |
| NIF Development | Rust + Rustler | Latest | High-performance device logic | Rust NIFs provide performance with safety |
| HTTP Client | ureq | Latest | HTTP operations in devices | Blocking HTTP client suitable for NIF context |
| Serialization | serde + serde_json | Latest | Data exchange between Erlang/Rust | Standard Rust serialization framework |
| Error Handling | anyhow | Latest | Rust error management | Ergonomic error handling in NIFs |
| Process Testing | aolite | Latest | Local AO process emulation | Lua process testing without network deployment |
| Version Control | Git | Latest | Source control | Standard development workflow |
| Development Server | Custom Erlang HTTP | Built-in | Local testing endpoints | Integrated with HyperBeam message routing |

## Data Models

### HyperBeam Message

**Purpose:** Core communication unit in HyperBeam system

**Key Attributes:**
- id: binary() - Unique message identifier
- data: term() - Message payload (binary or function map)
- target: binary() - Target process or device identifier
- timestamp: integer() - Message creation time
- signature: binary() - Cryptographic signature

```erlang
-record(hb_message, {
    id :: binary(),
    data :: term(),
    target :: binary(),
    timestamp :: integer(),
    signature :: binary()
}).
```

### Device Specification

**Purpose:** Device metadata and routing information

**Key Attributes:**
- name: atom() - Device identifier
- version: binary() - Device version
- module: atom() - Erlang module implementing device
- nif_module: atom() - Associated Rust NIF module (optional)
- routes: list() - Supported message routes

```erlang
-record(device_spec, {
    name :: atom(),
    version :: binary(),
    module :: atom(),
    nif_module :: atom() | undefined,
    routes :: [binary()]
}).
```

## Core Components

### HyperBeam Local Node

**Responsibility:** Main HyperBeam node running locally with full device support

**Key Interfaces:**
- Message routing and processing
- Device registration and management
- HTTP API for external testing
- WebSocket connections for real-time testing

**Dependencies:** Erlang OTP, HyperBeam core modules

**Technology Stack:** Erlang/OTP with cowboy HTTP server, gen_server architecture

### Rust NIF Device Framework

**Responsibility:** Rust-based device implementations with NIF integration

**Key Interfaces:**
- `device_init/1` - Device initialization
- `handle_message/2` - Message processing
- `device_info/0` - Device metadata

**Dependencies:** Rustler, ureq, serde, anyhow

**Technology Stack:** Rust library crates compiled as NIFs

### Local Process Manager

**Responsibility:** AO process lifecycle management and testing

**Key Interfaces:**
- Process spawning and termination
- Message queuing and delivery
- Process state inspection
- Lua code evaluation

**Dependencies:** aolite, HyperBeam message system

**Technology Stack:** Lua 5.3 runtime with coroutine management

### Testing Framework

**Responsibility:** Device and process integration testing

**Key Interfaces:**
- Device test harness
- Message flow testing
- Performance benchmarking
- Mock external services

**Dependencies:** All above components

**Technology Stack:** EUnit (Erlang) + custom test utilities

## HyperBeam Local Development Environment Setup

### Prerequisites Installation

```bash
# Install Erlang/OTP 27
brew install erlang  # macOS
# OR
sudo apt-get install erlang  # Ubuntu

# Install Rust toolchain
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env

# Install rebar3
brew install rebar3  # macOS
# OR follow installation guide for other platforms

# Verify installations
erl -version
rustc --version
rebar3 version
```

### Project Structure

```
pokerogue-hyperbeam-local/
├── hyperbeam-local/
│   ├── src/
│   │   ├── hb_local_app.erl        # Main application
│   │   ├── hb_local_sup.erl        # Supervisor tree
│   │   ├── hb_message_router.erl   # Message routing
│   │   ├── hb_device_registry.erl  # Device management
│   │   └── hb_http_handler.erl     # HTTP API
│   ├── include/
│   │   └── hb_local.hrl            # Header definitions
│   ├── priv/
│   │   └── native/                 # Compiled NIF libraries
│   └── rebar.config                # Erlang build config
├── devices/
│   ├── rust_template_device/       # Rust NIF device template
│   │   ├── src/
│   │   │   └── lib.rs             # Rust NIF implementation
│   │   ├── native/
│   │   │   └── rust_template_nif/  # NIF module
│   │   ├── Cargo.toml             # Rust dependencies
│   │   └── build.rs               # Build script
│   ├── erlang_device_template/     # Pure Erlang device template
│   │   └── src/
│   │       └── erlang_template_device.erl
│   └── examples/
│       ├── roam_device/           # HTTP query device (from tutorial)
│       └── calculation_device/    # CPU-intensive device example
├── processes/
│   ├── examples/
│   │   ├── echo_process.lua       # Simple echo process
│   │   ├── trading_agent.lua      # Trading simulation
│   │   └── data_aggregator.lua    # Data processing process
│   └── tests/
│       └── process_test_suite.lua
├── tests/
│   ├── integration/
│   │   ├── device_tests.erl
│   │   ├── message_flow_tests.erl
│   │   └── nif_performance_tests.erl
│   └── unit/
│       ├── message_router_tests.erl
│       └── device_registry_tests.erl
├── scripts/
│   ├── start_local_node.sh        # Start development environment
│   ├── build_devices.sh           # Compile all devices
│   ├── run_tests.sh              # Execute test suites
│   └── deploy_process.sh         # Deploy process to local node
├── config/
│   ├── sys.config                 # Erlang system configuration
│   └── vm.args                    # Erlang VM arguments
├── docs/
│   ├── device_development.md      # Device development guide
│   ├── process_testing.md         # Process testing guide
│   └── api_reference.md          # HTTP API documentation
└── README.md
```

### Development Commands

```bash
# Initial setup
git clone -b edge https://github.com/permaweb/HyperBEAM.git hyperbeam-core
cd pokerogue-hyperbeam-local
rebar3 deps get
rebar3 compile

# Build all devices (including Rust NIFs)
./scripts/build_devices.sh

# Start local HyperBeam node
./scripts/start_local_node.sh

# In another terminal - run integration tests
./scripts/run_tests.sh

# Deploy a process for testing
./scripts/deploy_process.sh processes/examples/echo_process.lua
```

## Device Development Workflow

### Creating a Rust NIF Device

1. **Create device structure:**
```bash
mkdir devices/my_custom_device
cd devices/my_custom_device
cargo init --lib
```

2. **Configure Cargo.toml:**
```toml
[lib]
name = "my_custom_device_nif"
crate-type = ["cdylib"]

[dependencies]
rustler = "0.32"
anyhow = "1.0"
ureq = "2.9"
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
```

3. **Implement NIF functions:**
```rust
use rustler::{Env, Term, NifResult, Encoder, Error, schedule::SchedulerFlags};
use std::thread;

#[rustler::nif(schedule = "DirtyCpu")]
fn process_heavy_computation(data: String) -> NifResult<String> {
    // Simulate heavy computation
    thread::sleep(std::time::Duration::from_millis(100));
    
    // Process data and return result
    Ok(format!("Processed: {}", data))
}

#[rustler::nif(schedule = "DirtyCpu")]
fn fetch_external_data(url: String) -> NifResult<String> {
    match ureq::get(&url).call() {
        Ok(response) => {
            let body = response.into_string()
                .map_err(|_| Error::Term(Box::new("Failed to read response")))?;
            Ok(body)
        }
        Err(e) => Err(Error::Term(Box::new(format!("HTTP error: {}", e)))),
    }
}

rustler::init!("my_custom_device_nif", [process_heavy_computation, fetch_external_data]);
```

4. **Create Erlang device module:**
```erlang
-module(my_custom_device).
-behaviour(hb_device).

-export([init/1, handle_message/2, device_info/0]).

init(_Args) ->
    case erlang:load_nif("./priv/native/my_custom_device_nif", 0) of
        ok -> {ok, #{}};
        Error -> {error, Error}
    end.

handle_message(Message, State) ->
    case Message#hb_message.data of
        {compute, Data} ->
            Result = process_heavy_computation(binary_to_list(Data)),
            Response = Message#hb_message{data = {result, list_to_binary(Result)}},
            {reply, Response, State};
        {fetch, Url} ->
            Result = fetch_external_data(binary_to_list(Url)),
            Response = Message#hb_message{data = {data, list_to_binary(Result)}},
            {reply, Response, State};
        _ ->
            {noreply, State}
    end.

device_info() ->
    #{
        name => my_custom_device,
        version => <<"1.0.0">>,
        description => <<"Custom device with Rust NIF support">>,
        routes => [<<"/compute">>, <<"/fetch">>]
    }.

%% NIF function declarations
process_heavy_computation(_Data) ->
    erlang:nif_error(nif_not_loaded).

fetch_external_data(_Url) ->
    erlang:nif_error(nif_not_loaded).
```

## Testing Framework

### Device Integration Tests

```erlang
-module(device_integration_tests).
-include_lib("eunit/include/eunit.hrl").

custom_device_test() ->
    % Start local node
    {ok, _} = hb_local_app:start(normal, []),
    
    % Register device
    ok = hb_device_registry:register_device(my_custom_device),
    
    % Create test message
    Message = #hb_message{
        id = crypto:strong_rand_bytes(16),
        data = {compute, <<"test data">>},
        target = <<"my_custom_device">>,
        timestamp = os:system_time(millisecond)
    },
    
    % Send message and verify response
    {ok, Response} = hb_message_router:route_message(Message),
    ?assertMatch({result, <<"Processed: test data">>}, Response#hb_message.data).
```

### Process Testing

```lua
-- echo_process.lua
local json = require("json")

Handlers.add(
    "Echo",
    Handlers.utils.hasMatchingTag("Action", "Echo"),
    function(msg)
        local data = msg.Data or "No data provided"
        ao.send({
            Target = msg.From,
            Action = "EchoResponse",
            Data = "Echo: " .. data
        })
    end
)
```

## API Interface

### HTTP Testing API

```http
# Send message to device
POST /api/message
Content-Type: application/json

{
    "target": "my_custom_device",
    "data": {
        "compute": "sample data"
    }
}

# Get device info
GET /api/devices/my_custom_device

# List all registered devices
GET /api/devices

# Deploy process
POST /api/processes
Content-Type: application/json

{
    "code": "-- Lua process code here",
    "name": "test_process"
}

# Send message to process
POST /api/processes/{process_id}/messages
Content-Type: application/json

{
    "action": "Echo",
    "data": "Hello, Process!"
}
```

## Performance Testing

### NIF Performance Benchmarks

```erlang
-module(nif_benchmarks).

benchmark_computation() ->
    Data = crypto:strong_rand_bytes(1024),
    
    % Benchmark NIF implementation
    {Time1, _} = timer:tc(fun() ->
        [my_custom_device:process_heavy_computation(Data) || _ <- lists:seq(1, 1000)]
    end),
    
    % Compare with pure Erlang implementation
    {Time2, _} = timer:tc(fun() ->
        [pure_erlang_computation(Data) || _ <- lists:seq(1, 1000)]
    end),
    
    io:format("NIF: ~p microseconds~n", [Time1]),
    io:format("Erlang: ~p microseconds~n", [Time2]),
    io:format("Speedup: ~p~n", [Time2 / Time1]).
```

## Monitoring and Debugging

### Development Tools

1. **Observer Tool:** Built-in Erlang system monitoring
```bash
rebar3 shell
# In Erlang shell:
observer:start().
```

2. **Message Tracing:**
```erlang
% Enable message tracing
dbg:tracer(),
dbg:p(all, [m]),
dbg:tp(hb_message_router, route_message, []).
```

3. **Device State Inspection:**
```http
GET /api/debug/devices/{device_name}/state
GET /api/debug/messages/recent
GET /api/debug/performance/stats
```

## Security Considerations

### Local Development Security

- **NIF Safety:** All Rust NIFs use safe Rust patterns and proper error handling
- **Process Isolation:** Lua processes run in sandboxed environments
- **Resource Limits:** CPU and memory limits for device operations
- **Input Validation:** All external input validated before processing

## Next Steps

1. **Complete Initial Setup:**
   - Clone and configure HyperBeam core
   - Set up development environment
   - Create basic device templates

2. **Implement Core Testing Infrastructure:**
   - Message routing system
   - Device registry
   - HTTP API for testing

3. **Develop Example Devices:**
   - Port the Roam device from the tutorial
   - Create calculation-heavy device
   - Implement external API device

4. **Process Integration:**
   - Integrate aolite for process testing
   - Create process deployment workflow
   - Implement message passing between devices and processes

5. **Testing and Documentation:**
   - Comprehensive test suites
   - Performance benchmarks
   - Developer documentation and guides

This architecture provides a complete local development and testing environment for HyperBeam devices and processes, enabling rapid development and testing before deployment to the AO network.