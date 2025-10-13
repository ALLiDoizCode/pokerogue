# Epic 17: Trainer & AI Systems

**Status**: COMPLETE - All existing AI systems migrated

Migrate AI battle decision making systems while maintaining identical behavioral patterns and decision-making algorithms.

**Completion Summary**:
- ✅ Stories 17.1-17.2: Successfully migrated ALL existing AI behavior from TypeScript
- ❌ Stories 17.3-17.8: Removed from epic - features do not exist in TypeScript reference implementation

**Note**: Original epic scope included features that don't exist in PokéRogue (trainer item usage, strategy adaptation, difficulty scaling, personalities, party generation, NPC interactions). These would require new feature development, not migration.

## Story 17.1: AI Move Selection Core Implementation
As a **AI move selection engineer**,
I want **core AI move selection algorithms implemented in stateless AO process**,
so that **AI move evaluation pipeline is functional with basic type effectiveness**.

### Acceptance Criteria
1. Three AI types implemented: RANDOM, SMART_RANDOM, SMART (9-stage evaluation pipeline)
2. Move queue processing with virtual move detection (isVirtual checks)
3. Usability filtering (PP checks, disabled moves, restrictions)
4. Encore forced move detection and single-move shortcut logic
5. Basic KO move detection (damage >= opponent.hp threshold)
6. Move benefit scoring with simplified type effectiveness (1.0 default)
7. Move pool sorting and probabilistic AI selection algorithms
8. Struggle fallback for no usable moves
9. ADP v1.0 compliant with 5+ handlers (evaluate-move-selection, calculate-move-benefit, detect-ko-moves, health-check, info)
10. AO compliance validation passes (100% compliance)
11. Process size under 100KB (target: 40-60KB)

### Out of Scope (Deferred to 17.1a-17.1c)
- Full type effectiveness matrix (18×18 type chart)
- Complete damage calculation formulas
- Complex target selection logic
- Comprehensive test suites (40+ unit, 15+ integration, 50+ parity tests)

## Story 17.1a: AI Move Selection Type System Enhancement
As a **AI move selection engineer**,
I want **full type effectiveness matrix and STAB calculations integrated**,
so that **AI move selection evaluates type matchups identically to TypeScript**.

### Acceptance Criteria
1. 18×18 type effectiveness matrix embedded (324 entries from src/data/type.ts)
2. Type damage multipliers: IMMUNE=0, EIGHTH=0.125, QUARTER=0.25, HALF=0.5, NORMAL=1, DOUBLE=2, QUADRUPLE=4, OCTUPLE=8
3. Dual-type target effectiveness calculation (multiply individual type multipliers)
4. STAB (Same-Type Attack Bonus) calculation: 1.5× for matching types, 1.0× otherwise
5. Ability-modified effectiveness (Levitate, Flash Fire, Volt Absorb, etc.)
6. Type effectiveness integration with move benefit scoring
7. Unit tests for type effectiveness calculations (15+ tests)
8. Parity tests vs TypeScript type system (20+ scenarios)

## Story 17.1b: AI Move Selection Damage Calculation
As a **AI move selection engineer**,
I want **complete damage calculation formulas for KO detection**,
so that **AI accurately predicts which moves can KO opponents**.

### Acceptance Criteria
1. Base damage formula implementation: `((2 * Level / 5 + 2) * Power * (Atk / Def) / 50) + 2`
2. Damage modifiers: STAB, type effectiveness, critical hits, random variance
3. Stat-based damage calculation (Attack/Defense or SpAtk/SpDef based on move category)
4. Critical hit detection: crit-only moves, Laser Focus tag, critical hit rates
5. Special move conditions: Sucker Punch, Upper Hand, Thunderclap priority checks
6. Move condition checking (applyConditions equivalent)
7. Ability interactions affecting damage (Thick Fat, Filter, Solid Rock, etc.)
8. Weather/terrain damage modifiers
9. KO detection accuracy validation (unit tests: 12+ scenarios)
10. Parity tests vs TypeScript damage calculations (15+ scenarios)

## Story 17.1c: AI Move Selection Target Selection & Testing
As a **AI move selection engineer**,
I want **complex target selection logic and comprehensive test coverage**,
so that **AI move selection matches TypeScript behavior exactly with 100% test parity**.

### Acceptance Criteria
1. Target selection logic from getNextTargets() (lines 6717-6800)
2. Multi-target move handling (AoE moves like Earthquake, Surf)
3. Single-target optimization (select best target based on benefit scores)
4. Move target type filtering (MoveTarget enums: USER, OTHER, ALL_OTHERS, etc.)
5. Double battle target selection with ally considerations
6. Unit test suite: 40+ tests covering all algorithms (move queue, usability, benefit scoring, KO detection, AI selection)
7. Integration test suite: 15+ tests with full battle context
8. Parity test suite: 50+ scenarios validating 100% behavioral match with TypeScript
9. AO compliance validation: 100% (no forbidden patterns)
10. Performance validation: <500ms for typical scenarios, <5s execution limit

## Story 17.2: AI Switch Decision Logic Migration
As a **AI switch decision engineer**,
I want **AI Pokemon switching decision algorithms migrated to stateless AO process**,
so that **AI switching logic maintains identical evaluation and timing behavior**.

### Acceptance Criteria
1. AI switch decision calculations maintain identical evaluation criteria and timing behavior
2. Switch opportunity assessment maintains identical strategic evaluation and risk analysis
3. Pokemon matchup evaluation maintains identical type advantage and stat consideration
4. Switch timing optimization maintains identical turn management and opportunity recognition
5. Complex switch scenarios maintain identical decision resolution and strategic implementation
6. Comprehensive testing validates 100% AI switch decision behavioral and strategic parity

---

## ~~Removed Stories~~ (Features Don't Exist in TypeScript Reference)

The following stories were removed from Epic 17 as they describe functionality that does not exist in the PokéRogue TypeScript codebase. These would require new feature development rather than migration:

### ~~Story 17.3: AI Item Usage Systems Migration~~ (REMOVED)
**Reason for Removal**: TypeScript codebase has NO implementation of:
- AI trainer item usage (no Command.ITEM, no item selection logic)
- Trainers only use: Fight, Switch, Tera (no healing items, status cures, etc.)

### ~~Story 17.4: AI Strategy Adaptation & Learning Migration~~ (REMOVED)
**Reason for Removal**: TypeScript codebase has NO implementation of:
- Strategy adaptation or learning systems
- Battle pattern recognition or opponent behavior analysis
- Counter-strategy development
- Only "adaptive" mechanism: `enemySwitchCounter` (simple counter, already migrated in Story 17.2)

### ~~Story 17.5: AI Difficulty Scaling Migration~~ (REMOVED)
**Reason for Removal**: AI difficulty is controlled by static configuration (`isBoss` flag), not dynamic scaling systems

### ~~Story 17.6: Trainer Personality Migration~~ (REMOVED)
**Reason for Removal**: Trainers have static configurations (TrainerConfig), no personality behavior systems exist

### ~~Story 17.7: Dynamic Party Generation Migration~~ (REMOVED)
**Reason for Removal**: Party generation is static configuration-based via TrainerConfig, not dynamic algorithms

### ~~Story 17.8: NPC Interaction Migration~~ (REMOVED)
**Reason for Removal**: NPC systems would be UI/frontend scope, not AI battle systems

---

## Epic 17 Implementation Summary

**Status**: ✅ COMPLETE - All existing AI behavior migrated

**Completed Stories**:
1. ✅ Story 17.1: AI Move Selection Core Implementation
2. ✅ Story 17.1a: AI Move Selection Type System Enhancement
3. ✅ Story 17.1b: AI Move Selection Damage Calculation
4. ✅ Story 17.1c: AI Move Selection Target Selection & Testing
5. ✅ Story 17.2: AI Switch Decision Logic Migration

**Process Created**: `processes/ai-move-selection-engine.lua` (78KB / 500KB limit)

**What Was Successfully Migrated**:
- ✅ Move selection algorithms (RANDOM, SMART_RANDOM, SMART AI types)
- ✅ Move benefit scoring system (user + target benefit scores)
- ✅ KO move detection with damage calculation
- ✅ Full 18×18 type effectiveness matrix
- ✅ STAB (Same-Type Attack Bonus) calculations
- ✅ Target selection logic (single-target and multi-target moves)
- ✅ Switch decision logic with matchup score evaluation
- ✅ `enemySwitchCounter` adaptive switch frequency mechanism
- ✅ Boss trainer vs regular trainer differentiation

**Testing Summary**:
- Unit tests: 45+ tests covering all AI algorithms
- Integration tests: 15+ tests with full battle context
- Parity tests: 50+ scenarios validating 100% behavioral match with TypeScript
- AO compliance: 100% (no forbidden patterns)

**Result**: Epic 17 migration is COMPLETE. All AI behavior that exists in PokéRogue TypeScript has been successfully migrated to AO processes.
