/**
 * Aolite Framework JavaScript Interface
 * Provides JavaScript interface to aolite Lua testing framework
 */

import { spawn } from "child_process";
import fs from "fs/promises";
import path from "path";
import chalk from "chalk";

export class AoliteFramework {
  constructor(options = {}) {
    this.aoliteDir = options.aoliteDir || path.join(process.cwd(), "testing/aolite");
    this.luaExecutable = options.luaExecutable || "lua";
    this.processes = new Map();
    this.messageLog = [];
    this.logLevel = options.logLevel || 2;
    this.initialized = false;
  }

  /**
   * Initialize aolite framework
   */
  async initialize() {
    if (this.initialized) {
      return;
    }

    console.log(chalk.blue("🔧 Initializing aolite framework..."));

    // Verify Lua availability
    try {
      await this.execLua("print('Lua available')");
    } catch (error) {
      throw new Error(`Lua not available: ${error.message}`);
    }

    // Verify aolite framework files exist
    const requiredFiles = [
      "process-emulator.lua",
      "enhanced-test-framework.lua",
      "assertion-library.lua",
      "mock-system.lua",
      "state-inspector.lua",
    ];

    for (const file of requiredFiles) {
      const filePath = path.join(this.aoliteDir, file);
      try {
        await fs.access(filePath);
      } catch (_error) {
        throw new Error(`Required aolite file not found: ${file}`);
      }
    }

    // Initialize aolite in Lua
    await this.initializeAoliteLua();

    this.initialized = true;
    console.log(chalk.green("✅ aolite framework initialized"));
  }

  /**
   * Initialize aolite Lua components
   */
  async initializeAoliteLua() {
    const initScript = `
      -- Load aolite framework components
      package.path = package.path .. ";${this.aoliteDir}/?.lua"
      
      local ProcessEmulator = require("process-emulator")
      local TestFramework = require("enhanced-test-framework")
      local AssertionLibrary = require("assertion-library")
      local MockSystem = require("mock-system")
      local StateInspector = require("state-inspector")
      
      -- Initialize global aolite instance
      aolite = {
        emulator = ProcessEmulator.new(),
        framework = TestFramework.new(),
        assertions = AssertionLibrary,
        mocks = MockSystem.new(),
        inspector = StateInspector.new(),
        processes = {},
        messageLog = {},
        logLevel = ${this.logLevel}
      }
      
      -- Configure logging
      aolite.emulator:setMessageLog(aolite.logLevel)
      
      print("aolite framework initialized")
    `;

    await this.execLua(initScript);
  }

  /**
   * Spawn a process in aolite
   */
  async spawnProcess(processPath) {
    if (!this.initialized) {
      await this.initialize();
    }

    const processName = path.basename(processPath, ".lua");
    const processId = `${processName}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;

    console.log(chalk.blue(`📦 Spawning process: ${processName} -> ${processId}`));

    const spawnScript = `
      -- Read process file
      local file = io.open("${processPath}", "r")
      if not file then
        error("Process file not found: ${processPath}")
      end
      
      local processCode = file:read("*all")
      file:close()
      
      -- Spawn process in aolite
      local success, result = pcall(function()
        return aolite.emulator:spawnProcess("${processId}", processCode)
      end)
      
      if success then
        aolite.processes["${processId}"] = {
          id = "${processId}",
          name = "${processName}",
          path = "${processPath}",
          spawnedAt = os.time(),
          status = "running"
        }
        print("Process spawned successfully: ${processId}")
        return "${processId}"
      else
        error("Failed to spawn process: " .. tostring(result))
      end
    `;

    try {
      const _result = await this.execLua(spawnScript);
      this.processes.set(processId, {
        id: processId,
        name: processName,
        path: processPath,
        spawnedAt: Date.now(),
        status: "running",
      });

      console.log(chalk.green(`✅ Process spawned: ${processName} -> ${processId}`));
      return processId;
    } catch (error) {
      console.log(chalk.red(`❌ Failed to spawn process ${processName}: ${error.message}`));
      throw error;
    }
  }

  /**
   * Send message to a process
   */
  async sendMessage(processId, message) {
    if (!this.processes.has(processId)) {
      throw new Error(`Process ${processId} not found`);
    }

    console.log(chalk.blue(`📤 Sending message to ${processId}: ${message.Action}`));

    const messageScript = `
      -- Prepare message
      local message = {
        Id = "msg-" .. tostring(os.time()) .. "-" .. math.random(10000, 99999),
        From = "test-harness",
        Target = "${processId}",
        Action = "${message.Action}",
        Data = ${this.luaStringify(message.Data || {})},
        Timestamp = tostring(os.time()),
        Tags = ${this.luaStringify(message.Tags || {})}
      }
      
      -- Add GameState if provided
      ${message.GameState ? `message.GameState = ${this.luaStringify(message.GameState)}` : ""}
      
      -- Send message through aolite
      local success, response = pcall(function()
        return aolite.emulator:send("${processId}", message)
      end)
      
      if success and response then
        -- Log message for debugging
        table.insert(aolite.messageLog, {
          timestamp = os.time(),
          processId = "${processId}",
          action = "${message.Action}",
          success = true,
          response = response
        })
        
        -- Return response data
        return response
      else
        -- Log error
        table.insert(aolite.messageLog, {
          timestamp = os.time(),
          processId = "${processId}",
          action = "${message.Action}",
          success = false,
          error = tostring(response or "No response")
        })
        
        error("Message failed: " .. tostring(response or "No response"))
      end
    `;

    try {
      const result = await this.execLua(messageScript);

      // Parse the result if it's a JSON string
      let parsedResult;
      try {
        parsedResult = JSON.parse(result);
      } catch (_e) {
        parsedResult = { success: true, data: result };
      }

      console.log(chalk.green(`✅ Message sent to ${processId}: ${message.Action}`));

      return parsedResult;
    } catch (error) {
      console.log(chalk.red(`❌ Message failed for ${processId}: ${error.message}`));
      throw error;
    }
  }

  /**
   * Get all messages for a process
   */
  async getProcessMessages(processId) {
    const getMessagesScript = `
      local messages = aolite.emulator:getAllMsgs("${processId}")
      if messages then
        return messages
      else
        return {}
      end
    `;

    try {
      const result = await this.execLua(getMessagesScript);
      return JSON.parse(result);
    } catch (error) {
      console.warn(chalk.yellow(`Warning: Could not get messages for ${processId}: ${error.message}`));
      return [];
    }
  }

  /**
   * Get process state
   */
  async getProcessState(processId) {
    const getStateScript = `
      -- Use state inspector to get current process state
      local success, state = pcall(function()
        return aolite.inspector:inspectProcessState("${processId}")
      end)
      
      if success and state then
        return state
      else
        return { error = "Could not inspect process state: " .. tostring(state) }
      end
    `;

    try {
      const result = await this.execLua(getStateScript);
      return JSON.parse(result);
    } catch (error) {
      console.warn(chalk.yellow(`Warning: Could not get state for ${processId}: ${error.message}`));
      return { error: error.message };
    }
  }

  /**
   * Remove/stop a process
   */
  async removeProcess(processId) {
    if (!this.processes.has(processId)) {
      throw new Error(`Process ${processId} not found`);
    }

    const removeScript = `
      -- Remove process from aolite
      local success, result = pcall(function()
        aolite.processes["${processId}"] = nil
        return true
      end)
      
      if success then
        print("Process removed: ${processId}")
        return true
      else
        error("Failed to remove process: " .. tostring(result))
      end
    `;

    try {
      await this.execLua(removeScript);

      const process = this.processes.get(processId);
      process.status = "stopped";
      process.stoppedAt = Date.now();

      console.log(chalk.yellow(`🛑 Process removed: ${processId}`));
      return true;
    } catch (error) {
      console.log(chalk.red(`❌ Failed to remove process ${processId}: ${error.message}`));
      throw error;
    }
  }

  /**
   * Run the aolite scheduler
   */
  async runScheduler() {
    const runSchedulerScript = `
      local success, result = pcall(function()
        return aolite.emulator:runScheduler()
      end)
      
      if success then
        return result or "Scheduler run completed"
      else
        error("Scheduler failed: " .. tostring(result))
      end
    `;

    try {
      const result = await this.execLua(runSchedulerScript);
      console.log(chalk.blue("⚡ Scheduler run completed"));
      return result;
    } catch (error) {
      console.log(chalk.red(`❌ Scheduler failed: ${error.message}`));
      throw error;
    }
  }

  /**
   * Get framework statistics
   */
  async getStatistics() {
    const statsScript = `
      local stats = {
        processCount = 0,
        messageCount = #aolite.messageLog,
        activeProcesses = {},
        recentMessages = {}
      }
      
      -- Count processes
      for id, process in pairs(aolite.processes) do
        stats.processCount = stats.processCount + 1
        table.insert(stats.activeProcesses, {
          id = id,
          name = process.name,
          status = process.status
        })
      end
      
      -- Get recent messages
      local recentCount = math.min(10, #aolite.messageLog)
      for i = #aolite.messageLog - recentCount + 1, #aolite.messageLog do
        if aolite.messageLog[i] then
          table.insert(stats.recentMessages, aolite.messageLog[i])
        end
      end
      
      return stats
    `;

    try {
      const result = await this.execLua(statsScript);
      return JSON.parse(result);
    } catch (error) {
      console.warn(chalk.yellow(`Warning: Could not get statistics: ${error.message}`));
      return {
        processCount: this.processes.size,
        messageCount: 0,
        activeProcesses: Array.from(this.processes.values()),
        recentMessages: [],
      };
    }
  }

  /**
   * Execute Lua code
   */
  async execLua(luaCode) {
    return new Promise((resolve, reject) => {
      const lua = spawn(this.luaExecutable, ["-e", luaCode]);

      let stdout = "";
      let stderr = "";

      lua.stdout.on("data", data => {
        stdout += data.toString();
      });

      lua.stderr.on("data", data => {
        stderr += data.toString();
      });

      lua.on("close", code => {
        if (code === 0) {
          resolve(stdout.trim());
        } else {
          reject(new Error(`Lua execution failed (code ${code}): ${stderr || stdout}`));
        }
      });

      lua.on("error", error => {
        reject(new Error(`Failed to execute Lua: ${error.message}`));
      });
    });
  }

  /**
   * Convert JavaScript object to Lua table string
   */
  luaStringify(obj) {
    if (obj === null || obj === undefined) {
      return "nil";
    }

    if (typeof obj === "string") {
      return `"${obj.replace(/"/g, '\\"')}"`;
    }

    if (typeof obj === "number" || typeof obj === "boolean") {
      return obj.toString();
    }

    if (Array.isArray(obj)) {
      const items = obj.map(item => this.luaStringify(item));
      return `{${items.join(", ")}}`;
    }

    if (typeof obj === "object") {
      const pairs = Object.entries(obj).map(([key, value]) => {
        const luaKey = /^[a-zA-Z_][a-zA-Z0-9_]*$/.test(key) ? key : `["${key}"]`;
        return `${luaKey} = ${this.luaStringify(value)}`;
      });
      return `{${pairs.join(", ")}}`;
    }

    return "nil";
  }

  /**
   * Cleanup aolite framework
   */
  async cleanup() {
    console.log(chalk.blue("🧹 Cleaning up aolite framework..."));

    const cleanupScript = `
      -- Stop all processes
      for id, process in pairs(aolite.processes) do
        aolite.processes[id] = nil
      end
      
      -- Clear message log
      aolite.messageLog = {}
      
      print("aolite framework cleaned up")
    `;

    try {
      await this.execLua(cleanupScript);
      this.processes.clear();
      this.messageLog = [];
      console.log(chalk.green("✅ aolite framework cleanup completed"));
    } catch (error) {
      console.warn(chalk.yellow(`Warning: aolite cleanup encountered issues: ${error.message}`));
    }
  }
}

export { AoliteFramework };
