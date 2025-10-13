# Advanced Pokedex Features Engine - Design Document

**Date:** 2025-10-13
**Author:** James (Dev Agent)
**Story:** 22.3 - Advanced Pokedex Features Enhancement & Migration

## Process Architecture

### Overview
- **Process Name:** `advanced-pokedex-features-engine.lua`
- **Pattern:** Monolithic stateless AO process
- **Size Estimate:** 50-60KB (10-12% of 500KB limit)
- **Dependencies:** Embedded only (no external requires except json)

### Design Principles
1. **Stateless**: All operations derive results from input data, no process-local state
2. **Deterministic**: Consistent results for identical inputs
3. **Monolithic**: All logic embedded in single file
4. **ADP v1.0 Compliant**: Info handler for self-documentation
5. **Individual Handlers**: One handler per action (no multi-action handlers)

## Handler Design

### Core Handlers

#### 1. Info Handler (ADP v1.0)
**Trigger:** `Action = "Info"`
**Purpose:** Self-documentation and capability discovery
**Response:** Process metadata, version, capabilities, available handlers

#### 2. SearchPokedex Handler
**Trigger:** `Action = "SearchPokedex"`
**Purpose:** Execute search queries with text matching
**Input:**
- `msg.Data` (JSON): `{ textSearch: {name, move1, move2, ability1, ability2}, filters, sort }`
**Output:**
- Matching species with relevance scores
- Applied filter metadata
- Match reasons for debugging

**Algorithm:**
1. Parse search query from msg.Data
2. Apply text search filters (NAME, MOVE, ABILITY)
3. Apply generation/type/biome/caught/unlocks/misc filters (AND logic)
4. Apply sort criteria with direction
5. Return paginated results with metadata

**Search Matching:**
- **Name:** Case-insensitive substring matching + optional fuzzy (Levenshtein ≤2)
- **Move:** Search across level-up, egg, TM moves
- **Ability:** Search primary, hidden, passive abilities

**Relevance Scoring (0-100):**
- Exact name match: 100
- Name substring match: 80
- Move match: 60
- Ability match: 60
- Fuzzy name match (distance 1): 40
- Fuzzy name match (distance 2): 20

#### 3. ApplyFilters Handler
**Trigger:** `Action = "ApplyFilters"`
**Purpose:** Apply multiple filter criteria to species dataset
**Input:**
- `msg.Data` (JSON): `{ filters: {generation, types, biome, caught, unlocks, misc} }`
**Output:**
- Filtered species list
- Applied filter metadata
- Filter statistics (total, filtered count)

**Filter Logic (AND operations):**
1. **Generation Filter:** Array of generation numbers [1-9]
2. **Type Filter:** Array of type IDs, matches primary OR secondary type
3. **Biome Filter:** Array of biome IDs + "Uncatchable" option
4. **Caught Status Filter:** NORMAL, SHINY (variants 1/2/3), UNCAUGHT
5. **Unlocks Filter (RADIAL):**
   - PASSIVE: OFF, ON (unlocked), UNLOCKABLE, EXCLUDE (locked)
   - COST_REDUCTION: OFF, ON (any), ONE, TWO, UNLOCKABLE, EXCLUDE
6. **Misc Filter (RADIAL):**
   - STARTER: OFF, ON (is starter), EXCLUDE (not starter)
   - FAVORITE: OFF, ON (is favorite), EXCLUDE (not favorite)
   - WIN: OFF, ON (has won), EXCLUDE (has not won)
   - HIDDEN_ABILITY: OFF, ON (has HA), EXCLUDE (no HA)
   - SEEN_SPECIES: OFF, ON (is seen), EXCLUDE (unseen)
   - ENCOUNTERED_SPECIES: OFF, ON (encountered), EXCLUDE (not encountered)
   - EGG: OFF, ON (egg purchasable)
   - POKERUS: OFF, ON (has pokerus)

**State Mappings:**
- OFF: No filtering for this criterion
- ON: Include only matching species
- EXCLUDE: Exclude matching species
- UNLOCKABLE: Include only species that can be unlocked but aren't yet
- ONE/TWO: Cost reduction level (specific to COST_REDUCTION)

#### 4. SortResults Handler
**Trigger:** `Action = "SortResults"`
**Purpose:** Sort filtered results by specified criteria
**Input:**
- `msg.Data` (JSON): `{ species: [...], sort: {criteria, direction} }`
**Output:**
- Sorted species list
- Sort metadata

**Sort Criteria:**
- **NUMBER:** Pokedex number (speciesId)
- **COST:** Starter cost value
- **CANDY:** Candy count
- **IV:** Average IV quality (sum of IVs / 6)
- **NAME:** Alphabetical by species name
- **CAUGHT:** Caught count
- **HATCHED:** Hatched count

**Sort Direction:**
- ASC: -1 (ascending order)
- DESC: 1 (descending order)

**Stable Sort:** Lua table.sort maintains insertion order for equal values

#### 5. GetVisualization Handler
**Trigger:** `Action = "GetVisualization"`
**Purpose:** Generate visualization data for species display
**Input:**
- `msg.SpeciesId` (string): Species ID to visualize
**Output:**
- Complete species display data
- Type badges, stat displays, abilities, moves, forms

**Visualization Data Structure:**
```lua
{
  speciesId = 25,
  displayName = "Pikachu",
  number = "025",
  types = {
    primary = {id = 13, name = "Electric", color = "#F8D030"},
    secondary = nil
  },
  stats = {
    base = {hp, atk, def, spatk, spdef, spd},
    calculated = {hp, atk, def, spatk, spdef, spd}  -- at level 50
  },
  abilities = [{name, description, unlocked}],
  moves = {
    levelUp = [{level, moveId, name}],
    eggMoves = [{moveId, name}],
    tmMoves = [{tmId, moveId, name}]
  },
  forms = [{formIndex, name, unlocked}]
}
```

#### 6. ExportData Handler ✨ **[ENHANCEMENT]**
**Trigger:** `Action = "ExportData"`
**Purpose:** Export filtered/sorted results in specified format
**Input:**
- `msg.Data` (JSON): `{ format: "JSON"|"CSV", columns: [...], species: [...] }`
**Output:**
- Exported data string
- Export metadata (timestamp, format, record count)

**Export Formats:**

**JSON Format:**
```json
{
  "exportDate": 1234567890,
  "format": "JSON",
  "totalRecords": 150,
  "appliedFilters": {...},
  "data": [
    {
      "speciesId": 25,
      "name": "Pikachu",
      "generation": 1,
      "types": [13],
      "biomes": [0, 1, 5],
      "cost": 3,
      "caught": true,
      "shiny": true,
      "passive": "UNLOCKED",
      "costReduction": 1,
      "candyCount": 150,
      "avgIVs": 28.5,
      "caughtCount": 5,
      "hatchedCount": 2
    }
  ]
}
```

**CSV Format:**
```csv
speciesId,name,generation,types,biomes,cost,caught,shiny,passive,costReduction,candyCount,avgIVs,caughtCount,hatchedCount
25,Pikachu,1,13,"0,1,5",3,true,true,UNLOCKED,1,150,28.5,5,2
```

**Column Options (14 fields):**
- speciesId, name, generation, types, biomes, cost
- caught, shiny, passive, costReduction
- candyCount, avgIVs, caughtCount, hatchedCount

**Size Limits:**
- Max 1000 records per export
- Pagination required for larger datasets

#### 7. CustomizePreferences Handler
**Trigger:** `Action = "CustomizePreferences"`
**Purpose:** Save and load user preferences
**Input:**
- `msg.Data` (JSON): `{ savedPresets: [...], defaultSort: {...}, displayPreferences: {...} }`
**Output:**
- Updated preferences confirmation
- Stored preference data

**Preference Types:**
1. **Saved Filter Presets:**
   - Name: "Shiny Gen 1"
   - Filters: {generation: [1], caught: "SHINY"}

2. **Default Sort Preferences:**
   - criteria: "NAME"
   - direction: -1 (ASC)

3. **Display Preferences:**
   - infoDensity: "COMPACT"|"NORMAL"|"DETAILED"
   - showDecorations: true|false

**Storage:** Session-based only (no persistent cross-session storage in stateless process)

#### 8. GetAnalytics Handler ✨ **[ENHANCEMENT]**
**Trigger:** `Action = "GetAnalytics"`
**Purpose:** Provide search pattern insights and filter usage statistics
**Input:**
- `msg.Data` (JSON): `{ analyticsType: "search"|"filter"|"result" }`
**Output:**
- Analytics data with trends and insights

**Analytics Types:**

**Search Analytics:**
- Most searched species names
- Most searched moves
- Most searched abilities
- Recent search history (last 50 searches)

**Filter Analytics:**
- Most used filters
- Popular filter combinations
- Average result count by filter type

**Result Analytics:**
- Empty search rate
- Average result count
- Filter effectiveness scores

**Retention Policy:**
- Session-based: 50 recent searches
- No persistent storage across sessions
- No cross-user analytics (privacy-preserving)

## Data Structures

### SearchQuery
```lua
{
  textSearch = {
    name = "",           -- Species name search
    move1 = "",          -- First move search
    move2 = "",          -- Second move search
    ability1 = "",       -- First ability search
    ability2 = ""        -- Second ability search
  },
  filters = {
    generation = {1, 3, 5},           -- Array of generations
    types = {6, 10},                   -- Array of type IDs
    biome = {0, 5, 12},                -- Array of biome IDs
    caught = "NORMAL",                 -- Caught status string
    unlocks = {
      passive = "OFF",                 -- Passive filter state
      costReduction = "OFF"            -- Cost reduction filter state
    },
    misc = {
      starter = "OFF",
      favorite = "OFF",
      winCondition = "OFF",
      hiddenAbility = "OFF",
      seenSpecies = "OFF",
      encounteredSpecies = "OFF",
      egg = "OFF",
      pokerus = "OFF"
    }
  },
  sort = {
    criteria = "NUMBER",               -- Sort criteria
    direction = -1                     -- -1 = ASC, 1 = DESC
  }
}
```

### SearchResult
```lua
{
  species = {
    {
      speciesId = 25,
      name = "Pikachu",
      generation = 1,
      types = {13, -1},
      biomes = {0, 1, 5},
      cost = 3,
      caught = true,
      shiny = true,
      passive = "UNLOCKED",
      costReduction = 1,
      candyCount = 150,
      avgIVs = 28.5,
      caughtCount = 5,
      hatchedCount = 2,
      matchScore = 100,                -- Relevance score
      matchReason = "Exact name match"
    }
  },
  totalCount = 150,
  filteredCount = 15,
  appliedFilters = {...},
  sortCriteria = "NAME",
  sortDirection = -1
}
```

## Error Handling

### Validation Rules
1. **Search Query Validation:**
   - At least one search field or filter must be provided
   - Text search terms: max 50 characters each
   - Generation: 1-9 only
   - Type IDs: 1-18 (excluding 0 and 19)
   - Biome IDs: 0-34 + "Uncatchable"

2. **Filter State Validation:**
   - Validate state values: ON, OFF, EXCLUDE, UNLOCKABLE, ONE, TWO
   - Ensure filter combinations are valid

3. **Sort Validation:**
   - Validate criteria: NUMBER, COST, CANDY, IV, NAME, CAUGHT, HATCHED
   - Validate direction: -1 (ASC) or 1 (DESC)

4. **Export Validation:**
   - Format: "JSON" or "CSV" only
   - Columns: Must be from allowed 14 fields
   - Record limit: Max 1000 records

### Error Response Pattern
```lua
ao.send({
  Target = msg.From,
  Action = "Error",
  Error = "Descriptive error message",
  ErrorCode = "INVALID_SEARCH_QUERY"  -- Machine-readable code
})
```

### Error Codes
- `INVALID_SEARCH_QUERY`: Search query validation failed
- `INVALID_FILTER`: Filter criteria validation failed
- `INVALID_SORT`: Sort criteria validation failed
- `INVALID_EXPORT_FORMAT`: Export format not supported
- `EXPORT_SIZE_EXCEEDED`: Export record limit exceeded
- `SPECIES_NOT_FOUND`: Species ID not found in database

## Performance Optimization

### Search Performance
- **Short-circuit evaluation:** Stop filtering early if no matches
- **Index lookups:** Use species ID as primary key
- **Substring matching:** Use Lua string.find() for efficiency

### Filter Performance
- **Filter order optimization:** Apply most restrictive filters first
  1. Text search (name/move/ability)
  2. Generation filter
  3. Type filter
  4. Biome filter
  5. Caught status filter
  6. Unlocks filter
  7. Misc filters

### Sort Performance
- **Stable sort:** Lua table.sort() is stable by default
- **Cached comparisons:** Pre-compute sort keys when possible
- **Early termination:** For top-N queries, use partial sorting

### Pagination
- **Default page size:** 100 species
- **Max page size:** 500 species
- **Cursor-based:** Use species ID for stable pagination

## Testing Strategy

### Unit Tests (testing/unit/advanced-pokedex-features-engine.test.lua)
1. Text search: Name, move, ability matching
2. Individual filters: Generation, type, biome, caught, unlocks, misc
3. Combined filters: Multiple filters with AND logic
4. Sort criteria: All 7 types with both directions
5. Fuzzy matching: Levenshtein distance calculations
6. Export: JSON and CSV format generation
7. Analytics: Search history tracking
8. Edge cases: Empty results, invalid inputs

### Parity Tests (testing/parity/advanced-pokedex-features-parity.test.lua)
1. Text search parity with TypeScript implementation
2. Filter parity: All filter types match TypeScript behavior
3. Sort parity: All sort criteria match TypeScript behavior
4. Visualization parity: Data structure matches TypeScript
5. Edge case parity: Empty results, complex filters

### Integration Tests (testing/integration/advanced-pokedex-features.test.js)
1. Complete search workflow: Query → Filter → Sort → Results
2. Multi-filter application with result verification
3. Export functionality with data validation
4. Customization persistence across messages
5. Complex filter combinations with performance monitoring
6. Empty result handling with suggestions

## Size Estimate Breakdown

| Component | Estimated Size | Notes |
|-----------|----------------|-------|
| **Search algorithms** | ~12KB | Name, move, ability search + fuzzy matching |
| **Filter system** | ~15KB | 7 filter types with state management |
| **Sort implementation** | ~8KB | 7 sort criteria with direction toggle |
| **Visualization generation** | ~10KB | Species info cards, stats, type badges |
| **Export functionality** | ~8KB | JSON and CSV formatters |
| **Analytics tracking** | ~5KB | Search history, filter usage stats |
| **Handler implementations** | ~15KB | 8 handlers with validation |
| **ADP Info handler** | ~5KB | Self-documentation and capability listing |
| **Embedded constants** | ~3KB | DropDown types, states, sort criteria |
| **Total** | **~81KB** | Still within 500KB limit (16% utilization) |

**Note:** Initial estimate was 50-60KB, but detailed design reveals ~81KB is more realistic. This is still well within the 500KB limit with comfortable margin.

## AO Compliance Notes

### Forbidden Patterns (validated by ao-sandbox-validator)
- ❌ No `require()` statements (except `require("json")`)
- ❌ No `os.time()` calls (use `msg.Timestamp` instead)
- ❌ No unnecessary `pcall()` wrappers for simple operations
- ❌ No multi-action handlers (one handler per Action tag)

### Required Patterns
- ✅ Individual handlers with `Handlers.add()`
- ✅ Direct error validation (no pcall for table lookups)
- ✅ String conversion for all tag values (`tostring()`)
- ✅ ADP v1.0 Info handler for self-documentation
- ✅ Deterministic behavior (no randomness, no external I/O)

## Implementation Plan

### Phase 1: Core Search (Task 3)
- Implement SearchPokedex handler
- Text search algorithms (name, move, ability)
- Fuzzy matching with Levenshtein distance
- Search ranking and relevance scoring

### Phase 2: Filtering (Task 4)
- Implement ApplyFilters handler
- All 7 filter types (generation, type, biome, caught, unlocks, misc, sort)
- Filter state management (ON, OFF, EXCLUDE, UNLOCKABLE, ONE, TWO)
- Filter combination logic (AND operations)

### Phase 3: Sorting (Task 5)
- Implement SortResults handler
- All 7 sort criteria with direction toggle
- Stable sorting implementation

### Phase 4: Visualization (Task 6)
- Implement GetVisualization handler
- Species info card generation
- Type badges, stat displays, abilities, moves, forms

### Phase 5: Export ✨ (Task 7)
- Implement ExportData handler
- JSON and CSV formatters
- Column selection and size limits

### Phase 6: Analytics ✨ (Task 8)
- Implement GetAnalytics handler
- Search history tracking
- Filter usage statistics

### Phase 7: Customization (Task 9)
- Implement CustomizePreferences handler
- Saved filter presets
- Default sort preferences

### Phase 8: Complex Scenarios (Task 10)
- Complex filter combinations
- Empty result handling with suggestions
- Performance optimization
- Result caching

### Phase 9: Testing (Tasks 11-12)
- Parity tests (Task 11)
- Integration tests (Task 12)

### Phase 10: Validation (Task 13)
- Size validation
- AO compliance validation

### Phase 11: Documentation (Task 14)
- Process documentation
- Handler schemas
- Example queries

## Design Decisions

### Decision 1: Monolithic vs. Modular
**Choice:** Monolithic single-file process
**Rationale:** AO best practice, no external dependencies, easier deployment

### Decision 2: Handler Granularity
**Choice:** Individual handlers per action (8 total)
**Rationale:** AO requirement, clear separation of concerns

### Decision 3: Fuzzy Matching Implementation
**Choice:** Levenshtein distance ≤2 for NAME filter only
**Rationale:** Balance between flexibility and performance

### Decision 4: Analytics Retention
**Choice:** Session-based, 50 recent searches
**Rationale:** Privacy-preserving, no cross-session state in stateless process

### Decision 5: Export Size Limits
**Choice:** Max 1000 records per export
**Rationale:** Prevent abuse, reasonable for user needs

### Decision 6: Pagination Strategy
**Choice:** Cursor-based with default page size 100
**Rationale:** Stable pagination, good performance

## Open Questions / Future Enhancements

1. **Cross-session preferences:** Could be stored in separate coordinator process
2. **Real-time search suggestions:** Could implement typeahead with prefix matching
3. **Advanced analytics:** Cross-user trends (requires separate analytics process)
4. **Cached results:** Could implement result caching for frequent searches
5. **Batch export:** Support for larger datasets with streaming

## Design Review Checklist

- [x] All 8 handlers designed with clear inputs/outputs
- [x] Filter system supports all TypeScript features (migration complete)
- [x] Sort criteria match TypeScript implementation
- [x] Export and analytics defined (enhancements)
- [x] Error handling patterns defined
- [x] Performance optimization strategies identified
- [x] Size estimate within 500KB limit (81KB, 16% utilization)
- [x] AO compliance requirements addressed
- [x] Testing strategy defined
- [x] Implementation plan sequenced

**Design Status:** ✅ Complete - Ready for Implementation (Task 3)
