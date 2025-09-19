-- Process Topology Configuration for 26-Process Stateless Architecture
-- Predefined process addresses with no dynamic discovery

local PROCESS_TOPOLOGY = {
  coordinator = {
    ProcessType = "coordinator",
    ProcessId = "coordinator-process",
    Address = "TBD" -- Will be set during deployment
  },

  -- Data Processes (8 total)
  data = {
    {
      ProcessType = "data",
      ProcessId = "pokemon-species-db",
      Address = "TBD"
    },
    {
      ProcessType = "data",
      ProcessId = "moves-database",
      Address = "TBD"
    },
    {
      ProcessType = "data",
      ProcessId = "items-database",
      Address = "TBD"
    },
    {
      ProcessType = "data",
      ProcessId = "abilities-database",
      Address = "TBD"
    },
    {
      ProcessType = "data",
      ProcessId = "type-effectiveness-db",
      Address = "TBD"
    },
    {
      ProcessType = "data",
      ProcessId = "biome-data-db",
      Address = "TBD"
    },
    {
      ProcessType = "data",
      ProcessId = "trainer-data-db",
      Address = "TBD"
    },
    {
      ProcessType = "data",
      ProcessId = "wave-data-db",
      Address = "TBD"
    }
  },

  -- Logic Processes (12 total)
  logic = {
    {
      ProcessType = "logic",
      ProcessId = "battle-engine",
      Address = "TBD"
    },
    {
      ProcessType = "logic",
      ProcessId = "evolution-engine",
      Address = "TBD"
    },
    {
      ProcessType = "logic",
      ProcessId = "capture-engine",
      Address = "TBD"
    },
    {
      ProcessType = "logic",
      ProcessId = "status-effects-engine",
      Address = "TBD"
    },
    {
      ProcessType = "logic",
      ProcessId = "damage-calculator",
      Address = "TBD"
    },
    {
      ProcessType = "logic",
      ProcessId = "turn-processor",
      Address = "TBD"
    },
    {
      ProcessType = "logic",
      ProcessId = "breeding-engine",
      Address = "TBD"
    },
    {
      ProcessType = "logic",
      ProcessId = "shop-manager",
      Address = "TBD"
    },
    {
      ProcessType = "logic",
      ProcessId = "encounter-generator",
      Address = "TBD"
    },
    {
      ProcessType = "logic",
      ProcessId = "modifier-engine",
      Address = "TBD"
    },
    {
      ProcessType = "logic",
      ProcessId = "achievement-processor",
      Address = "TBD"
    },
    {
      ProcessType = "logic",
      ProcessId = "rng-coordinator",
      Address = "TBD"
    }
  },

  -- Specialized Processes (5 total)
  specialized = {
    {
      ProcessType = "specialized",
      ProcessId = "state-validator",
      Address = "TBD"
    },
    {
      ProcessType = "specialized",
      ProcessId = "query-processor",
      Address = "TBD"
    },
    {
      ProcessType = "specialized",
      ProcessId = "save-manager",
      Address = "TBD"
    },
    {
      ProcessType = "specialized",
      ProcessId = "performance-monitor",
      Address = "TBD"
    },
    {
      ProcessType = "specialized",
      ProcessId = "audit-logger",
      Address = "TBD"
    }
  }
}

return PROCESS_TOPOLOGY