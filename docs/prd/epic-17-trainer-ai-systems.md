# Epic 17: Trainer & AI Systems

Migrate AI battle decision making, trainer personalities, dynamic party generation, and NPC interaction systems while maintaining identical behavioral patterns and decision-making algorithms.

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

## Story 17.3: AI Item Usage Systems Migration
As a **AI item usage engineer**,  
I want **AI item selection and usage logic migrated to stateless AO process**,  
so that **AI item decisions maintain identical trigger conditions and selection behavior**.

### Acceptance Criteria
1. AI item usage logic maintains identical trigger conditions and selection behavior
2. Item priority assessment maintains identical utility evaluation and timing optimization
3. Item availability validation maintains identical inventory checking and constraint logic
4. Item effectiveness calculation maintains identical benefit analysis and strategic evaluation
5. Complex item scenarios maintain identical usage resolution and strategic implementation
6. Comprehensive testing validates 100% AI item usage behavioral and strategic parity

## Story 17.4: AI Strategy Adaptation & Learning Migration
As a **AI strategy adaptation engineer**,  
I want **AI adaptive strategy and learning systems migrated to stateless AO process**,  
so that **AI strategy evolution maintains identical learning patterns and adjustment behavior**.

### Acceptance Criteria
1. AI strategy adaptation maintains identical learning patterns and adjustment behavior
2. Battle pattern recognition maintains identical analysis and strategic modification logic
3. Opponent behavior analysis maintains identical assessment and counter-strategy development
4. Strategy effectiveness evaluation maintains identical performance analysis and optimization
5. Complex adaptation scenarios maintain identical learning resolution and strategy evolution
6. Comprehensive testing validates 100% AI strategy adaptation behavioral and learning parity

## Story 17.5: AI Difficulty Scaling Migration
As a **AI difficulty scaling engineer**,  
I want **AI difficulty and intelligence scaling migrated to stateless AO process**,  
so that **AI challenge progression maintains identical scaling and modification behavior**.

### Acceptance Criteria
1. AI difficulty scaling maintains identical challenge progression and intelligence modification
2. Skill level adjustment maintains identical performance modification and capability scaling
3. Decision complexity scaling maintains identical strategic depth and tactical sophistication
4. Battle flow management maintains identical turn planning and sequence optimization
5. Complex difficulty scenarios maintain identical scaling resolution and challenge optimization
6. Comprehensive testing validates 100% AI difficulty scaling behavioral and challenge parity

## Story 17.6: Trainer Personality Migration
As a **trainer personality engineer**,  
I want **trainer personality and behavior systems migrated to stateless AO process**,  
so that **trainer characterization and interaction maintain identical personality expression**.

### Acceptance Criteria
1. Personality trait algorithms maintain identical behavior modification and expression patterns
2. Trainer dialogue generation maintains identical personality-based text selection and presentation
3. Personality influence on battle tactics maintains identical strategy modification and decision weighting
4. Trainer interaction patterns maintain identical social behavior and response logic
5. Personality development maintains identical growth patterns and trait evolution behavior
6. Personality compatibility calculations maintain identical relationship and interaction assessment
7. Complex personality scenarios maintain identical behavioral expression and interaction resolution
8. Comprehensive testing validates 100% trainer personality system behavioral and expression parity

## Story 17.7: Dynamic Party Generation Migration
As a **party generation engineer**,  
I want **dynamic trainer party generation systems migrated to stateless AO process**,  
so that **trainer team composition maintains identical generation algorithms and balance**.

### Acceptance Criteria
1. Party composition algorithms produce statistically identical team structure and Pokemon selection
2. Level scaling calculations maintain identical difficulty progression and stat distribution
3. Type coverage optimization maintains identical team balance and strategic composition logic
4. Party generation constraints maintain identical validation and restriction enforcement
5. Dynamic team adaptation maintains identical adjustment logic and rebalancing behavior
6. Party generation performance maintains identical generation speed and computational efficiency
7. Complex party scenarios maintain identical composition resolution and balance optimization
8. Comprehensive testing validates 100% party generation system algorithmic and balance parity

## Story 17.8: NPC Interaction Migration
As a **NPC interaction engineer**,  
I want **NPC interaction and dialogue systems migrated to stateless AO process**,  
so that **NPC behavior and conversation maintain identical interaction patterns and functionality**.

### Acceptance Criteria
1. NPC dialogue trees maintain identical conversation flow and choice consequence logic
2. NPC behavior state tracking maintains identical personality persistence and interaction memory
3. NPC quest and task systems maintain identical objective tracking and completion validation
4. NPC reaction algorithms maintain identical response calculation and emotion expression behavior
5. NPC interaction persistence maintains identical relationship tracking and history preservation
6. NPC group dynamics maintain identical social interaction and collective behavior patterns
7. Complex NPC scenarios maintain identical interaction resolution and relationship development
8. Comprehensive testing validates 100% NPC interaction system behavioral and social parity
