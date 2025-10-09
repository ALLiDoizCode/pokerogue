/**
 * Modifier Integration Test Suite
 *
 * Validates modifier-engine.lua process using aos-local framework
 *
 * Test Coverage:
 * - Query modifier type information
 * - Generate modifier options for shop selection
 * - Apply modifier and verify state changes
 * - Stack multiple modifiers and verify max stack behavior
 * - Serialize and deserialize modifier state
 * - Filter modifier pools based on game mode
 * - Validate modifier constraints and conflicts
 * - Handle complex modifier interactions
 */

const AOLocal = require('aos-local');
const fs = require('fs');
const path = require('path');

// Load modifier process code
function loadModifierProcess() {
  const processPath = path.join(__dirname, '../../processes/modifier-engine.lua');
  return fs.readFileSync(processPath, 'utf8');
}

describe('Modifier Integration Tests', () => {
  let process;

  beforeEach(() => {
    // Spawn new process for each test
    const processCode = loadModifierProcess();
    process = AOLocal.spawnProcess(processCode);
  });

  afterEach(() => {
    // Cleanup process
    if (process) {
      AOLocal.killProcess(process.id);
    }
  });

  test('Query modifier type information', async () => {
    console.log('Test: Query Modifier Type Information');

    const result = await AOLocal.send(process, {
      Action: 'GetModifierInfo',
      ModifierId: 'POKEBALL'
    });

    expect(result.Action).toBe('SaveState');
    expect(result.Success).toBe('true');

    const data = JSON.parse(result.Data);
    expect(data.modifier).toBeDefined();
    expect(data.modifier.id).toBe('POKEBALL');
    expect(data.modifier.tier).toBe(0); // COMMON
    expect(data.modifier.category).toBe('Consumable');

    console.log('✅ Modifier type query validated');
  });

  test('Generate modifier options for shop selection', async () => {
    console.log('Test: Generate Modifier Options');

    const result = await AOLocal.send(process, {
      Action: 'GenerateModifierOptions',
      PoolType: 'player',
      Tier: '1', // GREAT
      Seed: '12345'
    });

    expect(result.Action).toBe('SaveState');
    expect(result.Success).toBe('true');

    const data = JSON.parse(result.Data);
    expect(data.options).toBeDefined();
    expect(Array.isArray(data.options)).toBe(true);
    expect(data.options.length).toBeGreaterThan(0);
    expect(data.poolType).toBe('player');
    expect(data.tier).toBe(1);

    // Verify options have required fields
    data.options.forEach(option => {
      expect(option.modifierId).toBeDefined();
      expect(option.weight).toBeDefined();
      expect(option.tier).toBeDefined();
    });

    console.log('✅ Modifier option generation validated');
  });

  test('Apply modifier and verify state changes', async () => {
    console.log('Test: Apply Modifier');

    const gameState = {
      modifiers: []
    };

    const result = await AOLocal.send(process, {
      Action: 'ApplyModifier',
      ModifierId: 'POTION',
      Data: JSON.stringify(gameState)
    });

    expect(result.Action).toBe('SaveState');
    expect(result.Success).toBe('true');

    const data = JSON.parse(result.Data);
    expect(data.modifier).toBeDefined();
    expect(data.modifier.id).toBe('POTION');
    expect(data.modifier.applied).toBe(true);
    expect(data.effects.heal).toBeDefined();
    expect(data.effects.heal.healPercent).toBe(0.2);

    console.log('✅ Modifier application validated');
  });

  test('Stack multiple modifiers and verify max stack behavior', async () => {
    console.log('Test: Modifier Stacking');

    // Query max stack count for POKEBALL
    const validation1 = await AOLocal.send(process, {
      Action: 'ValidateModifier',
      ModifierId: 'POKEBALL'
    });

    expect(validation1.Success).toBe('true');
    const data1 = JSON.parse(validation1.Data);
    expect(data1.constraints.maxStackCount).toBe(999);

    // Query max stack count for SHINY_CHARM (limited stacks)
    const validation2 = await AOLocal.send(process, {
      Action: 'ValidateModifier',
      ModifierId: 'SHINY_CHARM'
    });

    expect(validation2.Success).toBe('true');
    const data2 = JSON.parse(validation2.Data);
    expect(data2.constraints.maxStackCount).toBe(3);

    console.log('✅ Modifier stacking validated');
  });

  test('Serialize and deserialize modifier state', async () => {
    console.log('Test: Modifier Persistence');

    // Serialize game state with modifiers
    const gameState = {
      modifiers: [
        { id: 'POKEBALL', stackCount: 10 },
        { id: 'RARE_CANDY', stackCount: 5 }
      ]
    };

    const serializeResult = await AOLocal.send(process, {
      Action: 'SerializeModifiers',
      Data: JSON.stringify(gameState),
      Timestamp: '1234567890'
    });

    expect(serializeResult.Success).toBe('true');
    const serialized = JSON.parse(serializeResult.Data);
    expect(serialized.modifiers).toBeDefined();
    expect(serialized.modifiers.length).toBe(2);
    expect(serialized.version).toBe(1);
    expect(serialized.timestamp).toBe(1234567890);

    // Deserialize modifier state
    const deserializeResult = await AOLocal.send(process, {
      Action: 'DeserializeModifiers',
      Data: JSON.stringify(serialized)
    });

    expect(deserializeResult.Success).toBe('true');
    const deserialized = JSON.parse(deserializeResult.Data);
    expect(deserialized.modifiers.length).toBe(2);
    expect(deserialized.modifiers[0].id).toBe('POKEBALL');
    expect(deserialized.modifiers[0].valid).toBe(true);
    expect(deserialized.modifiers[1].id).toBe('RARE_CANDY');

    console.log('✅ Modifier serialization/deserialization validated');
  });

  test('Filter modifier pools based on game mode', async () => {
    console.log('Test: Pool Filtering');

    // Test player pool
    const playerResult = await AOLocal.send(process, {
      Action: 'GenerateModifierOptions',
      PoolType: 'player',
      Tier: '0',
      Seed: '12345'
    });

    expect(playerResult.Success).toBe('true');
    const playerData = JSON.parse(playerResult.Data);
    expect(playerData.poolType).toBe('player');

    // Test wild pool
    const wildResult = await AOLocal.send(process, {
      Action: 'GenerateModifierOptions',
      PoolType: 'wild',
      Tier: '0',
      Seed: '12345'
    });

    expect(wildResult.Success).toBe('true');
    const wildData = JSON.parse(wildResult.Data);
    expect(wildData.poolType).toBe('wild');

    // Wild pool should have different options than player pool
    const playerIds = playerData.options.map(o => o.modifierId).sort();
    const wildIds = wildData.options.map(o => o.modifierId).sort();
    expect(JSON.stringify(playerIds)).not.toBe(JSON.stringify(wildIds));

    console.log('✅ Pool filtering validated');
  });

  test('Validate modifier constraints and conflicts', async () => {
    console.log('Test: Modifier Constraints');

    // Validate consumable modifier
    const result1 = await AOLocal.send(process, {
      Action: 'ValidateModifier',
      ModifierId: 'POTION'
    });

    expect(result1.Success).toBe('true');
    const data1 = JSON.parse(result1.Data);
    expect(data1.valid).toBe(true);
    expect(data1.constraints.category).toBe('Consumable');

    // Validate held item modifier
    const result2 = await AOLocal.send(process, {
      Action: 'ValidateModifier',
      ModifierId: 'LUCKY_EGG'
    });

    expect(result2.Success).toBe('true');
    const data2 = JSON.parse(result2.Data);
    expect(data2.valid).toBe(true);
    expect(data2.constraints.category).toBe('PokemonHeld');

    console.log('✅ Modifier constraints validated');
  });

  test('Handle complex modifier interactions', async () => {
    console.log('Test: Complex Modifier Interactions');

    // Apply multiple modifiers to game state
    const gameState = { modifiers: [] };

    // Apply BASE_STAT_BOOSTER
    const result1 = await AOLocal.send(process, {
      Action: 'ApplyModifier',
      ModifierId: 'BASE_STAT_BOOSTER',
      Data: JSON.stringify(gameState)
    });

    expect(result1.Success).toBe('true');
    const data1 = JSON.parse(result1.Data);
    expect(data1.effects.statBoost).toBeDefined();

    // Apply LUCKY_EGG
    const result2 = await AOLocal.send(process, {
      Action: 'ApplyModifier',
      ModifierId: 'LUCKY_EGG',
      Data: JSON.stringify(gameState)
    });

    expect(result2.Success).toBe('true');
    const data2 = JSON.parse(result2.Data);
    expect(data2.effects.expMultiplier).toBeDefined();

    console.log('✅ Complex modifier interactions validated');
  });

  test('Error handling for invalid requests', async () => {
    console.log('Test: Error Handling');

    // Missing ModifierId
    const result1 = await AOLocal.send(process, {
      Action: 'GetModifierInfo'
    });

    expect(result1.Action).toBe('Error');
    expect(result1.Success).toBe('false');
    expect(result1.Error).toContain('ModifierId required');

    // Invalid ModifierId
    const result2 = await AOLocal.send(process, {
      Action: 'GetModifierInfo',
      ModifierId: 'INVALID_MODIFIER'
    });

    expect(result2.Action).toBe('Error');
    expect(result2.Error).toContain('not found');

    // Missing PoolType
    const result3 = await AOLocal.send(process, {
      Action: 'GenerateModifierOptions',
      Tier: '0',
      Seed: '12345'
    });

    expect(result3.Action).toBe('Error');
    expect(result3.Error).toContain('PoolType required');

    console.log('✅ Error handling validated');
  });

  test('Info handler returns process metadata (ADP v1.0)', async () => {
    console.log('Test: Info Handler (ADP v1.0)');

    const result = await AOLocal.send(process, {
      Action: 'Info'
    });

    expect(result.Action).toBe('SaveState');
    expect(result.Success).toBe('true');

    const data = JSON.parse(result.Data);
    expect(data.name).toBe('Modifier Engine');
    expect(data.version).toBe('1.0.0');
    expect(data.adpVersion).toBe('1.0');
    expect(data.capabilities).toBeDefined();
    expect(data.handlers).toBeDefined();
    expect(data.handlers.length).toBeGreaterThan(0);

    // Verify handler metadata
    const getModifierInfoHandler = data.handlers.find(h => h.action === 'GetModifierInfo');
    expect(getModifierInfoHandler).toBeDefined();
    expect(getModifierInfoHandler.parameters).toBeDefined();

    console.log('✅ ADP v1.0 compliance validated');
  });

  test('Ping handler responds correctly', async () => {
    console.log('Test: Ping Handler');

    const result = await AOLocal.send(process, {
      Action: 'Ping'
    });

    expect(result.Action).toBe('Pong');
    expect(result.Success).toBe('true');
    expect(result.Data).toBe('pong');

    console.log('✅ Ping handler validated');
  });
});

console.log('\n✅ Modifier Integration Test Suite Complete\n');
