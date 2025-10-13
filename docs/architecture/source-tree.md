# Source Tree

```plaintext
pokerogue-ao-migration/
├── processes/                              # AO Process Implementation
│   ├── battle-engine.lua                 # Battle resolution process
│   ├── biome-progression-engine.lua      # Biome and world progression
│   ├── daily-run-engine.lua              # Daily challenge generation
│   ├── challenge-framework-engine.lua    # Challenge creation and management
│   ├── trainer-encounter-engine.lua      # Trainer battle mechanics
│   ├── ai-move-selection-engine.lua      # AI decision making
│   └── [additional process files]        # Other stateless AO processes
│
├── testing/                                # Test Suite (AO-First Testing Strategy)
│   ├── unit/                              # Unit tests for AO processes (*.test.lua)
│   │   ├── battle-*.test.lua             # Battle engine unit tests
│   │   ├── biome-*.test.lua              # Biome progression unit tests
│   │   ├── daily-run-*.test.lua          # Daily run unit tests
│   │   ├── challenge-*.test.lua          # Challenge framework unit tests
│   │   └── [additional test files]       # Other process unit tests
│   │
│   ├── parity/                            # TypeScript behavioral comparison tests
│   │   ├── battle-parity.test.lua        # Battle engine parity tests
│   │   ├── biome-parity.test.lua         # Biome progression parity tests
│   │   ├── daily-run-parity.test.lua     # Daily run parity tests
│   │   └── [additional parity tests]     # Other parity validations
│   │
│   ├── integration/                       # Multi-process integration tests (aos-local)
│   │   ├── battle-integration.test.lua   # Battle flow integration
│   │   ├── biome-integration.test.lua    # Biome progression integration
│   │   └── [additional integration]      # Other integration scenarios
│   │
│   ├── performance/                       # Performance benchmarking tests
│   │   ├── battle-performance.test.lua   # Battle engine performance
│   │   └── [additional benchmarks]       # Other performance tests
│   │
│   ├── fixtures/                          # Test data and mock objects
│   ├── utils/                             # Testing utilities and helpers
│   └── reports/                           # Generated test reports
│
├── src/                                    # Original TypeScript Implementation (Reference)
│   ├── data/                              # Game data (species, moves, items, etc.)
│   ├── field/                             # Battle field and Pokemon management
│   ├── system/                            # Game systems and mechanics
│   └── [additional TypeScript files]     # Other TypeScript sources
│
├── scripts/                               # Build and Automation Scripts
│   ├── run-aolite-tests.lua              # Unit test runner (aolite framework)
│   ├── hooks/                             # Git hooks and CI validation
│   │   ├── tdd-pre-commit.sh             # TDD validation pre-commit hook
│   │   └── ao-compliance.sh              # AO compliance validation
│   └── [additional scripts]              # Other automation scripts
│
├── tools/                                  # Development Tools
│   ├── ao-sandbox-validator.lua          # AO compliance validation tool
│   └── [additional tools]                # Other development utilities
│
└── docs/                                   # Project Documentation
    ├── architecture/                      # Architecture documentation
    │   ├── source-tree.md                # This file
    │   ├── tech-stack.md                 # Technology stack
    │   ├── coding-standards.md           # Coding standards
    │   └── ao-compliance-guidelines.md   # AO compliance requirements
    ├── prd/                               # Product Requirements Documents
    │   ├── epic-*.md                     # Epic specifications
    │   └── [additional PRDs]             # Other requirements
    ├── stories/                           # Story documents
    │   ├── *.story.md                    # Story specifications
    │   └── [additional stories]          # Other stories
    └── qa/                                # QA documentation
        └── gates/                         # QA gate files
            └── *.yml                     # QA validation results
```
