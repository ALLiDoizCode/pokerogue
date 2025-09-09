#!/bin/bash

# HyperBeam Local Testing Environment - Device Build Script
set -e

echo "Building HyperBeam Local Testing Environment devices..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if required tools are installed
check_requirements() {
    echo -e "${BLUE}Checking requirements...${NC}"
    
    if ! command -v rustc &> /dev/null; then
        echo -e "${RED}Rust is not installed. Please install Rust: https://rustup.rs/${NC}"
        exit 1
    fi
    
    if ! command -v rebar3 &> /dev/null; then
        echo -e "${RED}rebar3 is not installed. Please install rebar3${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Requirements check passed${NC}"
}

# Build Rust NIF devices
build_rust_devices() {
    echo -e "${BLUE}Building Rust NIF devices...${NC}"
    
    for device_dir in devices/*/; do
        if [[ -f "${device_dir}Cargo.toml" ]]; then
            device_name=$(basename "$device_dir")
            echo -e "${YELLOW}Building Rust device: ${device_name}${NC}"
            
            cd "$device_dir"
            
            # Build the Rust NIF
            cargo build --release
            
            # Copy the compiled NIF to the correct location
            target_dir="target/release"
            if [[ "$OSTYPE" == "darwin"* ]]; then
                nif_ext=".dylib"
                src_prefix="lib"
            else
                nif_ext=".so"
                src_prefix="lib"
            fi
            
            # The actual compiled library name
            compiled_name="${src_prefix}${device_name}_nif${nif_ext}"
            # The name we want in the destination (without lib prefix)
            dest_name="${device_name}_nif${nif_ext}"
            
            src_nif="${target_dir}/${compiled_name}"
            dest_dir="../../hyperbeam-local/priv/native"
            
            mkdir -p "$dest_dir"
            
            # Also check for cdylib format without lib prefix
            alt_src_nif="${target_dir}/${device_name}_nif${nif_ext}"
            
            if [[ -f "$src_nif" ]]; then
                cp "$src_nif" "${dest_dir}/${dest_name}"
                echo -e "${GREEN}  ✓ NIF compiled and copied: ${dest_name}${NC}"
            elif [[ -f "$alt_src_nif" ]]; then
                cp "$alt_src_nif" "${dest_dir}/${dest_name}"
                echo -e "${GREEN}  ✓ NIF compiled and copied: ${dest_name}${NC}"
            else
                echo -e "${RED}  ✗ Failed to find compiled NIF at: ${src_nif} or ${alt_src_nif}${NC}"
                echo -e "${YELLOW}  Available files in ${target_dir}:${NC}"
                ls -la "$target_dir" || true
            fi
            
            cd - > /dev/null
        fi
    done
}

# Build Erlang components
build_erlang_components() {
    echo -e "${BLUE}Building Erlang components...${NC}"
    
    cd hyperbeam-local
    
    # Get dependencies
    echo -e "${YELLOW}Getting dependencies...${NC}"
    rebar3 deps get
    
    # Compile the project
    echo -e "${YELLOW}Compiling Erlang code...${NC}"
    rebar3 compile
    
    cd - > /dev/null
    
    echo -e "${GREEN}Erlang components built successfully${NC}"
}

# Copy device Erlang modules to the hyperbeam-local source
copy_device_modules() {
    echo -e "${BLUE}Copying device modules...${NC}"
    
    for device_dir in devices/*/; do
        if [[ -d "${device_dir}src" ]]; then
            device_name=$(basename "$device_dir")
            echo -e "${YELLOW}Copying device modules for: ${device_name}${NC}"
            
            for erl_file in "${device_dir}src"/*.erl; do
                if [[ -f "$erl_file" ]]; then
                    cp "$erl_file" "hyperbeam-local/src/"
                    echo -e "${GREEN}  ✓ Copied: $(basename "$erl_file")${NC}"
                fi
            done
        fi
    done
}

# Main build process
main() {
    echo -e "${GREEN}=== HyperBeam Local Testing Environment Build ===${NC}"
    
    check_requirements
    build_rust_devices
    copy_device_modules
    build_erlang_components
    
    echo -e "${GREEN}=== Build Complete ===${NC}"
    echo -e "${BLUE}To start the environment, run: ./scripts/start_local_node.sh${NC}"
}

# Run main function
main "$@"