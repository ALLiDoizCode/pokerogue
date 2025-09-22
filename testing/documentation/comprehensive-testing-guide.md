# Comprehensive Testing Guide

## Overview

This guide documents the complete testing strategy and validation framework for the PokéRogue TypeScript to AO migration, ensuring 100% functional parity and performance excellence.

## Testing Framework Architecture

### 1. TypeScript Reference Preservation

**Purpose**: Maintain isolated TypeScript implementation for parity validation

**Components**:
- Complete source code preservation in `/typescript-reference/`
- Independent build system with isolated dependencies
- Integrity validation with SHA-256 checksums (491 files)
- Automated scripts for build, test, and deployment

**Usage**:
```bash
# Validate reference integrity
cd typescript-reference && ./scripts/validate-integrity.sh --validate

# Build reference implementation  
./scripts/build-reference.sh

# Run reference tests
./scripts/run-tests.sh
```

### 2. Automated Parity Test Framework

**Purpose**: Cross-implementation validation ensuring identical behavior

**Components**:
- `testing/parity/parity-test-framework.js` - Core parity testing engine
- `testing/parity/scenario-generator.js` - Comprehensive test scenario generation
- `scripts/run-parity-tests.js` - Test execution script

**Test Categories**:
- Battle damage calculations with type effectiveness
- Pokemon stat calculations with nature modifiers
- Status effect mechanics and duration
- Evolution triggers and conditions
- Capture probability calculations

**Usage**:
```bash
npm run test:parity
```

**Validation Criteria**:
- 100% functional equivalence required
- Tolerance-based comparison for numerical values
- Statistical analysis for RNG-dependent mechanics

### 3. Enhanced aolite Unit Testing Framework

**Purpose**: Comprehensive process validation with mock AO environment

**Components**:
- `testing/aolite/enhanced-test-framework.lua` - Advanced testing capabilities
- `testing/aolite/test-generators.lua` - Automated test generation
- Mock AO environment with deterministic RNG

**Features**:
- Performance profiling and execution time tracking
- Test coverage reporting and metrics collection
- Automated test generation for game mechanics
- Mock AO globals (ao, Handlers, json, crypto)

**Usage**:
```bash
npm run test:aolite
```

### 4. aos-local Integration Testing Framework

**Purpose**: Multi-process deployment validation and message flow testing

**Components**:
- `testing/aos-local/integration-test-framework.js` - Integration testing engine
- End-to-end workflow testing
- Process health monitoring

**Test Scenarios**:
- Coordinator to data process message flow
- Complete battle workflow simulation
- Multi-process deployment validation
- Process communication latency measurement

**Usage**:
```bash
npm run test:aos-local
```

### 5. Property-Based Testing & Statistical Validation

**Purpose**: Statistical consistency validation for RNG-dependent systems

**Components**:
- `testing/statistical/property-based-testing.js` - Statistical framework
- Large-scale simulation testing (10,000+ iterations)
- Confidence interval analysis

**Statistical Tests**:
- Critical hit rate validation (1/24 base rate)
- Damage variance distribution (85-100% range)
- Capture probability calculations
- Status effect application rates

**Usage**:
```bash
npm run test:statistical
```

**Tolerance Levels**:
- Probability-based outcomes: ±2%
- Damage variance calculations: ±5%
- Critical hit rates: ±1%

### 6. Performance Benchmarking & Comparison

**Purpose**: Execution time and resource usage comparison

**Components**:
- `testing/performance/benchmark-framework.js` - Performance comparison
- TypeScript vs AO Lua benchmarking
- Memory usage and throughput analysis

**Benchmark Categories**:
- Pokemon stat calculation performance
- Battle damage calculation speed
- Type effectiveness lookup performance
- Data query execution time

**Usage**:
```bash
npm run test:performance
```

## Continuous Integration

**Workflow**: `.github/workflows/parity-validation.yml`

**Validation Steps**:
1. TypeScript reference integrity check
2. Enhanced aolite unit tests
3. aos-local integration tests
4. Statistical validation
5. Parity testing
6. Performance benchmarking
7. AO sandbox compliance
8. Process size validation

**Deployment Gates**:
- All parity tests must pass (0 failures)
- Performance must meet or exceed TypeScript
- Statistical validation within tolerance
- Process size under 500KB limit

## Test Execution Commands

### Individual Test Suites
```bash
npm run test:aolite           # aolite unit tests
npm run test:aos-local        # Integration tests
npm run test:parity           # Parity validation
npm run test:statistical      # Statistical validation
npm run test:performance      # Performance benchmarks
```

### Comprehensive Testing
```bash
npm run test:all              # All testing frameworks
```

### Validation Commands
```bash
npm run validate:size         # Process size constraints
npm run lint:ao-sandbox       # AO compliance validation
```

## Report Generation

**Locations**: `testing/reports/`

**Report Types**:
- Parity validation reports (JSON + HTML)
- Statistical analysis reports
- Performance benchmark reports
- Integration test results
- Coverage reports

**Report Features**:
- Detailed diff analysis for failures
- Statistical confidence intervals
- Performance comparison charts
- Historical trend analysis

## Testing Standards

### Parity Testing Requirements
- **100% functional equivalence** between TypeScript and AO implementations
- **Zero tolerance** for behavioral deviations
- Comprehensive coverage of all game mechanics
- Statistical validation for probability-based systems

### Performance Requirements
- AO processes must **meet or exceed** TypeScript performance
- Sub-5-second execution for critical operations
- Memory usage optimization
- Throughput maintenance under load

### Statistical Requirements
- **95% confidence intervals** for all statistical tests
- **Minimum 10,000 iterations** for probability validation
- **±2% tolerance** for critical probability calculations
- **±5% tolerance** for damage variance

### Quality Gates
- All unit tests pass (100% success rate)
- All integration tests pass
- All parity tests pass
- Statistical validation within tolerance
- Performance meets requirements
- AO compliance verification
- Process size under 500KB

## Troubleshooting

### Common Issues

**Parity Test Failures**:
1. Check TypeScript reference integrity
2. Verify AO process compliance
3. Review tolerance settings
4. Examine detailed diff reports

**Statistical Test Failures**:
1. Increase iteration count
2. Check RNG seeding
3. Verify expected distributions
4. Review confidence intervals

**Performance Issues**:
1. Profile individual functions
2. Check memory usage patterns
3. Optimize critical paths
4. Validate benchmark scenarios

### Debug Commands
```bash
# Validate TypeScript reference
cd typescript-reference && ./scripts/validate-integrity.sh --validate

# Check process sizes
npm run validate:size

# Verify AO compliance
npm run lint:ao-sandbox
```

## Best Practices

### Test Development
1. **Start with unit tests** using aolite framework
2. **Add integration tests** for multi-process scenarios
3. **Include parity tests** for critical functionality
4. **Validate statistics** for RNG-dependent features
5. **Benchmark performance** for optimization targets

### Maintenance
1. **Regular reference updates** with integrity validation
2. **Continuous statistical monitoring** for drift detection
3. **Performance regression testing** for optimization
4. **Comprehensive reporting** for stakeholder visibility

### Quality Assurance
1. **All tests must pass** before deployment
2. **Statistical significance** required for probability tests
3. **Performance requirements** must be met
4. **Documentation updates** with code changes

## Conclusion

This comprehensive testing framework ensures **100% functional parity** between TypeScript reference and AO implementations while maintaining **performance excellence** and **statistical accuracy**. The multi-layered validation approach provides confidence in the migration quality and long-term maintainability.