# TypeScript Reference Implementation

This directory contains the preserved TypeScript reference implementation for parity testing validation.

## Purpose

The TypeScript reference serves as the ground truth for validating the stateless AO implementation. All game mechanics, calculations, and behaviors in the AO implementation must maintain 100% functional equivalence with this reference.

## Architecture

### Directory Structure
```
typescript-reference/
├── src/                    # Complete TypeScript source code
├── scripts/               # Build and execution scripts
│   ├── build-reference.sh # TypeScript compilation
│   ├── run-tests.sh      # Test execution
│   └── start-game.sh     # Development server
├── package.json          # Isolated dependencies
├── tsconfig.json         # TypeScript configuration
├── vite.config.ts        # Build configuration
└── README.md            # This documentation
```

### Key Components

**Game Logic Modules:**
- Battle system and damage calculations
- Pokemon mechanics and stat calculations  
- Evolution and progression systems
- Status effects and condition logic
- RNG and probability systems

**Core Dependencies:**
- Phaser 3 for game engine
- TypeScript for type safety
- Vite for build system
- Vitest for testing framework

## Build Scripts

### Build Reference Implementation
```bash
./scripts/build-reference.sh
```
Compiles TypeScript and builds the reference implementation for testing.

### Run Reference Tests  
```bash
./scripts/run-tests.sh
```
Executes the reference test suite for validation.

### Start Game Instance
```bash
./scripts/start-game.sh
```
Launches development server at http://localhost:5173 for manual testing.

## Version Control Strategy

### Reference Updates
- TypeScript reference is updated only when main implementation changes
- All updates require checksum validation and documentation
- Reference changes trigger automatic parity test execution

### Integrity Validation
- SHA-256 checksums maintained for all critical game logic files
- Automated integrity checks before parity test execution
- Version history preserved for reference rollback capabilities

### Change Management
- Reference modifications require explicit approval workflow
- All changes documented with rationale and impact analysis
- Automated backup creation before reference updates

## Parity Testing Integration

The TypeScript reference integrates with the parity testing framework:

1. **Test Scenario Execution**: Identical scenarios run on both implementations
2. **Result Comparison**: Automated diff analysis for validation
3. **Statistical Analysis**: RNG-dependent mechanics validated for consistency
4. **Performance Benchmarking**: Execution time and resource usage comparison

## Development Workflow

1. Reference implementation remains stable and isolated
2. AO implementation changes validated against reference
3. Parity tests ensure 100% functional equivalence
4. Performance benchmarks ensure AO meets/exceeds reference performance

## Security Considerations

- Isolated dependency management prevents contamination
- Read-only reference implementation during testing
- Secure checksum validation for integrity assurance
- Access control for reference modifications with audit trails