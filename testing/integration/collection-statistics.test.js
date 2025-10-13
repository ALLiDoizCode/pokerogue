/**
 * Collection Statistics Engine Integration Test Suite
 *
 * Validates collection-statistics-engine.lua process using aos-local framework
 *
 * Test Coverage:
 * - Calculate progress with completion percentages and milestones
 * - Generate comprehensive statistical metrics
 * - Create visualization data for charts
 * - Analyze trends and capture velocity
 * - Compare progress and calculate rankings
 * - Validate statistics data integrity
 * - Complete workflow: progress → statistics → visualization → analytics
 */

const AOLocal = require("aos-local");
const fs = require("fs");
const path = require("path");

// Load collection statistics process code
function loadCollectionStatisticsProcess() {
  const processPath = path.join(__dirname, "../../processes/collection-statistics-engine.lua");
  return fs.readFileSync(processPath, "utf8");
}

describe("Collection Statistics Integration Tests", () => {
  let process;

  beforeEach(() => {
    // Spawn new process for each test
    const processCode = loadCollectionStatisticsProcess();
    process = AOLocal.spawnProcess(processCode);
  });

  afterEach(() => {
    // Cleanup process
    if (process) {
      AOLocal.killProcess(process.id);
    }
  });

  test("Calculate progress with basic collection data", async () => {
    console.log("Test: Calculate Progress - Basic Collection");

    const dexData = {
      25: { seenAttr: 5, caughtAttr: 5, seenCount: 3, caughtCount: 1 }, // Pikachu
      150: { seenAttr: 3, caughtAttr: 0, seenCount: 1, caughtCount: 0 }, // Mewtwo
      1: { seenAttr: 5, caughtAttr: 5, seenCount: 2, caughtCount: 1 }, // Bulbasaur
    };

    const starterData = {
      25: { caughtAttr: 7 },
      1: { caughtAttr: 5 },
    };

    const result = await AOLocal.send(process, {
      Action: "CalculateProgress",
      Data: JSON.stringify({ dexData, starterData }),
    });

    expect(result.Action).toBe("SaveState");
    expect(result.Success).toBe("true");

    const data = JSON.parse(result.Data);
    expect(data.overall).toBeDefined();
    expect(data.overall.totalCaught).toBe(2);
    expect(data.overall.totalSeen).toBe(3);
    expect(data.overall.completionPercentage).toBeGreaterThanOrEqual(0);

    expect(data.milestones).toBeDefined();
    expect(data.milestones.first_catch).toBe(true);
    expect(data.milestones.pokedex_10).toBe(false);

    expect(data.starters).toBeDefined();
    expect(data.starters.unlockedCount).toBe(2);

    console.log("✅ Progress calculation validated");
  });

  test("Calculate regional completion tracking", async () => {
    console.log("Test: Regional Completion Tracking");

    // Create all Kanto Pokemon (1-151)
    const kantoDex = {};
    for (let i = 1; i <= 151; i++) {
      kantoDex[i.toString()] = {
        seenAttr: 5,
        caughtAttr: 5,
        seenCount: 1,
        caughtCount: 1,
      };
    }

    const result = await AOLocal.send(process, {
      Action: "CalculateProgress",
      Data: JSON.stringify({ dexData: kantoDex, starterData: {} }),
    });

    expect(result.Action).toBe("SaveState");
    expect(result.Success).toBe("true");

    const data = JSON.parse(result.Data);
    expect(data.regional).toBeDefined();
    expect(data.regional.kanto).toBeDefined();
    expect(data.regional.kanto.caught).toBe(151);
    expect(data.regional.kanto.percentage).toBe(100.0);

    expect(data.milestones.kanto_completion).toBe(true);

    console.log("✅ Regional completion tracking validated");
  });

  test("Generate comprehensive statistics", async () => {
    console.log("Test: Generate Statistics");

    const gameStats = {
      pokemonSeen: 450,
      pokemonCaught: 200,
      pokemonHatched: 50,
      legendaryPokemonSeen: 15,
      legendaryPokemonCaught: 5,
      shinyPokemonSeen: 8,
      shinyPokemonCaught: 3,
      battles: 1000,
      trainersDefeated: 50,
    };

    const captureData = {
      totalAttempts: 250,
      criticalCaptures: 25,
      escapeCount: 50,
    };

    const result = await AOLocal.send(process, {
      Action: "GenerateStatistics",
      Data: JSON.stringify({ gameStats, captureData }),
    });

    expect(result.Action).toBe("SaveState");
    expect(result.Success).toBe("true");

    const data = JSON.parse(result.Data);
    expect(data.captureStats).toBeDefined();
    expect(data.captureStats.totalAttempts).toBe(250);
    expect(data.captureStats.successfulCaptures).toBe(200);
    expect(data.captureStats.successRate).toBe(80.0);

    expect(data.encounterStats).toBeDefined();
    expect(data.encounterStats.totalEncounters).toBe(450);
    expect(data.encounterStats.shinyEncounters).toBe(8);

    expect(data.legendaryStats).toBeDefined();
    expect(data.sessionStats).toBeDefined();
    expect(data.battleStats).toBeDefined();
    expect(data.resourceStats).toBeDefined();

    console.log("✅ Statistics generation validated");
  });

  test("Generate visualization data for charts", async () => {
    console.log("Test: Visualization Data Generation");

    const progressData = {
      overall: { totalSeen: 450, totalCaught: 200, completionPercentage: 19.51 },
      regional: {
        kanto: { seen: 151, caught: 140, total: 151, percentage: 92.71 },
        johto: { seen: 80, caught: 50, total: 100, percentage: 50.0 },
      },
    };

    const statsData = {
      captureStats: {
        successfulCaptures: 200,
        escapeCount: 50,
      },
      legendaryStats: {
        shinyPokemonHatched: 5,
      },
    };

    const result = await AOLocal.send(process, {
      Action: "GetVisualizationData",
      Data: JSON.stringify({ progressData, statsData }),
    });

    expect(result.Action).toBe("SaveState");
    expect(result.Success).toBe("true");

    const data = JSON.parse(result.Data);
    expect(data.completionChart).toBeDefined();
    expect(data.completionChart.labels).toBeDefined();
    expect(data.completionChart.labels.length).toBe(2);
    expect(data.completionChart.values).toBeDefined();
    expect(data.completionChart.colors).toBeDefined();

    expect(data.statsChart).toBeDefined();
    expect(data.statsChart.labels.length).toBe(3);

    expect(data.captureChart).toBeDefined();
    expect(data.captureChart.type).toBe("pie");

    console.log("✅ Visualization data generation validated");
  });

  test("Analyze trends and calculate projections", async () => {
    console.log("Test: Trend Analysis");

    const historicalData = {
      dailyProgress: {
        "2025-01-01": { caught: 180 },
        "2025-01-08": { caught: 200 },
      },
      currentProgress: {
        totalCaught: 200,
      },
    };

    const result = await AOLocal.send(process, {
      Action: "AnalyzeTrends",
      Data: JSON.stringify({ historicalData, timeWindow: 7 }),
    });

    expect(result.Action).toBe("SaveState");
    expect(result.Success).toBe("true");

    const data = JSON.parse(result.Data);
    expect(data.captureVelocity).toBeDefined();
    expect(data.captureVelocity).toBeGreaterThanOrEqual(0);
    expect(data.progressTrend).toBeDefined();
    expect(data.insights).toBeDefined();
    expect(Array.isArray(data.insights)).toBe(true);

    console.log("✅ Trend analysis validated");
  });

  test("Compare progress and calculate rankings", async () => {
    console.log("Test: Progress Comparison");

    const playerData = {
      completionPercentage: 60.0,
    };

    const peerData = [
      { completionPercentage: 50.0 },
      { completionPercentage: 70.0 },
      { completionPercentage: 55.0 },
      { completionPercentage: 65.0 },
    ];

    const result = await AOLocal.send(process, {
      Action: "CompareProgress",
      Data: JSON.stringify({ playerData, peerData }),
    });

    expect(result.Action).toBe("SaveState");
    expect(result.Success).toBe("true");

    const data = JSON.parse(result.Data);
    expect(data.rank).toBe(3);
    expect(data.totalPeers).toBe(4);
    expect(data.percentile).toBeDefined();
    expect(data.averageCompletion).toBeDefined();
    expect(data.assessment).toBeDefined();

    console.log("✅ Progress comparison validated");
  });

  test("Validate statistics with valid data", async () => {
    console.log("Test: Statistics Validation - Valid Data");

    const validStats = {
      overall: {
        totalSeen: 450,
        totalCaught: 200,
        completionPercentage: 19.51,
      },
      captureStats: {
        totalAttempts: 250,
        successfulCaptures: 200,
        successRate: 80.0,
      },
      regional: {
        kanto: {
          seen: 151,
          caught: 140,
          percentage: 92.71,
        },
      },
    };

    const result = await AOLocal.send(process, {
      Action: "ValidateStatistics",
      Data: JSON.stringify({ statisticsData: validStats }),
    });

    expect(result.Action).toBe("SaveState");
    expect(result.Success).toBe("true");

    const data = JSON.parse(result.Data);
    expect(data.valid).toBe(true);
    expect(data.integrityScore).toBe(100.0);
    expect(data.errors.length).toBe(0);

    console.log("✅ Valid statistics validation passed");
  });

  test("Validate statistics with invalid data", async () => {
    console.log("Test: Statistics Validation - Invalid Data");

    const invalidStats = {
      overall: {
        totalSeen: 200,
        totalCaught: 450, // Invalid: caught > seen
        completionPercentage: 150.0, // Invalid: > 100%
      },
      captureStats: {
        successRate: 120.0, // Invalid: > 100%
      },
    };

    const result = await AOLocal.send(process, {
      Action: "ValidateStatistics",
      Data: JSON.stringify({ statisticsData: invalidStats }),
    });

    expect(result.Action).toBe("SaveState");
    expect(result.Success).toBe("true");

    const data = JSON.parse(result.Data);
    expect(data.valid).toBe(false);
    expect(data.errors.length).toBeGreaterThan(0);
    expect(data.integrityScore).toBe(0.0);

    console.log("✅ Invalid statistics validation passed");
  });

  test("Complete workflow: progress → statistics → visualization → analytics", async () => {
    console.log("Test: Complete Statistics Workflow");

    // Step 1: Calculate progress
    const dexData = {};
    for (let i = 1; i <= 50; i++) {
      dexData[i.toString()] = {
        seenAttr: 5,
        caughtAttr: 5,
        seenCount: 1,
        caughtCount: 1,
      };
    }

    const progressResult = await AOLocal.send(process, {
      Action: "CalculateProgress",
      Data: JSON.stringify({ dexData, starterData: {} }),
    });

    expect(progressResult.Success).toBe("true");
    const progressData = JSON.parse(progressResult.Data);

    // Step 2: Generate statistics
    const statsResult = await AOLocal.send(process, {
      Action: "GenerateStatistics",
      Data: JSON.stringify({
        gameStats: {
          pokemonSeen: 50,
          pokemonCaught: 50,
          pokemonHatched: 10,
        },
        captureData: {
          totalAttempts: 60,
          criticalCaptures: 5,
          escapeCount: 10,
        },
      }),
    });

    expect(statsResult.Success).toBe("true");
    const statsData = JSON.parse(statsResult.Data);

    // Step 3: Generate visualization
    const vizResult = await AOLocal.send(process, {
      Action: "GetVisualizationData",
      Data: JSON.stringify({ progressData, statsData }),
    });

    expect(vizResult.Success).toBe("true");
    const vizData = JSON.parse(vizResult.Data);
    expect(vizData.completionChart).toBeDefined();

    // Step 4: Analyze trends
    const trendsResult = await AOLocal.send(process, {
      Action: "AnalyzeTrends",
      Data: JSON.stringify({
        historicalData: {
          dailyProgress: {
            "2025-01-01": { caught: 30 },
            "2025-01-08": { caught: 50 },
          },
          currentProgress: { totalCaught: 50 },
        },
        timeWindow: 7,
      }),
    });

    expect(trendsResult.Success).toBe("true");
    const trendsData = JSON.parse(trendsResult.Data);
    expect(trendsData.captureVelocity).toBeDefined();

    console.log("✅ Complete workflow validated");
  });

  test("ADP v1.0 Info handler compliance", async () => {
    console.log("Test: ADP v1.0 Info Handler");

    const result = await AOLocal.send(process, {
      Action: "Info",
    });

    expect(result.Action).toBe("SaveState");
    expect(result.Success).toBe("true");

    const data = JSON.parse(result.Data);
    expect(data.process).toBeDefined();
    expect(data.process.name).toBe("Collection Statistics Engine");
    expect(data.process.adpVersion).toBe("1.0");
    expect(data.handlers).toBeDefined();
    expect(data.handlers.length).toBe(7);
    expect(data.schemas).toBeDefined();

    console.log("✅ ADP v1.0 compliance validated");
  });
});
