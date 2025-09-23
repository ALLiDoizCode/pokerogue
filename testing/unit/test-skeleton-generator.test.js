/**
 * Test Suite for Test Skeleton Generator
 * Tests the automated test generation functionality for Lua processes
 */

import { execSync } from "child_process";
import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "fs";
import { join } from "path";
import { afterEach, beforeEach, describe, expect, it } from "vitest";

const TEST_DIR = join(process.cwd(), "test-temp-generator");
const GENERATOR_PATH = join(process.cwd(), "scripts/generators/test-skeleton-generator.lua");

describe("Test Skeleton Generator", () => {
  beforeEach(() => {
    // Create temporary test directory
    if (existsSync(TEST_DIR)) {
      rmSync(TEST_DIR, { recursive: true, force: true });
    }
    mkdirSync(TEST_DIR, { recursive: true });
    mkdirSync(join(TEST_DIR, "scripts", "generators", "templates"), { recursive: true });

    // Copy templates to test directory
    const templateDir = join(process.cwd(), "scripts/generators/templates");
    if (existsSync(templateDir)) {
      execSync(`cp -r "${templateDir}" "${join(TEST_DIR, "scripts/generators/")}"`, { encoding: "utf8" });
    }
  });

  afterEach(() => {
    // Clean up temporary files
    if (existsSync(TEST_DIR)) {
      rmSync(TEST_DIR, { recursive: true, force: true });
    }
  });

  describe("Function Discovery", () => {
    it("should discover regular function definitions", () => {
      const sourceFile = join(TEST_DIR, "battle.lua");
      writeFileSync(
        sourceFile,
        `
        function calculateDamage(attack, defense)
          return math.max(1, attack - defense)
        end
        
        function validateMove(move, pokemon)
          return move and pokemon and move.pp > 0
        end
        
        function getTypeEffectiveness(moveType, targetType)
          local effectiveness = 1.0
          -- Type chart logic here
          return effectiveness
        end
      `,
      );

      const result = execSync(`cd ${TEST_DIR} && lua ${GENERATOR_PATH} discover ${sourceFile}`, { encoding: "utf8" });

      expect(result).toContain("calculateDamage");
      expect(result).toContain("validateMove");
      expect(result).toContain("getTypeEffectiveness");
      expect(result).toContain("Functions discovered: 3");
    });

    it("should discover local function definitions", () => {
      const sourceFile = join(TEST_DIR, "utils.lua");
      writeFileSync(
        sourceFile,
        `
        local function clamp(value, min, max)
          return math.max(min, math.min(max, value))
        end
        
        local function deepCopy(table)
          -- Deep copy implementation
          return table
        end
        
        function publicFunction()
          return clamp(5, 1, 10)
        end
      `,
      );

      const result = execSync(`cd ${TEST_DIR} && lua ${GENERATOR_PATH} discover ${sourceFile}`, { encoding: "utf8" });

      expect(result).toContain("clamp (local)");
      expect(result).toContain("deepCopy (local)");
      expect(result).toContain("publicFunction (global)");
    });

    it("should discover table method definitions", () => {
      const sourceFile = join(TEST_DIR, "stats.lua");
      writeFileSync(
        sourceFile,
        `
        local Stats = {}
        
        Stats.calculate = function(baseStat, level, iv, ev)
          return math.floor((baseStat * 2 + iv + ev/4) * level / 100) + 5
        end
        
        Stats.getModifier = function(stages)
          return stages >= 0 and (2 + stages) / 2 or 2 / (2 - stages)
        end
        
        Pokemon.updateStats = function(self)
          self.attack = Stats.calculate(self.baseAttack, self.level, self.ivs.attack, self.evs.attack)
        end
      `,
      );

      const result = execSync(`cd ${TEST_DIR} && lua ${GENERATOR_PATH} discover ${sourceFile}`, { encoding: "utf8" });

      expect(result).toContain("Stats.calculate (method)");
      expect(result).toContain("Stats.getModifier (method)");
      expect(result).toContain("Pokemon.updateStats (method)");
    });

    it("should discover AO handler definitions", () => {
      const sourceFile = join(TEST_DIR, "handlers.lua");
      writeFileSync(
        sourceFile,
        `
        Handlers.add("process-move",
          Handlers.utils.hasMatchingTag("Action", "ProcessMove"),
          function(msg)
            local move = json.decode(msg.Data)
            local result = processMove(move)
            ao.send({
              Target = msg.From,
              Action = "MoveResult",
              Data = json.encode(result)
            })
          end
        )
        
        Handlers.add('calculate-damage',
          function(msg)
            return msg.Action == "CalculateDamage"
          end,
          function(msg)
            local damage = calculateDamage(msg.Attack, msg.Defense)
            ao.send({ Target = msg.From, Data = tostring(damage) })
          end
        )
      `,
      );

      const result = execSync(`cd ${TEST_DIR} && lua ${GENERATOR_PATH} discover ${sourceFile}`, { encoding: "utf8" });

      expect(result).toContain("Handler:process-move");
      expect(result).toContain("Handler:calculate-damage");
    });

    it("should handle complex mixed patterns", () => {
      const sourceFile = join(TEST_DIR, "complex.lua");
      writeFileSync(
        sourceFile,
        `
        -- Module with mixed patterns
        local BattleEngine = {}
        
        function BattleEngine.init()
          return true
        end
        
        local function _validateInput(data)
          return data ~= nil
        end
        
        BattleEngine.processMove = function(move, attacker, defender)
          if not _validateInput(move) then
            return nil
          end
          return calculateDamage(move.power, attacker.attack, defender.defense)
        end
        
        BattleEngine:updateState = function(newState)
          self.state = newState
        end
        
        Handlers.add("battle-action",
          Handlers.utils.hasMatchingTag("Action", "Battle"),
          function(msg)
            local result = BattleEngine.processMove(msg.Move, msg.Attacker, msg.Defender)
            ao.send({ Target = msg.From, Data = json.encode(result) })
          end
        )
        
        return BattleEngine
      `,
      );

      const result = execSync(`cd ${TEST_DIR} && lua ${GENERATOR_PATH} discover ${sourceFile}`, { encoding: "utf8" });

      expect(result).toContain("BattleEngine.init (global)");
      expect(result).toContain("_validateInput (local)");
      expect(result).toContain("BattleEngine.processMove (method)");
      expect(result).toContain("BattleEngine:updateState (method)");
      expect(result).toContain("Handler:battle-action");
    });
  });

  describe("Template Selection", () => {
    it("should select unit test template for regular functions", () => {
      const sourceFile = join(TEST_DIR, "math-utils.lua");
      writeFileSync(
        sourceFile,
        `
        function add(a, b)
          return a + b
        end
        
        function multiply(a, b)
          return a * b
        end
      `,
      );

      const result = execSync(`cd ${TEST_DIR} && lua ${GENERATOR_PATH} analyze ${sourceFile}`, { encoding: "utf8" });

      expect(result).toContain("Template: unit-test");
      expect(result).toContain("Reason: Contains regular functions");
    });

    it("should select handler test template for AO handlers", () => {
      const sourceFile = join(TEST_DIR, "ao-process.lua");
      writeFileSync(
        sourceFile,
        `
        Handlers.add("test-handler",
          Handlers.utils.hasMatchingTag("Action", "Test"),
          function(msg)
            ao.send({ Target = msg.From, Data = "OK" })
          end
        )
      `,
      );

      const result = execSync(`cd ${TEST_DIR} && lua ${GENERATOR_PATH} analyze ${sourceFile}`, { encoding: "utf8" });

      expect(result).toContain("Template: handler-test");
      expect(result).toContain("Reason: Contains AO handlers");
    });

    it("should select integration test template for mixed patterns", () => {
      const sourceFile = join(TEST_DIR, "complex-process.lua");
      writeFileSync(
        sourceFile,
        `
        function calculateStat(base, level)
          return base * level
        end
        
        Handlers.add("get-stats",
          Handlers.utils.hasMatchingTag("Action", "GetStats"),
          function(msg)
            local stat = calculateStat(msg.Base, msg.Level)
            ao.send({ Target = msg.From, Data = tostring(stat) })
          end
        )
      `,
      );

      const result = execSync(`cd ${TEST_DIR} && lua ${GENERATOR_PATH} analyze ${sourceFile}`, { encoding: "utf8" });

      expect(result).toContain("Template: integration-test");
      expect(result).toContain("Reason: Contains both functions and handlers");
    });
  });

  describe("Test Generation", () => {
    it("should generate complete unit test file", () => {
      const sourceFile = join(TEST_DIR, "calculator.lua");
      writeFileSync(
        sourceFile,
        `
        function add(a, b)
          return a + b
        end
        
        function subtract(a, b)
          return a - b
        end
        
        function divide(a, b)
          if b == 0 then
            error("Division by zero")
          end
          return a / b
        end
      `,
      );

      const outputFile = join(TEST_DIR, "calculator.test.lua");
      execSync(`cd ${TEST_DIR} && lua ${GENERATOR_PATH} generate ${sourceFile} ${outputFile}`);

      expect(existsSync(outputFile)).toBe(true);

      const testContent = readFileSync(outputFile, "utf8");

      // Check for proper test structure
      expect(testContent).toContain('describe("calculator.lua Tests"');
      expect(testContent).toContain('describe("add"');
      expect(testContent).toContain('describe("subtract"');
      expect(testContent).toContain('describe("divide"');

      // Check for test cases
      expect(testContent).toContain('it("should add positive numbers"');
      expect(testContent).toContain('it("should handle zero"');
      expect(testContent).toContain('it("should handle negative numbers"');
      expect(testContent).toContain('it("should handle division by zero"');

      // Check for edge case TODOs
      expect(testContent).toContain("-- TODO: Add edge case tests");
      expect(testContent).toContain("-- TODO: Test boundary conditions");
    });

    it("should generate handler test file for AO processes", () => {
      const sourceFile = join(TEST_DIR, "token-process.lua");
      writeFileSync(
        sourceFile,
        `
        local TokenProcess = {}
        
        function TokenProcess.transfer(from, to, amount)
          -- Transfer logic
          return { success = true, newBalance = 100 }
        end
        
        Handlers.add("transfer",
          Handlers.utils.hasMatchingTag("Action", "Transfer"),
          function(msg)
            local result = TokenProcess.transfer(msg.From, msg.To, tonumber(msg.Amount))
            ao.send({
              Target = msg.From,
              Action = "TransferResult",
              Data = json.encode(result)
            })
          end
        )
        
        Handlers.add("balance",
          Handlers.utils.hasMatchingTag("Action", "Balance"),
          function(msg)
            local balance = getBalance(msg.Address)
            ao.send({
              Target = msg.From,
              Data = tostring(balance)
            })
          end
        )
      `,
      );

      const outputFile = join(TEST_DIR, "token-process.test.lua");
      execSync(`cd ${TEST_DIR} && lua ${GENERATOR_PATH} generate ${sourceFile} ${outputFile}`);

      expect(existsSync(outputFile)).toBe(true);

      const testContent = readFileSync(outputFile, "utf8");

      // Check for AO test setup
      expect(testContent).toContain("-- AO Test Environment Setup");
      expect(testContent).toContain("local ao = {");
      expect(testContent).toContain("local Handlers = {");

      // Check for handler tests
      expect(testContent).toContain('describe("Handler: transfer"');
      expect(testContent).toContain('describe("Handler: balance"');

      // Check for message simulation
      expect(testContent).toContain("local mockMessage = {");
      expect(testContent).toContain('Action = "Transfer"');

      // Check for AO-specific assertions
      expect(testContent).toContain("-- Verify response message");
      expect(testContent).toContain("assert(sentMessages[1].Target");
    });

    it("should include coverage annotations", () => {
      const sourceFile = join(TEST_DIR, "sample.lua");
      writeFileSync(
        sourceFile,
        `
        function simpleFunction(x)
          return x * 2
        end
      `,
      );

      const outputFile = join(TEST_DIR, "sample.test.lua");
      execSync(`cd ${TEST_DIR} && lua ${GENERATOR_PATH} generate ${sourceFile} ${outputFile}`);

      const testContent = readFileSync(outputFile, "utf8");

      // Check for coverage annotations
      expect(testContent).toContain("-- @coverage:");
      expect(testContent).toContain("-- @test-type: unit");
      expect(testContent).toContain("-- @functions-tested: simpleFunction");
    });

    it("should handle files with no functions", () => {
      const sourceFile = join(TEST_DIR, "constants.lua");
      writeFileSync(
        sourceFile,
        `
        local CONSTANTS = {
          MAX_LEVEL = 100,
          MAX_HP = 999
        }
        
        return CONSTANTS
      `,
      );

      const outputFile = join(TEST_DIR, "constants.test.lua");
      execSync(`cd ${TEST_DIR} && lua ${GENERATOR_PATH} generate ${sourceFile} ${outputFile}`);

      expect(existsSync(outputFile)).toBe(true);

      const testContent = readFileSync(outputFile, "utf8");

      // Should generate basic structure test
      expect(testContent).toContain('describe("constants.lua Tests"');
      expect(testContent).toContain('it("should load without errors"');
      expect(testContent).toContain("-- No functions to test - testing module structure");
    });
  });

  describe("Template System", () => {
    it("should use correct template placeholders", () => {
      // Create a custom template for testing
      const templateFile = join(TEST_DIR, "scripts/generators/templates/unit-test.template.lua");
      writeFileSync(
        templateFile,
        `
-- Test for {{MODULE_NAME}}
-- Generated on {{TIMESTAMP}}
describe("{{MODULE_NAME}} Tests", function()
  {{#each FUNCTIONS}}
  describe("{{name}}", function()
    it("should test {{name}}", function()
      -- TODO: Implement test for {{name}}
    end)
  end)
  {{/each}}
end)
      `,
      );

      const sourceFile = join(TEST_DIR, "math.lua");
      writeFileSync(
        sourceFile,
        `
        function add(a, b)
          return a + b
        end
      `,
      );

      const outputFile = join(TEST_DIR, "math.test.lua");
      execSync(`cd ${TEST_DIR} && lua ${GENERATOR_PATH} generate ${sourceFile} ${outputFile}`);

      const testContent = readFileSync(outputFile, "utf8");

      expect(testContent).toContain("Test for math.lua");
      expect(testContent).toContain('describe("math.lua Tests"');
      expect(testContent).toContain("should test add");
      expect(testContent).not.toContain("{{MODULE_NAME}}");
      expect(testContent).not.toContain("{{TIMESTAMP}}");
    });
  });

  describe("Command-line Interface", () => {
    it("should show usage when no arguments provided", () => {
      const result = execSync(`lua ${GENERATOR_PATH}`, { encoding: "utf8" });

      expect(result).toContain("Usage:");
      expect(result).toContain("discover");
      expect(result).toContain("analyze");
      expect(result).toContain("generate");
    });

    it("should handle discover command", () => {
      const sourceFile = join(TEST_DIR, "test.lua");
      writeFileSync(sourceFile, "function test() end");

      const result = execSync(`cd ${TEST_DIR} && lua ${GENERATOR_PATH} discover ${sourceFile}`, { encoding: "utf8" });

      expect(result).toContain("test (global)");
      expect(result).toContain("Functions discovered: 1");
    });

    it("should handle analyze command", () => {
      const sourceFile = join(TEST_DIR, "test.lua");
      writeFileSync(sourceFile, "function test() end");

      const result = execSync(`cd ${TEST_DIR} && lua ${GENERATOR_PATH} analyze ${sourceFile}`, { encoding: "utf8" });

      expect(result).toContain("Template: unit-test");
      expect(result).toContain("Complexity: Low");
    });

    it("should handle generate command", () => {
      const sourceFile = join(TEST_DIR, "test.lua");
      writeFileSync(sourceFile, "function test() end");

      const outputFile = join(TEST_DIR, "test.test.lua");
      const result = execSync(`cd ${TEST_DIR} && lua ${GENERATOR_PATH} generate ${sourceFile} ${outputFile}`, {
        encoding: "utf8",
      });

      expect(result).toContain("Test file generated");
      expect(result).toContain(outputFile);
      expect(existsSync(outputFile)).toBe(true);
    });
  });

  describe("Error Handling", () => {
    it("should handle non-existent source files", () => {
      try {
        execSync(`cd ${TEST_DIR} && lua ${GENERATOR_PATH} discover non-existent.lua`);
        expect.fail("Should have thrown an error");
      } catch (error) {
        expect(error.stdout || error.message).toContain("Error: Could not read file");
      }
    });

    it("should handle invalid output paths", () => {
      const sourceFile = join(TEST_DIR, "test.lua");
      writeFileSync(sourceFile, "function test() end");

      try {
        execSync(`cd ${TEST_DIR} && lua ${GENERATOR_PATH} generate ${sourceFile} /invalid/path/test.lua`);
        expect.fail("Should have thrown an error");
      } catch (error) {
        expect(error.stdout || error.message).toContain("Error: Could not write test file");
      }
    });

    it("should handle syntax errors in source files gracefully", () => {
      const sourceFile = join(TEST_DIR, "broken.lua");
      writeFileSync(
        sourceFile,
        `
        function incomplete(
        -- Missing closing parenthesis and end
      `,
      );

      const result = execSync(`cd ${TEST_DIR} && lua ${GENERATOR_PATH} discover ${sourceFile}`, { encoding: "utf8" });

      // Should not crash, just report what it can find
      expect(result).toContain("Functions discovered: 0");
    });

    it("should handle empty files", () => {
      const sourceFile = join(TEST_DIR, "empty.lua");
      writeFileSync(sourceFile, "");

      const result = execSync(`cd ${TEST_DIR} && lua ${GENERATOR_PATH} discover ${sourceFile}`, { encoding: "utf8" });

      expect(result).toContain("Functions discovered: 0");
    });
  });

  describe("Integration with TDD Workflow", () => {
    it("should generate tests that integrate with TDD validation", () => {
      const sourceFile = join(TEST_DIR, "processes", "battle.lua");
      mkdirSync(join(TEST_DIR, "processes"), { recursive: true });

      writeFileSync(
        sourceFile,
        `
        function calculateDamage(attack, defense)
          return math.max(1, attack - defense)
        end
      `,
      );

      const outputFile = join(TEST_DIR, "testing", "unit", "battle.test.lua");
      mkdirSync(join(TEST_DIR, "testing", "unit"), { recursive: true });

      execSync(`cd ${TEST_DIR} && lua ${GENERATOR_PATH} generate processes/battle.lua testing/unit/battle.test.lua`);

      expect(existsSync(outputFile)).toBe(true);

      const testContent = readFileSync(outputFile, "utf8");

      // Should be compatible with TDD validation patterns
      expect(testContent).toContain("calculateDamage");
      expect(testContent).toContain("describe(");
      expect(testContent).toContain("it(");
    });
  });
});
