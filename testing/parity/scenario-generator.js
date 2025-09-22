/**
 * Test Scenario Generator for Parity Testing
 * Generates comprehensive test scenarios covering all game mechanics
 */

import fs from "fs/promises";
import path from "path";

export class ScenarioGenerator {
  constructor(outputDir = "./testing/parity/scenarios") {
    this.outputDir = outputDir;
    this.scenarios = [];
  }

  /**
   * Generate all test scenarios
   */
  async generateAllScenarios() {
    console.log("Generating comprehensive test scenarios...");

    // Game mechanic categories
    await this.generateBattleScenarios();
    await this.generatePokemonMechanicScenarios();
    await this.generateStatusEffectScenarios();
    await this.generateEvolutionScenarios();
    await this.generateCaptureScenarios();
    await this.generateStatCalculationScenarios();

    // Save all scenarios
    await this.saveScenarios();

    console.log(`Generated ${this.scenarios.length} test scenarios`);
    return this.scenarios;
  }

  /**
   * Generate battle-related test scenarios
   */
  async generateBattleScenarios() {
    // Basic damage calculation scenarios
    this.scenarios.push({
      id: "battle-damage-basic",
      name: "Basic Damage Calculation",
      category: "battle",
      description: "Standard damage calculation without modifiers",
      inputGameState: {
        battle: {
          attacker: {
            species: "Charizard",
            level: 50,
            stats: { attack: 134 },
            types: ["Fire", "Flying"],
          },
          defender: {
            species: "Blastoise",
            level: 50,
            stats: { defense: 120 },
            types: ["Water"],
          },
          move: {
            name: "Flamethrower",
            type: "Fire",
            power: 90,
            category: "Special",
            accuracy: 100,
          },
          field: {
            weather: "none",
            terrain: "none",
          },
        },
        rng: {
          seed: "test-seed-001",
          damageRoll: 0.85, // Fixed roll for deterministic testing
        },
      },
      expectedOutput: {
        damage: 127,
        effectiveness: "not_very_effective",
        critical: false,
        accuracy: true,
      },
      tolerances: {
        damage: 1,
      },
      validationRules: [
        "damage must be positive integer",
        "effectiveness must match type chart",
        "critical must be boolean",
      ],
    });

    // Type effectiveness scenarios
    this.scenarios.push({
      id: "battle-type-effectiveness",
      name: "Type Effectiveness Matrix",
      category: "battle",
      description: "Test all type effectiveness combinations",
      inputGameState: {
        typeMatchups: [
          { attacking: "Fire", defending: "Grass", expected: 2.0 },
          { attacking: "Water", defending: "Fire", expected: 2.0 },
          { attacking: "Electric", defending: "Water", expected: 2.0 },
          { attacking: "Electric", defending: "Ground", expected: 0.0 },
          { attacking: "Normal", defending: "Ghost", expected: 0.0 },
          { attacking: "Fighting", defending: "Normal", expected: 2.0 },
        ],
      },
      expectedOutput: {
        allCorrect: true,
        mismatches: [],
      },
      tolerances: {},
      validationRules: [
        "effectiveness values must be 0, 0.25, 0.5, 1.0, 2.0, or 4.0",
        "dual type calculations must compound correctly",
      ],
    });

    // Critical hit scenarios
    this.scenarios.push({
      id: "battle-critical-hits",
      name: "Critical Hit Calculation",
      category: "battle",
      description: "Test critical hit probability and damage multipliers",
      inputGameState: {
        pokemon: {
          species: "Alakazam",
          level: 50,
          moves: ["Psychic"],
          criticalStage: 0,
        },
        move: {
          name: "Psychic",
          criticalRatio: 1, // 1/24 base rate
        },
        testIterations: 1000,
      },
      expectedOutput: {
        criticalRate: 0.0417, // ~4.17% for stage 0
        damageMultiplier: 1.5,
      },
      tolerances: {
        criticalRate: 0.01, // ±1% tolerance
      },
      requiresStatisticalAnalysis: true,
      statisticalRequirements: {
        minIterations: 1000,
        confidenceLevel: 0.95,
      },
    });
  }

  /**
   * Generate Pokemon mechanic scenarios
   */
  async generatePokemonMechanicScenarios() {
    // Stat calculation scenarios
    this.scenarios.push({
      id: "pokemon-stat-calculation",
      name: "Pokemon Stat Calculation",
      category: "pokemon",
      description: "Test complete stat calculation formula with all modifiers",
      inputGameState: {
        pokemon: {
          species: "Garchomp",
          level: 100,
          nature: "Jolly", // +Speed, -SpAttack
          ivs: {
            hp: 31,
            attack: 31,
            defense: 31,
            spAttack: 0,
            spDefense: 31,
            speed: 31,
          },
          evs: {
            hp: 0,
            attack: 252,
            defense: 4,
            spAttack: 0,
            spDefense: 0,
            speed: 252,
          },
          baseStats: {
            hp: 108,
            attack: 130,
            defense: 95,
            spAttack: 80,
            spDefense: 85,
            speed: 102,
          },
        },
      },
      expectedOutput: {
        stats: {
          hp: 415,
          attack: 394,
          defense: 216,
          spAttack: 176,
          spDefense: 206,
          speed: 350,
        },
      },
      tolerances: {},
      validationRules: [
        "HP calculation uses different formula than other stats",
        "Nature modifiers must be exactly 0.9, 1.0, or 1.1",
        "All stats must use Math.floor for final values",
      ],
    });

    // Nature modifier scenarios
    this.scenarios.push({
      id: "pokemon-nature-modifiers",
      name: "Nature Stat Modifiers",
      category: "pokemon",
      description: "Test all nature combinations and stat modifications",
      inputGameState: {
        natureTests: [
          { nature: "Hardy", boosted: null, reduced: null },
          { nature: "Adamant", boosted: "attack", reduced: "spAttack" },
          { nature: "Modest", boosted: "spAttack", reduced: "attack" },
          { nature: "Timid", boosted: "speed", reduced: "attack" },
          { nature: "Bold", boosted: "defense", reduced: "attack" },
        ],
        basePokemon: {
          species: "Alakazam",
          level: 50,
          ivs: { attack: 31, spAttack: 31, speed: 31, defense: 31 },
          evs: { attack: 0, spAttack: 0, speed: 0, defense: 0 },
        },
      },
      expectedOutput: {
        modifierValues: {
          neutral: 1.0,
          boosted: 1.1,
          reduced: 0.9,
        },
        allNaturesValid: true,
      },
      tolerances: {},
      validationRules: [
        "Neutral natures affect no stats",
        "Boosted stats get exactly 1.1x multiplier",
        "Reduced stats get exactly 0.9x multiplier",
      ],
    });
  }

  /**
   * Generate status effect scenarios
   */
  async generateStatusEffectScenarios() {
    this.scenarios.push({
      id: "status-burn-damage",
      name: "Burn Status Effect",
      category: "status",
      description: "Test burn damage calculation and attack reduction",
      inputGameState: {
        pokemon: {
          species: "Charizard",
          level: 50,
          maxHp: 153,
          currentHp: 153,
          status: "burn",
          stats: { attack: 134 },
        },
        turnCount: 5,
      },
      expectedOutput: {
        damagePerTurn: 19, // 1/8 of max HP
        attackReduction: 0.5, // 50% attack reduction
        totalDamage: 95, // 5 turns of burn damage
      },
      tolerances: {
        damagePerTurn: 1,
      },
      validationRules: [
        "Burn damage is 1/8 of max HP per turn",
        "Attack is reduced by 50% while burned",
        "Burn damage cannot reduce HP below 1",
      ],
    });

    this.scenarios.push({
      id: "status-paralysis-speed",
      name: "Paralysis Speed Reduction",
      category: "status",
      description: "Test paralysis speed reduction and action chance",
      inputGameState: {
        pokemon: {
          species: "Pikachu",
          level: 50,
          status: "paralysis",
          stats: { speed: 120 },
        },
        actionAttempts: 1000,
      },
      expectedOutput: {
        speedReduction: 0.25, // 75% speed reduction
        actionSuccessRate: 0.75, // 25% chance to be fully paralyzed
        effectiveSpeed: 30,
      },
      tolerances: {
        actionSuccessRate: 0.05, // ±5% tolerance for randomness
      },
      requiresStatisticalAnalysis: true,
      statisticalRequirements: {
        minIterations: 1000,
        confidenceLevel: 0.95,
      },
    });
  }

  /**
   * Generate evolution scenarios
   */
  async generateEvolutionScenarios() {
    this.scenarios.push({
      id: "evolution-level-up",
      name: "Level-based Evolution",
      category: "evolution",
      description: "Test level-based evolution triggers and stat changes",
      inputGameState: {
        pokemon: {
          species: "Charmeleon",
          level: 35,
          experience: 42875, // Experience for level 35
        },
        expGain: 1000,
      },
      expectedOutput: {
        shouldEvolve: true,
        newSpecies: "Charizard",
        newLevel: 36,
        statIncrease: true,
      },
      tolerances: {},
      validationRules: [
        "Evolution must trigger at exact level threshold",
        "Stats must be recalculated for new species",
        "Experience must be preserved through evolution",
      ],
    });

    this.scenarios.push({
      id: "evolution-stone",
      name: "Stone-based Evolution",
      category: "evolution",
      description: "Test evolution triggered by evolutionary stones",
      inputGameState: {
        pokemon: {
          species: "Pikachu",
          level: 25,
        },
        item: "Thunder Stone",
      },
      expectedOutput: {
        shouldEvolve: true,
        newSpecies: "Raichu",
        levelRequirement: false, // No level requirement for stone evolution
      },
      tolerances: {},
      validationRules: [
        "Stone evolution ignores level requirements",
        "Item must be consumed during evolution",
        "Species must change to correct evolution",
      ],
    });
  }

  /**
   * Generate capture scenarios
   */
  async generateCaptureScenarios() {
    this.scenarios.push({
      id: "capture-pokeball-rates",
      name: "Pokeball Capture Rates",
      category: "capture",
      description: "Test capture probability calculations for different Pokeballs",
      inputGameState: {
        wildPokemon: {
          species: "Pidgey",
          level: 5,
          currentHp: 20,
          maxHp: 20,
          status: "none",
          catchRate: 255, // Pidgey's catch rate
        },
        pokeballs: [
          { type: "Pokeball", modifier: 1.0 },
          { type: "Great Ball", modifier: 1.5 },
          { type: "Ultra Ball", modifier: 2.0 },
          { type: "Master Ball", modifier: 255.0 },
        ],
        attempts: 1000,
      },
      expectedOutput: {
        captureRates: {
          Pokeball: 0.85,
          "Great Ball": 0.91,
          "Ultra Ball": 0.95,
          "Master Ball": 1.0,
        },
      },
      tolerances: {
        captureRates: 0.05, // ±5% tolerance
      },
      requiresStatisticalAnalysis: true,
      statisticalRequirements: {
        minIterations: 1000,
        confidenceLevel: 0.95,
      },
    });
  }

  /**
   * Generate stat calculation edge cases
   */
  async generateStatCalculationScenarios() {
    this.scenarios.push({
      id: "stats-edge-cases",
      name: "Stat Calculation Edge Cases",
      category: "pokemon",
      description: "Test edge cases in stat calculations",
      inputGameState: {
        edgeCases: [
          {
            name: "Level 1 Pokemon",
            pokemon: { species: "Shedinja", level: 1, ivs: { hp: 31 }, evs: { hp: 0 } },
            expectedHp: 1, // Shedinja always has 1 HP
          },
          {
            name: "Maximum stats",
            pokemon: {
              species: "Shuckle",
              level: 100,
              nature: "Bold",
              ivs: { defense: 31 },
              evs: { defense: 252 },
            },
            expectedDefense: 614, // Maximum possible Defense stat
          },
          {
            name: "Minimum stats",
            pokemon: {
              species: "Abra",
              level: 50,
              nature: "Modest",
              ivs: { attack: 0 },
              evs: { attack: 0 },
            },
            expectedAttack: 22, // Minimum Attack for Abra
          },
        ],
      },
      expectedOutput: {
        allEdgeCasesCorrect: true,
        calculations: [],
      },
      tolerances: {},
      validationRules: [
        "Shedinja HP is always 1 regardless of calculation",
        "Stats cannot exceed species maximum bounds",
        "Stats cannot be less than species minimum bounds",
      ],
    });
  }

  /**
   * Save all generated scenarios to files
   */
  async saveScenarios() {
    await fs.mkdir(this.outputDir, { recursive: true });

    for (const scenario of this.scenarios) {
      const filename = `${scenario.id}.json`;
      const filepath = path.join(this.outputDir, filename);
      await fs.writeFile(filepath, JSON.stringify(scenario, null, 2));
    }

    // Create scenario index
    const index = {
      generated: new Date().toISOString(),
      total: this.scenarios.length,
      categories: this.getScenarioCategories(),
      scenarios: this.scenarios.map(s => ({
        id: s.id,
        name: s.name,
        category: s.category,
        requiresStatisticalAnalysis: s.requiresStatisticalAnalysis || false,
      })),
    };

    await fs.writeFile(path.join(this.outputDir, "index.json"), JSON.stringify(index, null, 2));
  }

  /**
   * Get scenario categories and counts
   */
  getScenarioCategories() {
    const categories = {};
    for (const scenario of this.scenarios) {
      if (!categories[scenario.category]) {
        categories[scenario.category] = 0;
      }
      categories[scenario.category]++;
    }
    return categories;
  }
}

// Export for use in other modules
export { ScenarioGenerator };
