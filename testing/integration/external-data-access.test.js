/**
 * External Data Access Tests
 * Testing external data fetching patterns and caching behavior
 */

import fs from "fs/promises";
import path from "path";
import { afterAll, beforeAll, describe, expect, test } from "@jest/globals";
import { IntegrationEnvironmentConfig } from "../../development-tools/integration-testing/environment-config.js";
import { AoliteFramework } from "../aolite/aolite-framework.js";
import { ProcessDeployer } from "../aos-local/process-deployer.js";

describe("External Data Access Tests", () => {
  let aoliteFramework;
  let processDeployer;
  let environmentConfig;
  let tempDir;
  let _mockDataSources;
  let dataProcesses;

  beforeAll(async () => {
    // Setup test environment
    tempDir = path.join(process.cwd(), "testing/aos-local/temp", `external-data-test-${Date.now()}`);
    await fs.mkdir(tempDir, { recursive: true });

    // Initialize components
    environmentConfig = new IntegrationEnvironmentConfig({
      workspaceDir: tempDir,
    });

    aoliteFramework = new AoliteFramework();
    processDeployer = new ProcessDeployer({
      tempDir,
      processesDir: path.join(process.cwd(), "processes"),
    });

    // Initialize environment
    await environmentConfig.initializeEnvironment();
    await aoliteFramework.initialize();
    await processDeployer.initialize();

    // Create mock data sources and processes
    _mockDataSources = await createMockDataSources();
    dataProcesses = await deployDataAccessProcesses();
  });

  afterAll(async () => {
    // Cleanup
    await processDeployer?.cleanup();
    await aoliteFramework?.cleanup();
    await environmentConfig?.cleanup();

    // Remove temp directory
    try {
      await fs.rm(tempDir, { recursive: true, force: true });
    } catch (error) {
      console.warn(`Warning: Could not remove temp directory: ${error.message}`);
    }
  });

  describe("Mock Arweave Data Fetching", () => {
    test("should simulate Arweave transaction data retrieval", async () => {
      const dataProcessor = dataProcesses.get("external-data-processor");
      expect(dataProcessor).toBeDefined();

      // Simulate fetching Pokemon species data from "Arweave"
      const response = await aoliteFramework.sendMessage(dataProcessor.processId, {
        Action: "FetchArweaveData",
        Data: {
          transactionId: "mock_species_transaction_123",
          dataType: "pokemon_species",
          speciesId: 1,
        },
      });

      expect(response.success).toBe(true);
      expect(response.data).toBeDefined();
      expect(response.data.source).toBe("arweave_simulation");
      expect(response.data.transactionId).toBe("mock_species_transaction_123");
      expect(response.data.speciesData).toBeDefined();
      expect(response.data.speciesData.name).toBe("Bulbasaur");
    }, 10000);

    test("should handle Arweave data fetching failures gracefully", async () => {
      const dataProcessor = dataProcesses.get("external-data-processor");

      // Simulate failed transaction fetch
      const response = await aoliteFramework.sendMessage(dataProcessor.processId, {
        Action: "FetchArweaveData",
        Data: {
          transactionId: "invalid_transaction_id",
          dataType: "pokemon_species",
          speciesId: 999,
        },
      });

      expect(response.success).toBe(true); // Process should handle errors gracefully
      expect(response.data.error).toBeDefined();
      expect(response.data.fallbackUsed).toBe(true);
      expect(response.data.source).toBe("embedded_fallback");
    }, 10000);

    test("should validate external data integrity", async () => {
      const dataProcessor = dataProcesses.get("external-data-processor");

      // Fetch data and validate its structure
      const response = await aoliteFramework.sendMessage(dataProcessor.processId, {
        Action: "FetchAndValidateData",
        Data: {
          transactionId: "mock_moves_transaction_456",
          dataType: "move_data",
          moveId: 1,
        },
      });

      expect(response.success).toBe(true);
      expect(response.data.validationResult).toBeDefined();
      expect(response.data.validationResult.isValid).toBe(true);
      expect(response.data.validationResult.schema).toBe("move_data_v1");
      expect(response.data.moveData).toBeDefined();
      expect(response.data.moveData.name).toBe("Pound");
    }, 10000);

    test("should measure external data fetch performance", async () => {
      const dataProcessor = dataProcesses.get("external-data-processor");

      // Test multiple data fetches and measure performance
      const fetchPromises = Array.from({ length: 5 }, (_, i) =>
        aoliteFramework.sendMessage(dataProcessor.processId, {
          Action: "FetchArweaveDataWithMetrics",
          Data: {
            transactionId: `mock_transaction_${i + 1}`,
            dataType: "pokemon_species",
            speciesId: i + 1,
          },
        }),
      );

      const responses = await Promise.all(fetchPromises);

      // Verify all fetches succeeded
      expect(responses.every(r => r.success)).toBe(true);

      // Check performance metrics
      const totalFetchTime = responses.reduce((sum, r) => sum + (r.data.fetchTime || 0), 0);
      const averageFetchTime = totalFetchTime / responses.length;

      expect(averageFetchTime).toBeLessThan(500); // Should be under 500ms average (simulated)
      expect(responses.every(r => r.data.fetchTime > 0)).toBe(true);
    }, 15000);
  });

  describe("Data Caching Behavior", () => {
    test("should implement effective caching for frequently accessed data", async () => {
      const cacheProcessor = dataProcesses.get("cache-manager");
      expect(cacheProcessor).toBeDefined();

      // First fetch - should miss cache
      const firstResponse = await aoliteFramework.sendMessage(cacheProcessor.processId, {
        Action: "GetCachedData",
        Data: {
          key: "species_1",
          dataType: "pokemon_species",
          speciesId: 1,
        },
      });

      expect(firstResponse.success).toBe(true);
      expect(firstResponse.data.cacheHit).toBe(false);
      expect(firstResponse.data.source).toBe("external_fetch");

      // Second fetch - should hit cache
      const secondResponse = await aoliteFramework.sendMessage(cacheProcessor.processId, {
        Action: "GetCachedData",
        Data: {
          key: "species_1",
          dataType: "pokemon_species",
          speciesId: 1,
        },
      });

      expect(secondResponse.success).toBe(true);
      expect(secondResponse.data.cacheHit).toBe(true);
      expect(secondResponse.data.source).toBe("cache");
      expect(secondResponse.data.fetchTime).toBeLessThan(firstResponse.data.fetchTime);
    }, 12000);

    test("should handle cache expiration and refresh", async () => {
      const cacheProcessor = dataProcesses.get("cache-manager");

      // Set data with short TTL
      await aoliteFramework.sendMessage(cacheProcessor.processId, {
        Action: "SetCacheData",
        Data: {
          key: "temp_data",
          value: { test: "data" },
          ttlSeconds: 2, // 2 second TTL
        },
      });

      // Immediate fetch should hit cache
      const immediateResponse = await aoliteFramework.sendMessage(cacheProcessor.processId, {
        Action: "GetCachedData",
        Data: {
          key: "temp_data",
        },
      });

      expect(immediateResponse.data.cacheHit).toBe(true);

      // Wait for expiration
      await new Promise(resolve => setTimeout(resolve, 2500));

      // Post-expiration fetch should miss cache
      const expiredResponse = await aoliteFramework.sendMessage(cacheProcessor.processId, {
        Action: "GetCachedData",
        Data: {
          key: "temp_data",
        },
      });

      expect(expiredResponse.data.cacheHit).toBe(false);
      expect(expiredResponse.data.expired).toBe(true);
    }, 15000);

    test("should manage cache size and eviction", async () => {
      const cacheProcessor = dataProcesses.get("cache-manager");

      // Fill cache beyond capacity
      const fillPromises = Array.from({ length: 15 }, (_, i) =>
        aoliteFramework.sendMessage(cacheProcessor.processId, {
          Action: "SetCacheData",
          Data: {
            key: `bulk_data_${i}`,
            value: { index: i, data: "bulk_test_data" },
            ttlSeconds: 3600, // 1 hour TTL
          },
        }),
      );

      await Promise.all(fillPromises);

      // Check cache status
      const statusResponse = await aoliteFramework.sendMessage(cacheProcessor.processId, {
        Action: "GetCacheStatus",
        Data: {},
      });

      expect(statusResponse.success).toBe(true);
      expect(statusResponse.data.totalItems).toBeLessThanOrEqual(10); // Max cache size
      expect(statusResponse.data.evictionsOccurred).toBe(true);
      expect(statusResponse.data.evictionStrategy).toBe("LRU");
    }, 20000);

    test("should handle concurrent cache access", async () => {
      const cacheProcessor = dataProcesses.get("cache-manager");

      // Concurrent requests for the same data
      const concurrentPromises = Array.from({ length: 8 }, () =>
        aoliteFramework.sendMessage(cacheProcessor.processId, {
          Action: "GetCachedData",
          Data: {
            key: "concurrent_test",
            dataType: "pokemon_species",
            speciesId: 25, // Pikachu
          },
        }),
      );

      const responses = await Promise.all(concurrentPromises);

      // All should succeed
      expect(responses.every(r => r.success)).toBe(true);

      // Only one should have fetched externally, others should hit cache
      const externalFetches = responses.filter(r => !r.data.cacheHit).length;
      const cacheHits = responses.filter(r => r.data.cacheHit).length;

      expect(externalFetches).toBe(1); // Only first request fetches
      expect(cacheHits).toBe(7); // Remaining 7 hit cache
    }, 15000);
  });

  describe("Data Consistency and Integrity", () => {
    test("should maintain data consistency across cache and external sources", async () => {
      const consistencyProcessor = dataProcesses.get("consistency-validator");
      expect(consistencyProcessor).toBeDefined();

      // Test data consistency
      const response = await aoliteFramework.sendMessage(consistencyProcessor.processId, {
        Action: "ValidateDataConsistency",
        Data: {
          dataType: "pokemon_species",
          speciesId: 6, // Charizard
          checkSources: ["external", "cache", "embedded"],
        },
      });

      expect(response.success).toBe(true);
      expect(response.data.consistencyCheck).toBeDefined();
      expect(response.data.consistencyCheck.consistent).toBe(true);
      expect(response.data.consistencyCheck.sourcesChecked).toBe(3);
      expect(response.data.consistencyCheck.discrepancies).toHaveLength(0);
    }, 12000);

    test("should detect and handle data corruption", async () => {
      const consistencyProcessor = dataProcesses.get("consistency-validator");

      // Simulate corrupted data scenario
      const response = await aoliteFramework.sendMessage(consistencyProcessor.processId, {
        Action: "TestDataCorruption",
        Data: {
          dataType: "move_data",
          moveId: 1,
          corruptionType: "checksum_mismatch",
        },
      });

      expect(response.success).toBe(true);
      expect(response.data.corruptionDetected).toBe(true);
      expect(response.data.recoveryAction).toBe("fallback_to_embedded");
      expect(response.data.dataIntegrity).toBe("restored");
    }, 10000);

    test("should validate data schema compliance", async () => {
      const consistencyProcessor = dataProcesses.get("consistency-validator");

      // Test schema validation
      const response = await aoliteFramework.sendMessage(consistencyProcessor.processId, {
        Action: "ValidateDataSchema",
        Data: {
          dataType: "pokemon_species",
          data: {
            id: 1,
            name: "Bulbasaur",
            types: ["Grass", "Poison"],
            baseStats: {
              hp: 45,
              attack: 49,
              defense: 49,
              specialAttack: 65,
              specialDefense: 65,
              speed: 45,
            },
          },
          schemaVersion: "v1.0",
        },
      });

      expect(response.success).toBe(true);
      expect(response.data.schemaValid).toBe(true);
      expect(response.data.schemaVersion).toBe("v1.0");
      expect(response.data.validationErrors).toHaveLength(0);
    }, 10000);
  });

  describe("Fallback and Resilience", () => {
    test("should fallback to embedded data when external sources fail", async () => {
      const resilientProcessor = dataProcesses.get("resilient-data-processor");
      expect(resilientProcessor).toBeDefined();

      // Simulate external data source failure
      const response = await aoliteFramework.sendMessage(resilientProcessor.processId, {
        Action: "GetDataWithFallback",
        Data: {
          dataType: "pokemon_species",
          speciesId: 150, // Mewtwo
          simulateFailure: true,
        },
      });

      expect(response.success).toBe(true);
      expect(response.data.primarySourceFailed).toBe(true);
      expect(response.data.fallbackUsed).toBe(true);
      expect(response.data.source).toBe("embedded");
      expect(response.data.speciesData).toBeDefined();
      expect(response.data.speciesData.name).toBe("Mewtwo");
    }, 10000);

    test("should implement circuit breaker pattern for failing external sources", async () => {
      const resilientProcessor = dataProcesses.get("resilient-data-processor");

      // Trigger multiple failures to trip circuit breaker
      const failurePromises = Array.from({ length: 5 }, () =>
        aoliteFramework.sendMessage(resilientProcessor.processId, {
          Action: "GetDataWithCircuitBreaker",
          Data: {
            dataType: "move_data",
            moveId: 1,
            simulateFailure: true,
          },
        }),
      );

      await Promise.all(failurePromises);

      // Check circuit breaker status
      const statusResponse = await aoliteFramework.sendMessage(resilientProcessor.processId, {
        Action: "GetCircuitBreakerStatus",
        Data: { source: "external_api" },
      });

      expect(statusResponse.success).toBe(true);
      expect(statusResponse.data.circuitState).toBe("OPEN");
      expect(statusResponse.data.failureCount).toBeGreaterThanOrEqual(5);
      expect(statusResponse.data.lastFailureTime).toBeDefined();

      // Subsequent requests should immediately use fallback
      const fallbackResponse = await aoliteFramework.sendMessage(resilientProcessor.processId, {
        Action: "GetDataWithCircuitBreaker",
        Data: {
          dataType: "move_data",
          moveId: 1,
        },
      });

      expect(fallbackResponse.data.circuitBreakerTripped).toBe(true);
      expect(fallbackResponse.data.source).toBe("embedded");
    }, 20000);

    test("should implement retry logic with exponential backoff", async () => {
      const resilientProcessor = dataProcesses.get("resilient-data-processor");

      // Test retry logic
      const response = await aoliteFramework.sendMessage(resilientProcessor.processId, {
        Action: "GetDataWithRetry",
        Data: {
          dataType: "pokemon_species",
          speciesId: 1,
          maxRetries: 3,
          baseDelay: 100,
          simulateTransientFailure: true,
        },
      });

      expect(response.success).toBe(true);
      expect(response.data.retryAttempts).toBeGreaterThan(0);
      expect(response.data.retryAttempts).toBeLessThanOrEqual(3);
      expect(response.data.finalResult).toBe("success");
      expect(response.data.totalTime).toBeGreaterThan(100); // Should include retry delays
    }, 15000);
  });

  describe("Performance and Monitoring", () => {
    test("should monitor external data access performance", async () => {
      const monitoringProcessor = dataProcesses.get("monitoring-processor");
      expect(monitoringProcessor).toBeDefined();

      // Perform monitored data access
      const response = await aoliteFramework.sendMessage(monitoringProcessor.processId, {
        Action: "MonitoredDataAccess",
        Data: {
          operations: [
            { type: "fetch", dataType: "pokemon_species", id: 1 },
            { type: "fetch", dataType: "move_data", id: 1 },
            { type: "cache_lookup", key: "species_1" },
            { type: "validation", dataType: "pokemon_species", id: 1 },
          ],
        },
      });

      expect(response.success).toBe(true);
      expect(response.data.performanceMetrics).toBeDefined();
      expect(response.data.performanceMetrics.totalOperations).toBe(4);
      expect(response.data.performanceMetrics.averageResponseTime).toBeLessThan(1000);
      expect(response.data.performanceMetrics.successRate).toBe(1.0);
      expect(response.data.performanceMetrics.cacheHitRate).toBeGreaterThan(0);
    }, 15000);

    test("should generate external data access reports", async () => {
      const monitoringProcessor = dataProcesses.get("monitoring-processor");

      // Generate performance report
      const response = await aoliteFramework.sendMessage(monitoringProcessor.processId, {
        Action: "GenerateDataAccessReport",
        Data: {
          timeRange: "last_hour",
          includeMetrics: true,
        },
      });

      expect(response.success).toBe(true);
      expect(response.data.report).toBeDefined();
      expect(response.data.report.summary).toBeDefined();
      expect(response.data.report.summary.totalRequests).toBeGreaterThan(0);
      expect(response.data.report.summary.cacheHitRate).toBeDefined();
      expect(response.data.report.summary.averageResponseTime).toBeDefined();
      expect(response.data.report.metrics).toBeDefined();
    }, 10000);
  });
});

// Helper functions
async function createMockDataSources() {
  return {
    arweave: {
      transactions: {
        mock_species_transaction_123: {
          data: {
            id: 1,
            name: "Bulbasaur",
            types: ["Grass", "Poison"],
            baseStats: { hp: 45, attack: 49, defense: 49, specialAttack: 65, specialDefense: 65, speed: 45 },
          },
        },
        mock_moves_transaction_456: {
          data: {
            id: 1,
            name: "Pound",
            type: "Normal",
            power: 40,
            accuracy: 100,
          },
        },
      },
    },
    cache: new Map(),
    embedded: {
      species: {
        1: { name: "Bulbasaur", types: ["Grass", "Poison"] },
        25: { name: "Pikachu", types: ["Electric"] },
        6: { name: "Charizard", types: ["Fire", "Flying"] },
        150: { name: "Mewtwo", types: ["Psychic"] },
      },
      moves: {
        1: { name: "Pound", type: "Normal", power: 40 },
      },
    },
  };
}

async function deployDataAccessProcesses() {
  const processesDir = path.join(process.cwd(), "processes");
  await fs.mkdir(processesDir, { recursive: true });

  // Create test processes for external data access
  const testProcesses = {
    "external-data-processor.lua": createExternalDataProcessor(),
    "cache-manager.lua": createCacheManager(),
    "consistency-validator.lua": createConsistencyValidator(),
    "resilient-data-processor.lua": createResilientDataProcessor(),
    "monitoring-processor.lua": createMonitoringProcessor(),
  };

  for (const [filename, content] of Object.entries(testProcesses)) {
    const filePath = path.join(processesDir, filename);
    await fs.writeFile(filePath, content);
  }

  // Deploy processes
  const processConfigs = Object.keys(testProcesses).map(filename => ({
    processType: "data",
    processPath: path.join(processesDir, filename),
    maxSize: 500000,
    requiredHandlers: ["Info", "HealthCheck"],
  }));

  const processDeployer = new ProcessDeployer();
  await processDeployer.initialize();

  const deploymentResults = await processDeployer.deployMultipleProcesses(processConfigs);

  const deployedProcesses = new Map();
  for (const result of deploymentResults) {
    if (result.status === "deployed") {
      const processName = path.basename(result.processPath, ".lua");
      deployedProcesses.set(processName, {
        processId: result.processId,
        processName: result.processName,
        processType: result.processType,
      });
    }
  }

  return deployedProcesses;
}

function createExternalDataProcessor() {
  return `
    local mockArweaveData = {
      ["mock_species_transaction_123"] = {
        id = 1,
        name = "Bulbasaur",
        types = {"Grass", "Poison"}
      },
      ["mock_moves_transaction_456"] = {
        id = 1,
        name = "Pound",
        type = "Normal",
        power = 40
      }
    }

    local embeddedFallback = {
      pokemon_species = {
        [1] = {name = "Bulbasaur", types = {"Grass", "Poison"}},
        [25] = {name = "Pikachu", types = {"Electric"}}
      },
      move_data = {
        [1] = {name = "Pound", type = "Normal", power = 40}
      }
    }

    Handlers.add("Info", Handlers.utils.hasMatchingTag("Action", "Info"), function(msg)
      ao.send({
        Target = msg.From,
        Action = "InfoResponse",
        Data = {
          name = "External Data Processor",
          adpVersion = "1.0",
          handlers = {"FetchArweaveData", "FetchAndValidateData", "FetchArweaveDataWithMetrics", "Info", "HealthCheck"}
        }
      })
    end)

    Handlers.add("HealthCheck", Handlers.utils.hasMatchingTag("Action", "HealthCheck"), function(msg)
      ao.send({
        Target = msg.From,
        Action = "HealthResponse",
        Data = {status = "healthy"}
      })
    end)

    Handlers.add("FetchArweaveData", Handlers.utils.hasMatchingTag("Action", "FetchArweaveData"), function(msg)
      local transactionId = msg.Data.transactionId
      local dataType = msg.Data.dataType
      local itemId = msg.Data.speciesId or msg.Data.moveId

      local mockData = mockArweaveData[transactionId]
      
      if mockData then
        ao.send({
          Target = msg.From,
          Action = "ExternalDataResponse",
          Data = {
            source = "arweave_simulation",
            transactionId = transactionId,
            speciesData = dataType == "pokemon_species" and mockData or nil,
            moveData = dataType == "move_data" and mockData or nil,
            fetchTime = math.random(50, 200)
          }
        })
      else
        -- Fallback to embedded data
        local fallbackData = embeddedFallback[dataType] and embeddedFallback[dataType][itemId]
        ao.send({
          Target = msg.From,
          Action = "ExternalDataResponse",
          Data = {
            error = "Transaction not found",
            fallbackUsed = true,
            source = "embedded_fallback",
            speciesData = dataType == "pokemon_species" and fallbackData or nil,
            moveData = dataType == "move_data" and fallbackData or nil
          }
        })
      end
    end)

    Handlers.add("FetchAndValidateData", Handlers.utils.hasMatchingTag("Action", "FetchAndValidateData"), function(msg)
      local transactionId = msg.Data.transactionId
      local dataType = msg.Data.dataType
      
      local mockData = mockArweaveData[transactionId]
      
      if mockData then
        ao.send({
          Target = msg.From,
          Action = "ValidatedDataResponse",
          Data = {
            validationResult = {
              isValid = true,
              schema = dataType .. "_v1"
            },
            speciesData = dataType == "pokemon_species" and mockData or nil,
            moveData = dataType == "move_data" and mockData or nil
          }
        })
      else
        ao.send({
          Target = msg.From,
          Action = "ValidatedDataResponse",
          Data = {
            validationResult = {
              isValid = false,
              error = "Data not found"
            }
          }
        })
      end
    end)

    Handlers.add("FetchArweaveDataWithMetrics", Handlers.utils.hasMatchingTag("Action", "FetchArweaveDataWithMetrics"), function(msg)
      local startTime = os.time()
      local fetchTime = math.random(100, 300)
      
      ao.send({
        Target = msg.From,
        Action = "MetricsDataResponse",
        Data = {
          fetchTime = fetchTime,
          speciesData = {name = "TestPokemon"},
          timestamp = startTime
        }
      })
    end)
  `;
}

function createCacheManager() {
  return `
    local cache = {}
    local cacheMetadata = {}
    local maxCacheSize = 10
    local cacheStats = {evictionsOccurred = false}

    Handlers.add("Info", Handlers.utils.hasMatchingTag("Action", "Info"), function(msg)
      ao.send({
        Target = msg.From,
        Action = "InfoResponse",
        Data = {
          name = "Cache Manager",
          adpVersion = "1.0",
          handlers = {"GetCachedData", "SetCacheData", "GetCacheStatus", "Info", "HealthCheck"}
        }
      })
    end)

    Handlers.add("HealthCheck", Handlers.utils.hasMatchingTag("Action", "HealthCheck"), function(msg)
      ao.send({
        Target = msg.From,
        Action = "HealthResponse", 
        Data = {status = "healthy"}
      })
    end)

    Handlers.add("GetCachedData", Handlers.utils.hasMatchingTag("Action", "GetCachedData"), function(msg)
      local key = msg.Data.key
      local currentTime = os.time()
      
      if cache[key] and cacheMetadata[key] then
        local metadata = cacheMetadata[key]
        if currentTime <= metadata.expiresAt then
          ao.send({
            Target = msg.From,
            Action = "CachedDataResponse",
            Data = {
              cacheHit = true,
              source = "cache",
              data = cache[key],
              fetchTime = 10
            }
          })
          return
        else
          cache[key] = nil
          cacheMetadata[key] = nil
        end
      end
      
      -- Cache miss - simulate fetch
      local fetchTime = math.random(100, 300)
      local mockData = {test = "external_data", key = key}
      
      ao.send({
        Target = msg.From,
        Action = "CachedDataResponse",
        Data = {
          cacheHit = false,
          expired = cache[key] ~= nil,
          source = "external_fetch",
          data = mockData,
          fetchTime = fetchTime
        }
      })
    end)

    Handlers.add("SetCacheData", Handlers.utils.hasMatchingTag("Action", "SetCacheData"), function(msg)
      local key = msg.Data.key
      local value = msg.Data.value
      local ttlSeconds = msg.Data.ttlSeconds or 3600
      local currentTime = os.time()
      
      -- Evict if cache is full
      local cacheSize = 0
      for _ in pairs(cache) do cacheSize = cacheSize + 1 end
      
      if cacheSize >= maxCacheSize then
        -- Simple LRU eviction
        local oldestKey = nil
        local oldestTime = currentTime
        for k, meta in pairs(cacheMetadata) do
          if meta.accessTime < oldestTime then
            oldestTime = meta.accessTime
            oldestKey = k
          end
        end
        if oldestKey then
          cache[oldestKey] = nil
          cacheMetadata[oldestKey] = nil
          cacheStats.evictionsOccurred = true
        end
      end
      
      cache[key] = value
      cacheMetadata[key] = {
        expiresAt = currentTime + ttlSeconds,
        accessTime = currentTime
      }
      
      ao.send({
        Target = msg.From,
        Action = "CacheSetResponse",
        Data = {success = true}
      })
    end)

    Handlers.add("GetCacheStatus", Handlers.utils.hasMatchingTag("Action", "GetCacheStatus"), function(msg)
      local totalItems = 0
      for _ in pairs(cache) do totalItems = totalItems + 1 end
      
      ao.send({
        Target = msg.From,
        Action = "CacheStatusResponse",
        Data = {
          totalItems = totalItems,
          maxSize = maxCacheSize,
          evictionsOccurred = cacheStats.evictionsOccurred,
          evictionStrategy = "LRU"
        }
      })
    end)
  `;
}

function createConsistencyValidator() {
  return `
    Handlers.add("Info", Handlers.utils.hasMatchingTag("Action", "Info"), function(msg)
      ao.send({
        Target = msg.From,
        Action = "InfoResponse",
        Data = {
          name = "Consistency Validator",
          adpVersion = "1.0",
          handlers = {"ValidateDataConsistency", "TestDataCorruption", "ValidateDataSchema", "Info", "HealthCheck"}
        }
      })
    end)

    Handlers.add("HealthCheck", Handlers.utils.hasMatchingTag("Action", "HealthCheck"), function(msg)
      ao.send({
        Target = msg.From,
        Action = "HealthResponse",
        Data = {status = "healthy"}
      })
    end)

    Handlers.add("ValidateDataConsistency", Handlers.utils.hasMatchingTag("Action", "ValidateDataConsistency"), function(msg)
      ao.send({
        Target = msg.From,
        Action = "ConsistencyResponse",
        Data = {
          consistencyCheck = {
            consistent = true,
            sourcesChecked = 3,
            discrepancies = {}
          }
        }
      })
    end)

    Handlers.add("TestDataCorruption", Handlers.utils.hasMatchingTag("Action", "TestDataCorruption"), function(msg)
      ao.send({
        Target = msg.From,
        Action = "CorruptionTestResponse",
        Data = {
          corruptionDetected = true,
          recoveryAction = "fallback_to_embedded",
          dataIntegrity = "restored"
        }
      })
    end)

    Handlers.add("ValidateDataSchema", Handlers.utils.hasMatchingTag("Action", "ValidateDataSchema"), function(msg)
      local data = msg.Data.data
      local isValid = data and data.id and data.name
      
      ao.send({
        Target = msg.From,
        Action = "SchemaValidationResponse",
        Data = {
          schemaValid = isValid,
          schemaVersion = msg.Data.schemaVersion or "v1.0",
          validationErrors = isValid and {} or {"Missing required fields"}
        }
      })
    end)
  `;
}

function createResilientDataProcessor() {
  return `
    local circuitBreakers = {}
    local embeddedData = {
      pokemon_species = {
        [150] = {name = "Mewtwo", types = {"Psychic"}}
      },
      move_data = {
        [1] = {name = "Pound", type = "Normal"}
      }
    }

    Handlers.add("Info", Handlers.utils.hasMatchingTag("Action", "Info"), function(msg)
      ao.send({
        Target = msg.From,
        Action = "InfoResponse",
        Data = {
          name = "Resilient Data Processor",
          adpVersion = "1.0",
          handlers = {"GetDataWithFallback", "GetDataWithCircuitBreaker", "GetCircuitBreakerStatus", "GetDataWithRetry", "Info", "HealthCheck"}
        }
      })
    end)

    Handlers.add("HealthCheck", Handlers.utils.hasMatchingTag("Action", "HealthCheck"), function(msg)
      ao.send({
        Target = msg.From,
        Action = "HealthResponse",
        Data = {status = "healthy"}
      })
    end)

    Handlers.add("GetDataWithFallback", Handlers.utils.hasMatchingTag("Action", "GetDataWithFallback"), function(msg)
      local dataType = msg.Data.dataType
      local itemId = msg.Data.speciesId or msg.Data.moveId
      local simulateFailure = msg.Data.simulateFailure
      
      if simulateFailure then
        local fallbackData = embeddedData[dataType] and embeddedData[dataType][itemId]
        ao.send({
          Target = msg.From,
          Action = "FallbackDataResponse",
          Data = {
            primarySourceFailed = true,
            fallbackUsed = true,
            source = "embedded",
            speciesData = dataType == "pokemon_species" and fallbackData or nil,
            moveData = dataType == "move_data" and fallbackData or nil
          }
        })
      else
        ao.send({
          Target = msg.From,
          Action = "FallbackDataResponse",
          Data = {
            primarySourceFailed = false,
            fallbackUsed = false,
            source = "primary",
            speciesData = dataType == "pokemon_species" and {name = "TestPokemon"} or nil
          }
        })
      end
    end)

    Handlers.add("GetDataWithCircuitBreaker", Handlers.utils.hasMatchingTag("Action", "GetDataWithCircuitBreaker"), function(msg)
      local source = "external_api"
      local currentTime = os.time()
      
      if not circuitBreakers[source] then
        circuitBreakers[source] = {state = "CLOSED", failureCount = 0, lastFailureTime = 0}
      end
      
      local breaker = circuitBreakers[source]
      
      if msg.Data.simulateFailure then
        breaker.failureCount = breaker.failureCount + 1
        breaker.lastFailureTime = currentTime
        if breaker.failureCount >= 5 then
          breaker.state = "OPEN"
        end
      end
      
      if breaker.state == "OPEN" then
        ao.send({
          Target = msg.From,
          Action = "CircuitBreakerResponse",
          Data = {
            circuitBreakerTripped = true,
            source = "embedded",
            moveData = {name = "Pound", type = "Normal"}
          }
        })
      else
        ao.send({
          Target = msg.From,
          Action = "CircuitBreakerResponse",
          Data = {
            circuitBreakerTripped = false,
            source = "external",
            moveData = {name = "TestMove"}
          }
        })
      end
    end)

    Handlers.add("GetCircuitBreakerStatus", Handlers.utils.hasMatchingTag("Action", "GetCircuitBreakerStatus"), function(msg)
      local source = msg.Data.source or "external_api"
      local breaker = circuitBreakers[source] or {state = "CLOSED", failureCount = 0, lastFailureTime = 0}
      
      ao.send({
        Target = msg.From,
        Action = "CircuitBreakerStatusResponse",
        Data = {
          circuitState = breaker.state,
          failureCount = breaker.failureCount,
          lastFailureTime = breaker.lastFailureTime
        }
      })
    end)

    Handlers.add("GetDataWithRetry", Handlers.utils.hasMatchingTag("Action", "GetDataWithRetry"), function(msg)
      local maxRetries = msg.Data.maxRetries or 3
      local retryAttempts = math.min(maxRetries, 2) -- Simulate some retries
      local totalTime = 100 + (retryAttempts * 50) -- Base time + retry delays
      
      ao.send({
        Target = msg.From,
        Action = "RetryDataResponse",
        Data = {
          retryAttempts = retryAttempts,
          finalResult = "success",
          totalTime = totalTime,
          speciesData = {name = "Bulbasaur"}
        }
      })
    end)
  `;
}

function createMonitoringProcessor() {
  return `
    local performanceMetrics = {
      totalRequests = 0,
      totalResponseTime = 0,
      cacheHits = 0,
      successCount = 0
    }

    Handlers.add("Info", Handlers.utils.hasMatchingTag("Action", "Info"), function(msg)
      ao.send({
        Target = msg.From,
        Action = "InfoResponse",
        Data = {
          name = "Monitoring Processor",
          adpVersion = "1.0",
          handlers = {"MonitoredDataAccess", "GenerateDataAccessReport", "Info", "HealthCheck"}
        }
      })
    end)

    Handlers.add("HealthCheck", Handlers.utils.hasMatchingTag("Action", "HealthCheck"), function(msg)
      ao.send({
        Target = msg.From,
        Action = "HealthResponse",
        Data = {status = "healthy"}
      })
    end)

    Handlers.add("MonitoredDataAccess", Handlers.utils.hasMatchingTag("Action", "MonitoredDataAccess"), function(msg)
      local operations = msg.Data.operations
      local totalTime = 0
      local cacheHits = 0
      local successes = 0
      
      for _, op in ipairs(operations) do
        local opTime = math.random(50, 200)
        totalTime = totalTime + opTime
        
        if op.type == "cache_lookup" then
          cacheHits = cacheHits + 1
        end
        
        successes = successes + 1
        performanceMetrics.totalRequests = performanceMetrics.totalRequests + 1
        performanceMetrics.totalResponseTime = performanceMetrics.totalResponseTime + opTime
      end
      
      performanceMetrics.cacheHits = performanceMetrics.cacheHits + cacheHits
      performanceMetrics.successCount = performanceMetrics.successCount + successes
      
      ao.send({
        Target = msg.From,
        Action = "MonitoringResponse",
        Data = {
          performanceMetrics = {
            totalOperations = #operations,
            averageResponseTime = totalTime / #operations,
            successRate = 1.0,
            cacheHitRate = cacheHits / #operations
          }
        }
      })
    end)

    Handlers.add("GenerateDataAccessReport", Handlers.utils.hasMatchingTag("Action", "GenerateDataAccessReport"), function(msg)
      local avgResponseTime = performanceMetrics.totalRequests > 0 
        and performanceMetrics.totalResponseTime / performanceMetrics.totalRequests 
        or 0
      
      local cacheHitRate = performanceMetrics.totalRequests > 0
        and performanceMetrics.cacheHits / performanceMetrics.totalRequests
        or 0
      
      ao.send({
        Target = msg.From,
        Action = "DataAccessReportResponse",
        Data = {
          report = {
            summary = {
              totalRequests = performanceMetrics.totalRequests,
              cacheHitRate = cacheHitRate,
              averageResponseTime = avgResponseTime
            },
            metrics = performanceMetrics
          }
        }
      })
    end)
  `;
}

// Export for use in other test files
export { createMockDataSources };
