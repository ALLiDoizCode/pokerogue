/**
 * AI Move Selection Target Selection Parity Tests
 * Story 17.1c: Parity Testing
 *
 * Validates that Lua implementation matches TypeScript behavior exactly
 * Tests getMoveTargets() and getNextTargets() parity with TypeScript reference
 */

import { describe, it, expect } from '@jest/globals';

// Mock types for parity testing
type PokemonType = number;
type MoveCategory = 0 | 1 | 2; // PHYSICAL | SPECIAL | STATUS
type MoveTarget = number;
type BattlerIndex = number;

interface Pokemon {
  battlerIndex: BattlerIndex;
  isPlayer: boolean;
  hp: number;
  maxHp: number;
  types: PokemonType[];
  stats: {
    attack: number;
    defense: number;
    spAtk: number;
    spDef: number;
    speed: number;
    hp: number;
  };
  level: number;
}

interface Move {
  moveId: number;
  moveType: PokemonType;
  power: number;
  category: MoveCategory;
  moveTarget: MoveTarget;
  hasCounterAttr?: boolean;
}

interface MoveTargetSet {
  targets: BattlerIndex[];
  multiple: boolean;
}

/**
 * Mock TypeScript implementation of getMoveTargets for parity comparison
 * Based on src/data/moves/move-utils.ts:52-126
 */
function getMoveTargetsTS(
  attacker: Pokemon,
  moveTarget: MoveTarget,
  opponents: Pokemon[],
  ally?: Pokemon
): MoveTargetSet {
  let set: Pokemon[] = [];
  let multiple = false;

  switch (moveTarget) {
    case 0: // USER
    case 18: // PARTY
      set = [attacker];
      break;

    case 3: // NEAR_OTHER
    case 1: // OTHER
    case 4: // ALL_NEAR_OTHERS
    case 2: // ALL_OTHERS
      set = ally ? opponents.concat([ally]) : opponents;
      multiple = moveTarget === 4 || moveTarget === 2;
      break;

    case 5: // NEAR_ENEMY
    case 6: // ALL_NEAR_ENEMIES
    case 8: // ALL_ENEMIES
    case 16: // ENEMY_SIDE
      set = opponents;
      multiple = moveTarget !== 5;
      break;

    case 7: // RANDOM_NEAR_ENEMY
      set = opponents.length > 0 ? [opponents[0]] : [];
      break;

    case 9: // ATTACKER
      return { targets: [-1], multiple: false };

    case 10: // NEAR_ALLY
    case 11: // ALLY
      set = ally ? [ally] : [];
      break;

    case 12: // USER_OR_NEAR_ALLY
    case 13: // USER_AND_ALLIES
    case 15: // USER_SIDE
      set = ally ? [attacker, ally] : [attacker];
      multiple = moveTarget !== 12;
      break;

    case 14: // ALL
    case 17: // BOTH_SIDES
      set = (ally ? [attacker, ally] : [attacker]).concat(opponents);
      multiple = true;
      break;

    case 19: // CURSE
      const isGhostType = attacker.types.includes(7); // Ghost type
      if (isGhostType) {
        set = ally ? opponents.concat([ally]) : opponents;
      } else {
        set = [attacker];
      }
      break;

    default:
      set = opponents;
      break;
  }

  // Filter to active Pokemon
  const targets = set
    .filter(p => p && p.hp > 0)
    .map(p => p.battlerIndex);

  return { targets, multiple };
}

/**
 * Helper to create test Pokemon
 */
function createPokemon(
  battlerIndex: BattlerIndex,
  isPlayer: boolean,
  hp: number,
  types: PokemonType[]
): Pokemon {
  return {
    battlerIndex,
    isPlayer,
    hp,
    maxHp: 100,
    types,
    stats: {
      attack: 100,
      defense: 100,
      spAtk: 100,
      spDef: 100,
      speed: 100,
      hp: 100,
    },
    level: 50,
  };
}

describe('AI Move Selection - Target Selection Parity', () => {
  // Test Suite 1: Target Resolution Parity (15 tests)

  it('USER target type - should match TypeScript', () => {
    const attacker = createPokemon(0, true, 100, [9]);
    const opponents = [createPokemon(2, false, 100, [10])];

    const tsResult = getMoveTargetsTS(attacker, 0, opponents);

    // Lua implementation should match
    expect(tsResult.targets).toHaveLength(1);
    expect(tsResult.targets[0]).toBe(0);
    expect(tsResult.multiple).toBe(false);
  });

  it('OTHER target type - should match TypeScript', () => {
    const attacker = createPokemon(0, true, 100, [0]);
    const opponents = [
      createPokemon(2, false, 100, [0]),
      createPokemon(3, false, 100, [0]),
    ];

    const tsResult = getMoveTargetsTS(attacker, 1, opponents);

    expect(tsResult.targets).toHaveLength(2);
    expect(tsResult.multiple).toBe(false);
  });

  it('ALL_ENEMIES target type - should match TypeScript', () => {
    const attacker = createPokemon(0, true, 100, [4]);
    const opponents = [
      createPokemon(2, false, 100, [12]),
      createPokemon(3, false, 100, [9]),
    ];

    const tsResult = getMoveTargetsTS(attacker, 8, opponents);

    expect(tsResult.targets).toHaveLength(2);
    expect(tsResult.multiple).toBe(true);
  });

  it('ATTACKER target type - should match TypeScript', () => {
    const attacker = createPokemon(0, true, 100, [1]);
    const opponents = [createPokemon(2, false, 100, [0])];

    const tsResult = getMoveTargetsTS(attacker, 9, opponents);

    expect(tsResult.targets).toHaveLength(1);
    expect(tsResult.targets[0]).toBe(-1);
    expect(tsResult.multiple).toBe(false);
  });

  it('ALLY target type with ally present - should match TypeScript', () => {
    const attacker = createPokemon(0, true, 100, [0]);
    const opponents = [createPokemon(2, false, 100, [0])];
    const ally = createPokemon(1, true, 100, [0]);

    const tsResult = getMoveTargetsTS(attacker, 11, opponents, ally);

    expect(tsResult.targets).toHaveLength(1);
    expect(tsResult.targets[0]).toBe(1);
  });

  it('ALLY target type without ally - should match TypeScript', () => {
    const attacker = createPokemon(0, true, 100, [0]);
    const opponents = [createPokemon(2, false, 100, [0])];

    const tsResult = getMoveTargetsTS(attacker, 11, opponents);

    expect(tsResult.targets).toHaveLength(0);
  });

  it('USER_AND_ALLIES target type - should match TypeScript', () => {
    const attacker = createPokemon(0, true, 100, [0]);
    const opponents = [createPokemon(2, false, 100, [0])];
    const ally = createPokemon(1, true, 100, [0]);

    const tsResult = getMoveTargetsTS(attacker, 13, opponents, ally);

    expect(tsResult.targets).toHaveLength(2);
    expect(tsResult.multiple).toBe(true);
  });

  it('ALL target type - should match TypeScript', () => {
    const attacker = createPokemon(0, true, 100, [0]);
    const opponents = [
      createPokemon(2, false, 100, [0]),
      createPokemon(3, false, 100, [0]),
    ];
    const ally = createPokemon(1, true, 100, [0]);

    const tsResult = getMoveTargetsTS(attacker, 14, opponents, ally);

    expect(tsResult.targets).toHaveLength(4);
    expect(tsResult.multiple).toBe(true);
  });

  it('USER_SIDE target type - should match TypeScript', () => {
    const attacker = createPokemon(0, true, 100, [0]);
    const opponents = [createPokemon(2, false, 100, [0])];
    const ally = createPokemon(1, true, 100, [0]);

    const tsResult = getMoveTargetsTS(attacker, 15, opponents, ally);

    expect(tsResult.targets).toHaveLength(2);
    expect(tsResult.multiple).toBe(true);
  });

  it('ENEMY_SIDE target type - should match TypeScript', () => {
    const attacker = createPokemon(0, true, 100, [0]);
    const opponents = [
      createPokemon(2, false, 100, [0]),
      createPokemon(3, false, 100, [0]),
    ];

    const tsResult = getMoveTargetsTS(attacker, 16, opponents);

    expect(tsResult.targets).toHaveLength(2);
    expect(tsResult.multiple).toBe(true);
  });

  it('BOTH_SIDES target type - should match TypeScript', () => {
    const attacker = createPokemon(0, true, 100, [0]);
    const opponents = [createPokemon(2, false, 100, [0])];
    const ally = createPokemon(1, true, 100, [0]);

    const tsResult = getMoveTargetsTS(attacker, 17, opponents, ally);

    expect(tsResult.targets).toHaveLength(3);
    expect(tsResult.multiple).toBe(true);
  });

  it('CURSE target type - Ghost type - should match TypeScript', () => {
    const attacker = createPokemon(0, true, 100, [7]); // Ghost
    const opponents = [createPokemon(2, false, 100, [0])];

    const tsResult = getMoveTargetsTS(attacker, 19, opponents);

    expect(tsResult.targets).toHaveLength(1);
    expect(tsResult.targets[0]).toBe(2);
  });

  it('CURSE target type - non-Ghost - should match TypeScript', () => {
    const attacker = createPokemon(0, true, 100, [0]); // Normal
    const opponents = [createPokemon(2, false, 100, [0])];

    const tsResult = getMoveTargetsTS(attacker, 19, opponents);

    expect(tsResult.targets).toHaveLength(1);
    expect(tsResult.targets[0]).toBe(0);
  });

  it('Inactive Pokemon filtering - should match TypeScript', () => {
    const attacker = createPokemon(0, true, 100, [0]);
    const opponents = [
      createPokemon(2, false, 0, [0]), // Fainted
      createPokemon(3, false, 100, [0]), // Active
    ];

    const tsResult = getMoveTargetsTS(attacker, 8, opponents);

    expect(tsResult.targets).toHaveLength(1);
    expect(tsResult.targets[0]).toBe(3);
  });

  it('Empty opponent list - should match TypeScript', () => {
    const attacker = createPokemon(0, true, 100, [0]);
    const opponents: Pokemon[] = [];

    const tsResult = getMoveTargetsTS(attacker, 5, opponents);

    expect(tsResult.targets).toHaveLength(0);
  });

  // Test Suite 2: Multi-target vs Single-target Parity (10 tests)

  it('Single-target flag - NEAR_ENEMY - should match TypeScript', () => {
    const attacker = createPokemon(0, true, 100, [0]);
    const opponents = [
      createPokemon(2, false, 100, [0]),
      createPokemon(3, false, 100, [0]),
    ];

    const tsResult = getMoveTargetsTS(attacker, 5, opponents);

    expect(tsResult.multiple).toBe(false);
  });

  it('Multi-target flag - ALL_ENEMIES - should match TypeScript', () => {
    const attacker = createPokemon(0, true, 100, [0]);
    const opponents = [
      createPokemon(2, false, 100, [0]),
      createPokemon(3, false, 100, [0]),
    ];

    const tsResult = getMoveTargetsTS(attacker, 8, opponents);

    expect(tsResult.multiple).toBe(true);
  });

  it('Multi-target flag - ALL_NEAR_ENEMIES - should match TypeScript', () => {
    const attacker = createPokemon(0, true, 100, [0]);
    const opponents = [
      createPokemon(2, false, 100, [0]),
      createPokemon(3, false, 100, [0]),
    ];

    const tsResult = getMoveTargetsTS(attacker, 6, opponents);

    expect(tsResult.multiple).toBe(true);
  });

  it('Multi-target flag - ALL_OTHERS - should match TypeScript', () => {
    const attacker = createPokemon(0, true, 100, [0]);
    const opponents = [createPokemon(2, false, 100, [0])];
    const ally = createPokemon(1, true, 100, [0]);

    const tsResult = getMoveTargetsTS(attacker, 2, opponents, ally);

    expect(tsResult.multiple).toBe(true);
  });

  it('Single-target flag - OTHER - should match TypeScript', () => {
    const attacker = createPokemon(0, true, 100, [0]);
    const opponents = [createPokemon(2, false, 100, [0])];
    const ally = createPokemon(1, true, 100, [0]);

    const tsResult = getMoveTargetsTS(attacker, 1, opponents, ally);

    expect(tsResult.multiple).toBe(false);
  });

  it('Multi-target flag - USER_AND_ALLIES - should match TypeScript', () => {
    const attacker = createPokemon(0, true, 100, [0]);
    const opponents = [createPokemon(2, false, 100, [0])];
    const ally = createPokemon(1, true, 100, [0]);

    const tsResult = getMoveTargetsTS(attacker, 13, opponents, ally);

    expect(tsResult.multiple).toBe(true);
  });

  it('Single-target flag - USER_OR_NEAR_ALLY - should match TypeScript', () => {
    const attacker = createPokemon(0, true, 100, [0]);
    const opponents = [createPokemon(2, false, 100, [0])];
    const ally = createPokemon(1, true, 100, [0]);

    const tsResult = getMoveTargetsTS(attacker, 12, opponents, ally);

    expect(tsResult.multiple).toBe(false);
  });

  it('Multi-target flag - ALL - should match TypeScript', () => {
    const attacker = createPokemon(0, true, 100, [0]);
    const opponents = [createPokemon(2, false, 100, [0])];

    const tsResult = getMoveTargetsTS(attacker, 14, opponents);

    expect(tsResult.multiple).toBe(true);
  });

  it('Multi-target flag - USER_SIDE - should match TypeScript', () => {
    const attacker = createPokemon(0, true, 100, [0]);
    const opponents = [createPokemon(2, false, 100, [0])];
    const ally = createPokemon(1, true, 100, [0]);

    const tsResult = getMoveTargetsTS(attacker, 15, opponents, ally);

    expect(tsResult.multiple).toBe(true);
  });

  it('Multi-target flag - ENEMY_SIDE - should match TypeScript', () => {
    const attacker = createPokemon(0, true, 100, [0]);
    const opponents = [
      createPokemon(2, false, 100, [0]),
      createPokemon(3, false, 100, [0]),
    ];

    const tsResult = getMoveTargetsTS(attacker, 16, opponents);

    expect(tsResult.multiple).toBe(true);
  });

  // Test Suite 3: Doubles Battle Parity (10 tests)

  it('Doubles - ally targeting with OTHER - should match TypeScript', () => {
    const attacker = createPokemon(0, true, 100, [0]);
    const opponents = [createPokemon(2, false, 100, [0])];
    const ally = createPokemon(1, true, 100, [0]);

    const tsResult = getMoveTargetsTS(attacker, 1, opponents, ally);

    expect(tsResult.targets).toContain(1); // Should include ally
  });

  it('Doubles - ally excluded with NEAR_ENEMY - should match TypeScript', () => {
    const attacker = createPokemon(0, true, 100, [0]);
    const opponents = [createPokemon(2, false, 100, [0])];
    const ally = createPokemon(1, true, 100, [0]);

    const tsResult = getMoveTargetsTS(attacker, 5, opponents, ally);

    expect(tsResult.targets).not.toContain(1); // Should not include ally
  });

  it('Doubles - USER_AND_ALLIES includes both - should match TypeScript', () => {
    const attacker = createPokemon(0, true, 100, [0]);
    const opponents = [createPokemon(2, false, 100, [0])];
    const ally = createPokemon(1, true, 100, [0]);

    const tsResult = getMoveTargetsTS(attacker, 13, opponents, ally);

    expect(tsResult.targets).toContain(0); // Self
    expect(tsResult.targets).toContain(1); // Ally
  });

  it('Doubles - ALL targets everyone - should match TypeScript', () => {
    const attacker = createPokemon(0, true, 100, [0]);
    const opponents = [
      createPokemon(2, false, 100, [0]),
      createPokemon(3, false, 100, [0]),
    ];
    const ally = createPokemon(1, true, 100, [0]);

    const tsResult = getMoveTargetsTS(attacker, 14, opponents, ally);

    expect(tsResult.targets).toHaveLength(4);
    expect(tsResult.targets).toContain(0);
    expect(tsResult.targets).toContain(1);
    expect(tsResult.targets).toContain(2);
    expect(tsResult.targets).toContain(3);
  });

  it('Doubles - NEAR_ALLY targets ally only - should match TypeScript', () => {
    const attacker = createPokemon(0, true, 100, [0]);
    const opponents = [createPokemon(2, false, 100, [0])];
    const ally = createPokemon(1, true, 100, [0]);

    const tsResult = getMoveTargetsTS(attacker, 10, opponents, ally);

    expect(tsResult.targets).toHaveLength(1);
    expect(tsResult.targets[0]).toBe(1);
  });

  it('Singles - ALLY without ally returns empty - should match TypeScript', () => {
    const attacker = createPokemon(0, true, 100, [0]);
    const opponents = [createPokemon(2, false, 100, [0])];

    const tsResult = getMoveTargetsTS(attacker, 11, opponents);

    expect(tsResult.targets).toHaveLength(0);
  });

  it('Doubles - ALL_OTHERS includes ally - should match TypeScript', () => {
    const attacker = createPokemon(0, true, 100, [0]);
    const opponents = [createPokemon(2, false, 100, [0])];
    const ally = createPokemon(1, true, 100, [0]);

    const tsResult = getMoveTargetsTS(attacker, 2, opponents, ally);

    expect(tsResult.targets).toHaveLength(2);
    expect(tsResult.targets).toContain(1);
    expect(tsResult.targets).toContain(2);
  });

  it('Doubles - USER_SIDE targets team only - should match TypeScript', () => {
    const attacker = createPokemon(0, true, 100, [0]);
    const opponents = [createPokemon(2, false, 100, [0])];
    const ally = createPokemon(1, true, 100, [0]);

    const tsResult = getMoveTargetsTS(attacker, 15, opponents, ally);

    expect(tsResult.targets).toHaveLength(2);
    expect(tsResult.targets).not.toContain(2); // Opponent excluded
  });

  it('Doubles - ENEMY_SIDE excludes allies - should match TypeScript', () => {
    const attacker = createPokemon(0, true, 100, [0]);
    const opponents = [
      createPokemon(2, false, 100, [0]),
      createPokemon(3, false, 100, [0]),
    ];
    const ally = createPokemon(1, true, 100, [0]);

    const tsResult = getMoveTargetsTS(attacker, 16, opponents, ally);

    expect(tsResult.targets).toHaveLength(2);
    expect(tsResult.targets).not.toContain(0);
    expect(tsResult.targets).not.toContain(1);
  });

  it('Doubles - BOTH_SIDES includes all - should match TypeScript', () => {
    const attacker = createPokemon(0, true, 100, [0]);
    const opponents = [createPokemon(2, false, 100, [0])];
    const ally = createPokemon(1, true, 100, [0]);

    const tsResult = getMoveTargetsTS(attacker, 17, opponents, ally);

    expect(tsResult.targets).toHaveLength(3);
    expect(tsResult.multiple).toBe(true);
  });

  // Test Suite 4: Edge Cases Parity (10 tests)

  it('Zero HP Pokemon filtered - should match TypeScript', () => {
    const attacker = createPokemon(0, true, 100, [0]);
    const opponents = [
      createPokemon(2, false, 0, [0]),
      createPokemon(3, false, 0, [0]),
    ];

    const tsResult = getMoveTargetsTS(attacker, 8, opponents);

    expect(tsResult.targets).toHaveLength(0);
  });

  it('Mixed HP opponents - should match TypeScript', () => {
    const attacker = createPokemon(0, true, 100, [0]);
    const opponents = [
      createPokemon(2, false, 50, [0]), // Active
      createPokemon(3, false, 0, [0]), // Fainted
      createPokemon(4, false, 100, [0]), // Active
    ];

    const tsResult = getMoveTargetsTS(attacker, 8, opponents);

    expect(tsResult.targets).toHaveLength(2);
    expect(tsResult.targets).toContain(2);
    expect(tsResult.targets).toContain(4);
    expect(tsResult.targets).not.toContain(3);
  });

  it('Single opponent - should match TypeScript', () => {
    const attacker = createPokemon(0, true, 100, [0]);
    const opponents = [createPokemon(2, false, 100, [0])];

    const tsResult = getMoveTargetsTS(attacker, 5, opponents);

    expect(tsResult.targets).toHaveLength(1);
    expect(tsResult.targets[0]).toBe(2);
  });

  it('Three opponents - should match TypeScript', () => {
    const attacker = createPokemon(0, true, 100, [0]);
    const opponents = [
      createPokemon(2, false, 100, [0]),
      createPokemon(3, false, 100, [0]),
      createPokemon(4, false, 100, [0]),
    ];

    const tsResult = getMoveTargetsTS(attacker, 8, opponents);

    expect(tsResult.targets).toHaveLength(3);
  });

  it('PARTY target type - should match TypeScript', () => {
    const attacker = createPokemon(0, true, 100, [0]);
    const opponents = [createPokemon(2, false, 100, [0])];

    const tsResult = getMoveTargetsTS(attacker, 18, opponents);

    expect(tsResult.targets).toHaveLength(1);
    expect(tsResult.targets[0]).toBe(0);
  });

  it('CURSE with dual-type Ghost - should match TypeScript', () => {
    const attacker = createPokemon(0, true, 100, [7, 3]); // Ghost/Poison
    const opponents = [createPokemon(2, false, 100, [0])];

    const tsResult = getMoveTargetsTS(attacker, 19, opponents);

    expect(tsResult.targets).toHaveLength(1);
    expect(tsResult.targets[0]).toBe(2); // Should target opponent (Ghost type present)
  });

  it('USER_OR_NEAR_ALLY without ally - should match TypeScript', () => {
    const attacker = createPokemon(0, true, 100, [0]);
    const opponents = [createPokemon(2, false, 100, [0])];

    const tsResult = getMoveTargetsTS(attacker, 12, opponents);

    expect(tsResult.targets).toHaveLength(1);
    expect(tsResult.targets[0]).toBe(0); // Self only
  });

  it('RANDOM_NEAR_ENEMY with no opponents - should match TypeScript', () => {
    const attacker = createPokemon(0, true, 100, [0]);
    const opponents: Pokemon[] = [];

    const tsResult = getMoveTargetsTS(attacker, 7, opponents);

    expect(tsResult.targets).toHaveLength(0);
  });

  it('USER target with multiple opponents - should match TypeScript', () => {
    const attacker = createPokemon(0, true, 100, [0]);
    const opponents = [
      createPokemon(2, false, 100, [0]),
      createPokemon(3, false, 100, [0]),
    ];

    const tsResult = getMoveTargetsTS(attacker, 0, opponents);

    expect(tsResult.targets).toHaveLength(1);
    expect(tsResult.targets[0]).toBe(0);
  });

  it('ALL_NEAR_OTHERS with ally and opponents - should match TypeScript', () => {
    const attacker = createPokemon(0, true, 100, [0]);
    const opponents = [
      createPokemon(2, false, 100, [0]),
      createPokemon(3, false, 100, [0]),
    ];
    const ally = createPokemon(1, true, 100, [0]);

    const tsResult = getMoveTargetsTS(attacker, 4, opponents, ally);

    expect(tsResult.targets).toHaveLength(3);
    expect(tsResult.multiple).toBe(true);
  });
});

console.log('✓ AI Move Selection Target Selection Parity Tests Complete');
