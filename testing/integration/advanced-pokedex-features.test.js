/**
 * Integration Tests: Advanced Pokedex Features Engine
 *
 * Tests complete workflows using aos-local framework.
 * Validates message flow, response structure, and error handling.
 */

const AoLoader = require("@permaweb/ao-loader");
const fs = require("fs");
const path = require("path");

// Load process file
const processPath = path.join(__dirname, "../../processes/advanced-pokedex-features-engine.lua");
const processSource = fs.readFileSync(processPath, "utf-8");

describe("Advanced Pokedex Features Engine - Integration Tests", () => {
  let handle;
  const processId = "test-advanced-pokedex-integration";

  beforeAll(async () => {
    // Initialize AO loader
    handle = await AoLoader(null, {
      format: "wasm64-unknown-emscripten-draft_2024_02_15",
      inputEncoding: "JSON-1",
      outputEncoding: "JSON-1",
      memoryLimit: "524288000", // 500 MB
      computeLimit: "9000000000000",
      extensions: [],
    });

    // Load the process
    const result = await handle({
      Id: processId + "#0",
      Owner: "test-owner",
      Target: processId,
      From: "test-owner",
      Module: "test-module",
      "Block-Height": "1000",
      Timestamp: Date.now().toString(),
      Tags: [{ name: "Action", value: "Eval" }],
      Data: processSource,
    });

    if (result.Error) {
      throw new Error("Failed to load process: " + result.Error);
    }
  });

  /**
   * Integration Test 1: Complete Search Workflow
   * Query → Filter → Sort → Results
   */
  test("Complete search workflow (query → filter → sort)", async () => {
    // Step 1: Perform search
    const searchResult = await handle({
      Id: processId + "#1",
      Owner: "test-owner",
      Target: processId,
      From: "test-owner",
      Timestamp: Date.now().toString(),
      Tags: [{ name: "Action", value: "SearchPokedex" }],
      Data: JSON.stringify({
        textSearch: {
          name: "Pikachu",
        },
      }),
    });

    expect(searchResult.Messages).toBeDefined();
    expect(searchResult.Messages.length).toBeGreaterThan(0);

    const searchResponse = searchResult.Messages[0];
    expect(searchResponse.Tags.find(t => t.name === "Action")?.value).toBe("SaveState");
    expect(searchResponse.Tags.find(t => t.name === "Success")?.value).toBe("true");

    const searchData = JSON.parse(searchResponse.Data);
    expect(searchData.species).toBeDefined();
    expect(searchData.species.length).toBeGreaterThan(0);
    expect(searchData.species[0].name).toBe("Pikachu");
  });

  /**
   * Integration Test 2: Multi-filter Application
   */
  test("Multi-filter application with result verification", async () => {
    const filterResult = await handle({
      Id: processId + "#2",
      Owner: "test-owner",
      Target: processId,
      From: "test-owner",
      Timestamp: Date.now().toString(),
      Tags: [{ name: "Action", value: "ApplyFilters" }],
      Data: JSON.stringify({
        filters: {
          generation: [1],
          types: [13], // Electric
        },
      }),
    });

    expect(filterResult.Messages).toBeDefined();

    const filterResponse = filterResult.Messages[0];
    const filterData = JSON.parse(filterResponse.Data);

    expect(filterData.filteredSpecies).toBeDefined();
    expect(filterData.appliedFilters).toBeDefined();
    expect(filterData.appliedFilters.generation).toEqual([1]);
  });

  /**
   * Integration Test 3: Export Functionality
   */
  test("Export functionality with data validation (JSON)", async () => {
    const exportResult = await handle({
      Id: processId + "#3",
      Owner: "test-owner",
      Target: processId,
      From: "test-owner",
      Timestamp: Date.now().toString(),
      Tags: [{ name: "Action", value: "ExportData" }],
      Data: JSON.stringify({
        format: "JSON",
        species: [{ speciesId: 25, name: "Pikachu", generation: 1 }],
        columns: ["speciesId", "name", "generation"],
      }),
    });

    expect(exportResult.Messages).toBeDefined();

    const exportResponse = exportResult.Messages[0];
    const exportData = JSON.parse(exportResponse.Data);

    expect(exportData.format).toBe("JSON");
    expect(exportData.data).toBeDefined();
    expect(exportData.metadata).toBeDefined();
    expect(exportData.metadata.totalRecords).toBe(1);

    // Verify exported data is valid JSON
    const parsedExport = JSON.parse(exportData.data);
    expect(parsedExport.totalRecords).toBe(1);
    expect(parsedExport.data.length).toBe(1);
  });

  /**
   * Integration Test 4: Error Handling
   */
  test("Error handling for invalid inputs", async () => {
    const errorResult = await handle({
      Id: processId + "#4",
      Owner: "test-owner",
      Target: processId,
      From: "test-owner",
      Timestamp: Date.now().toString(),
      Tags: [{ name: "Action", value: "SearchPokedex" }],
      Data: "", // Missing data (should error)
    });

    expect(errorResult.Messages).toBeDefined();

    const errorResponse = errorResult.Messages[0];
    expect(errorResponse.Tags.find(t => t.name === "Action")?.value).toBe("Error");
    expect(errorResponse.Tags.find(t => t.name === "ErrorCode")?.value).toBe("INVALID_SEARCH_QUERY");
  });

  /**
   * Integration Test 5: GetVisualization Complete Data
   */
  test("GetVisualization returns complete species data", async () => {
    const vizResult = await handle({
      Id: processId + "#5",
      Owner: "test-owner",
      Target: processId,
      From: "test-owner",
      Timestamp: Date.now().toString(),
      Tags: [
        { name: "Action", value: "GetVisualization" },
        { name: "SpeciesId", value: "25" },
      ],
      Data: "",
    });

    expect(vizResult.Messages).toBeDefined();

    const vizResponse = vizResult.Messages[0];
    const vizData = JSON.parse(vizResponse.Data);

    expect(vizData.speciesId).toBe(25);
    expect(vizData.name).toBe("Pikachu");
    expect(vizData.types).toBeDefined();
    expect(vizData.types.primary).toBeDefined();
    expect(vizData.stats).toBeDefined();
    expect(vizData.abilities).toBeDefined();
    expect(vizData.moves).toBeDefined();
    expect(vizData.forms).toBeDefined();
  });

  /**
   * Integration Test 6: Analytics Tracking
   */
  test("Analytics tracking across multiple searches", async () => {
    // Perform several searches
    await handle({
      Id: processId + "#6",
      Owner: "test-owner",
      Target: processId,
      From: "test-owner",
      Timestamp: Date.now().toString(),
      Tags: [{ name: "Action", value: "SearchPokedex" }],
      Data: JSON.stringify({ textSearch: { name: "Pikachu" } }),
    });

    await handle({
      Id: processId + "#7",
      Owner: "test-owner",
      Target: processId,
      From: "test-owner",
      Timestamp: Date.now().toString(),
      Tags: [{ name: "Action", value: "SearchPokedex" }],
      Data: JSON.stringify({ textSearch: { name: "Charizard" } }),
    });

    // Get analytics
    const analyticsResult = await handle({
      Id: processId + "#8",
      Owner: "test-owner",
      Target: processId,
      From: "test-owner",
      Timestamp: Date.now().toString(),
      Tags: [{ name: "Action", value: "GetAnalytics" }],
      Data: "",
    });

    const analyticsResponse = analyticsResult.Messages[0];
    const analyticsData = JSON.parse(analyticsResponse.Data);

    expect(analyticsData.searchHistory).toBeDefined();
    expect(analyticsData.sessionStats).toBeDefined();
    expect(analyticsData.sessionStats.totalSearches).toBeGreaterThan(0);
  });
});

console.log("\n✅ All integration tests configured for aos-local execution");
