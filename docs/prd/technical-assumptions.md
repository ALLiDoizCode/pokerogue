# Technical Assumptions

## Repository Structure: Monorepo
Single repository approach for coordinated stateless process development:
- `/processes/` - 26 stateless Lua processes (battle-engine.lua, pokemon-species-db.lua, etc.)
- `/testing/` - Comprehensive TDD framework (aolite unit tests, aos-local integration, parity validation)
- `/tools/` - AO sandbox validation, process size monitoring, performance testing
- `/fixtures/` - Test data and golden master outputs for parity validation
- `/typescript-reference/` - Current implementation for parity testing

## Service Architecture
**26-Process Stateless Architecture with Async Coordination**
- Data processes provide pure reference data (pokemon-species-db, moves-database, items-database, abilities-database)
- Logic processes perform pure computation (battle-engine, evolution-engine, capture-engine, status-effects-engine)
- Coordinator process orchestrates complex multi-step async workflows
- Client-side GameState persistence eliminates persistent state within processes
- Fixed process topology with predefined process addresses

**Rationale:** Stateless process architecture enables infinite horizontal scalability while maintaining deterministic behavior and eliminating single points of failure through pure functional design.

## Testing Requirements: Migration Parity Validation
**Critical Requirement:** 100% functional parity with existing TypeScript implementation
- **Parity Testing:** Automated comparison of TypeScript vs Rust device outcomes for identical inputs
- **Device Testing:** Unit testing of individual Rust WASM devices with TypeScript reference validation
- **Integration Testing:** AO process coordination with inter-process communication and external data fetching
- **End-to-End Testing:** Complete game scenarios comparing TypeScript vs AO process implementations

## Additional Technical Assumptions and Requests

**Core Architecture:**
- **AO Process Architecture:** 26 stateless processes with ECS world state and coordinator-based orchestration
- **Rust WASM Devices:** Stateless, type-safe computational units for game logic (~pokemon-stats@1.0, ~battle-engine@1.0, etc.)
- **External Data Storage:** Arweave transactions for Pokemon species, moves, and items databases (2MB+ data moved external)
- **Process Communication:** AO message routing between processes based on action type

**Migration Approach:**
- **TypeScript Reference:** Preserve existing implementation for parity validation
- **Rust Device Logic:** Migrate battle calculations, stat computations, evolution logic to type-safe Rust
- **External Data Migration:** Move static game data to Arweave for bundle size optimization
- **State Synchronization:** ECS entity state managed through stateless AO process coordination

**Performance Requirements:**
- **Bundle Size:** <500KB per AO process through external data references  
- **Parity Validation:** Zero functional differences between TypeScript and Rust implementations
- **Response Time:** Battle turns complete within existing game performance expectations
