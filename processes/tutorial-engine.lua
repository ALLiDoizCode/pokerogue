--[[
  Tutorial Engine Process

  Manages interactive tutorial progression and skill validation for PokéRogue.

  Handlers:
  - StartTutorial: Initialize tutorial and check if already completed
  - CompleteTutorialStep: Mark tutorial step complete and advance
  - GetTutorialProgress: Return current tutorial state and statistics
  - ValidateTutorialSkill: Check player skill progression and validate completion

  ADP v1.0 Compliant: Self-documenting with Info handler

  Dependencies: None (monolithic design with embedded data)
  Size: ~25-35KB (tutorial definitions, progression logic, text content)
]]

local json = require("json")

-- ============================================================================
-- TUTORIAL TYPE CONSTANTS
-- ============================================================================

local TutorialType = {
  INTRO = "INTRO",
  ACCESS_MENU = "ACCESS_MENU",
  MENU = "MENU",
  STARTER_SELECT = "STARTER_SELECT",
  POKEDEX = "POKEDEX",
  POKERUS = "POKERUS",
  STAT_CHANGE = "STAT_CHANGE",
  SELECT_ITEM = "SELECT_ITEM",
  EGG_GACHA = "EGG_GACHA"
}

-- Tutorial type order for progression
local TUTORIAL_ORDER = {
  "INTRO",
  "ACCESS_MENU",
  "MENU",
  "STARTER_SELECT",
  "POKEDEX",
  "POKERUS",
  "STAT_CHANGE",
  "SELECT_ITEM",
  "EGG_GACHA"
}

-- ============================================================================
-- TUTORIAL TEXT CONTENT (Embedded from i18n)
-- ============================================================================

local TUTORIAL_TEXT = {
  [TutorialType.INTRO] = "Welcome to PokéRogue! This is a battle-focused Pokémon fangame with roguelite elements.$This game is not monetized and we claim no ownership of Pokémon nor of the copyrighted assets used.$The game is a work in progress, but fully playable.\nFor bug reports, please use the Discord community.$If the game runs slowly, please ensure \"Hardware Acceleration\" is turned on in your browser settings.",

  [TutorialType.ACCESS_MENU] = "To access the menu, press M or Escape while awaiting input.\nThe menu contains settings and various features.",

  [TutorialType.MENU] = "From this menu you can access the settings.$From the settings you can change game speed, window style, and other options.$There are also various other features here, so be sure to check them all!",

  [TutorialType.STARTER_SELECT] = "From this screen, you can select your starters by pressing\nZ or the Space bar. These are your initial party members.$Each starter has a value. Your party can have up to\n6 members as long as the total does not exceed 10.$You can also select gender, ability, and form depending on\nthe variants you've caught or hatched.$The IVs for a species are also the best of every one you've\ncaught or hatched, so try to get lots of the same species!",

  [TutorialType.POKEDEX] = "A daily random 5 selectable starters have a purple border.$If you see a starter you own with one of these,\ntry adding it to your party. Be sure to check its summary!",

  [TutorialType.POKERUS] = "A daily random 5 selectable starters have a purple border.$If you see a starter you own with one of these,\ntry adding it to your party. Be sure to check its summary!",

  [TutorialType.STAT_CHANGE] = "Stat changes persist across battles as long as your Pokémon aren't recalled.$Your Pokémon are recalled before a trainer battle and before entering a new biome.$You can view the stat changes for any Pokémon on the field by holding C or Shift.$You can also view the moveset for an enemy Pokémon by holding V.$This only reveals moves that you've seen the Pokémon use this battle.",

  [TutorialType.SELECT_ITEM] = "After every battle, you are given a choice of 3 random items.\nYou may only pick one.$These range from consumables, to Pokémon held items, to passive permanent items.$Most non-consumable item effects will stack in various ways.$Some items will only show up if they can be used, such as evolution items.$You can also transfer held items between Pokémon using the transfer option.$The transfer option will appear in the bottom right once you have obtained a held item.$You may purchase consumable items with money, and a larger variety will be available the further you get.$Be sure to buy these before you pick your random item, as it will progress to the next battle once you do.",

  [TutorialType.EGG_GACHA] = "From this screen, you can redeem your vouchers for\nPokémon Eggs.$Eggs have to be hatched and get closer to hatching after\nevery battle. Rarer Eggs take longer to hatch.$Hatched Pokémon also won't be added to your party, they will\nbe added to your starters.$Pokémon hatched from Eggs generally have better IVs than\nwild Pokémon.$Some Pokémon can only even be obtained from Eggs.$There are 3 different machines to pull from with different\nbonuses, so pick the one that suits you best!"
}

-- ============================================================================
-- TUTORIAL DEFINITIONS
-- ============================================================================

local TUTORIAL_DEFINITIONS = {
  [TutorialType.INTRO] = {
    type = TutorialType.INTRO,
    text = TUTORIAL_TEXT[TutorialType.INTRO],
    totalSteps = 1,
    prerequisites = {},
    skillChecks = {},
    overlay = {
      required = false,
      duration = 0
    },
    uiContext = {
      modeSwitch = nil,
      disableMenu = true
    },
    nextTutorial = TutorialType.ACCESS_MENU
  },

  [TutorialType.ACCESS_MENU] = {
    type = TutorialType.ACCESS_MENU,
    text = TUTORIAL_TEXT[TutorialType.ACCESS_MENU],
    totalSteps = 1,
    prerequisites = {},
    skillChecks = {},
    overlay = {
      required = true,
      duration = 1000,
      fadeIn = 750,
      fadeOut = 1000
    },
    uiContext = {
      modeSwitch = nil,
      disableMenu = true
    },
    nextTutorial = TutorialType.MENU,
    skipCondition = "enableTouchControls"
  },

  [TutorialType.MENU] = {
    type = TutorialType.MENU,
    text = TUTORIAL_TEXT[TutorialType.MENU],
    totalSteps = 1,
    prerequisites = {TutorialType.ACCESS_MENU},
    skillChecks = {},
    overlay = {
      required = false,
      duration = 0
    },
    uiContext = {
      modeSwitch = nil,
      disableMenu = true
    },
    nextTutorial = TutorialType.STARTER_SELECT
  },

  [TutorialType.STARTER_SELECT] = {
    type = TutorialType.STARTER_SELECT,
    text = TUTORIAL_TEXT[TutorialType.STARTER_SELECT],
    totalSteps = 1,
    prerequisites = {TutorialType.INTRO},
    skillChecks = {"starterSelected"},
    overlay = {
      required = false,
      duration = 0
    },
    uiContext = {
      modeSwitch = nil,
      disableMenu = true
    },
    nextTutorial = TutorialType.POKEDEX
  },

  [TutorialType.POKEDEX] = {
    type = TutorialType.POKEDEX,
    text = TUTORIAL_TEXT[TutorialType.POKEDEX],
    totalSteps = 1,
    prerequisites = {},
    skillChecks = {},
    overlay = {
      required = false,
      duration = 0
    },
    uiContext = {
      modeSwitch = nil,
      disableMenu = true
    },
    nextTutorial = nil
  },

  [TutorialType.POKERUS] = {
    type = TutorialType.POKERUS,
    text = TUTORIAL_TEXT[TutorialType.POKERUS],
    totalSteps = 1,
    prerequisites = {},
    skillChecks = {},
    overlay = {
      required = false,
      duration = 0
    },
    uiContext = {
      modeSwitch = nil,
      disableMenu = true
    },
    nextTutorial = nil
  },

  [TutorialType.STAT_CHANGE] = {
    type = TutorialType.STAT_CHANGE,
    text = TUTORIAL_TEXT[TutorialType.STAT_CHANGE],
    totalSteps = 1,
    prerequisites = {},
    skillChecks = {},
    overlay = {
      required = true,
      duration = 1000,
      fadeIn = 750,
      fadeOut = 1000
    },
    uiContext = {
      modeSwitch = nil,
      disableMenu = true
    },
    nextTutorial = nil
  },

  [TutorialType.SELECT_ITEM] = {
    type = TutorialType.SELECT_ITEM,
    text = TUTORIAL_TEXT[TutorialType.SELECT_ITEM],
    totalSteps = 1,
    prerequisites = {},
    skillChecks = {"itemSelected"},
    overlay = {
      required = false,
      duration = 0
    },
    uiContext = {
      modeSwitch = "MODIFIER_SELECT",
      disableMenu = true
    },
    nextTutorial = nil
  },

  [TutorialType.EGG_GACHA] = {
    type = TutorialType.EGG_GACHA,
    text = TUTORIAL_TEXT[TutorialType.EGG_GACHA],
    totalSteps = 1,
    prerequisites = {},
    skillChecks = {},
    overlay = {
      required = false,
      duration = 0
    },
    uiContext = {
      modeSwitch = nil,
      disableMenu = true
    },
    nextTutorial = nil
  }
}

-- ============================================================================
-- DATA VALIDATION FUNCTIONS
-- ============================================================================

-- Validate tutorial type exists
local function isValidTutorialType(tutorialType)
  if not tutorialType then
    return false
  end
  return TUTORIAL_DEFINITIONS[tutorialType] ~= nil
end

-- Validate tutorial state structure
local function validateTutorialState(state)
  if not state then
    return false, "Tutorial state is nil"
  end

  if type(state) ~= "table" then
    return false, "Tutorial state must be a table"
  end

  -- completedTutorials is optional but must be table if present
  if state.completedTutorials and type(state.completedTutorials) ~= "table" then
    return false, "completedTutorials must be a table"
  end

  -- currentTutorial is optional but must be valid type if present
  if state.currentTutorial and not isValidTutorialType(state.currentTutorial) then
    return false, "currentTutorial must be a valid tutorial type"
  end

  return true, nil
end

-- Create empty tutorial state
local function createEmptyTutorialState()
  return {
    completedTutorials = {},
    currentTutorial = nil,
    tutorialProgress = {
      currentStep = 0,
      totalSteps = 0,
      checkpointReached = false
    },
    skillChecks = {},
    statistics = {
      tutorialsCompleted = 0,
      totalTimeSpent = 0,
      stepsCompleted = 0
    }
  }
end

-- Initialize tutorial state if missing
local function initializeTutorialState(playerState)
  if not playerState then
    return createEmptyTutorialState()
  end

  if not playerState.completedTutorials then
    playerState.completedTutorials = {}
  end

  if not playerState.skillChecks then
    playerState.skillChecks = {}
  end

  if not playerState.statistics then
    playerState.statistics = {
      tutorialsCompleted = 0,
      totalTimeSpent = 0,
      stepsCompleted = 0
    }
  end

  return playerState
end

-- ============================================================================
-- TUTORIAL PROGRESSION HELPER FUNCTIONS
-- ============================================================================

-- Check if tutorial is already completed
local function isTutorialCompleted(tutorialType, playerState)
  if not playerState or not playerState.completedTutorials then
    return false
  end

  return playerState.completedTutorials[tutorialType] == true
end

-- Check if prerequisites are met for tutorial
local function arePrerequisitesMet(tutorialType, playerState)
  local tutorial = TUTORIAL_DEFINITIONS[tutorialType]
  if not tutorial or not tutorial.prerequisites then
    return true
  end

  -- Check all prerequisites are completed
  for _, prerequisite in ipairs(tutorial.prerequisites) do
    if not isTutorialCompleted(prerequisite, playerState) then
      return false
    end
  end

  return true
end

-- Check skip condition (e.g., touch controls for ACCESS_MENU)
local function shouldSkipTutorial(tutorialType, playerState)
  local tutorial = TUTORIAL_DEFINITIONS[tutorialType]
  if not tutorial or not tutorial.skipCondition then
    return false
  end

  -- Check skip condition
  if tutorial.skipCondition == "enableTouchControls" then
    return playerState.enableTouchControls == true
  end

  return false
end

-- Mark tutorial as completed
local function markTutorialComplete(tutorialType, playerState, timeSpent)
  if not playerState.completedTutorials then
    playerState.completedTutorials = {}
  end

  playerState.completedTutorials[tutorialType] = true

  -- Update statistics
  if not playerState.statistics then
    playerState.statistics = {
      tutorialsCompleted = 0,
      totalTimeSpent = 0,
      stepsCompleted = 0
    }
  end

  playerState.statistics.tutorialsCompleted = (playerState.statistics.tutorialsCompleted or 0) + 1
  playerState.statistics.totalTimeSpent = (playerState.statistics.totalTimeSpent or 0) + (timeSpent or 0)

  local tutorial = TUTORIAL_DEFINITIONS[tutorialType]
  if tutorial then
    playerState.statistics.stepsCompleted = (playerState.statistics.stepsCompleted or 0) + (tutorial.totalSteps or 1)
  end

  return playerState
end

-- Get next tutorial in sequence
local function getNextTutorial(tutorialType)
  local tutorial = TUTORIAL_DEFINITIONS[tutorialType]
  if tutorial and tutorial.nextTutorial then
    return tutorial.nextTutorial
  end
  return nil
end

-- ============================================================================
-- TUTORIAL PROGRESSION HANDLERS
-- ============================================================================

-- Handler: StartTutorial
-- Initialize tutorial and check if already completed
Handlers.add("start-tutorial",
  Handlers.utils.hasMatchingTag("Action", "StartTutorial"),
  function(msg)
    local tutorialType = msg.TutorialType

    -- Validate tutorial type
    if not tutorialType then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Success = "false",
        Error = "TutorialType required"
      })
      return
    end

    if not isValidTutorialType(tutorialType) then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Success = "false",
        Error = "Invalid tutorial type: " .. tutorialType
      })
      return
    end

    -- Parse player state
    local playerState = {}
    if msg.Data and msg.Data ~= "" then
      playerState = json.decode(msg.Data)
    end

    -- Initialize tutorial state if missing
    playerState = initializeTutorialState(playerState)

    -- Check if tutorial should be skipped (e.g., touch controls)
    if shouldSkipTutorial(tutorialType, playerState) then
      ao.send({
        Target = msg.From,
        Action = "SaveState",
        Success = "true",
        Data = json.encode({
          success = true,
          tutorialType = tutorialType,
          shouldDisplay = false,
          reason = "Skip condition met",
          nextTutorial = getNextTutorial(tutorialType)
        })
      })
      return
    end

    -- Check if tutorial already completed
    if isTutorialCompleted(tutorialType, playerState) then
      ao.send({
        Target = msg.From,
        Action = "SaveState",
        Success = "true",
        Data = json.encode({
          success = true,
          tutorialType = tutorialType,
          shouldDisplay = false,
          reason = "Already completed",
          completedAt = playerState.completedTutorials[tutorialType]
        })
      })
      return
    end

    -- Check prerequisites
    if not arePrerequisitesMet(tutorialType, playerState) then
      local tutorial = TUTORIAL_DEFINITIONS[tutorialType]
      ao.send({
        Target = msg.From,
        Action = "Error",
        Success = "false",
        Error = "Prerequisites not met",
        Prerequisites = json.encode(tutorial.prerequisites or {})
      })
      return
    end

    -- Get tutorial definition
    local tutorial = TUTORIAL_DEFINITIONS[tutorialType]

    -- Return tutorial definition with display instructions
    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      Data = json.encode({
        success = true,
        tutorialType = tutorialType,
        shouldDisplay = true,
        currentStep = 1,
        totalSteps = tutorial.totalSteps,
        text = tutorial.text,
        overlay = tutorial.overlay,
        uiContext = tutorial.uiContext,
        nextTutorial = tutorial.nextTutorial
      })
    })
  end
)

-- Handler: CompleteTutorialStep
-- Mark tutorial step complete and advance to next
Handlers.add("complete-tutorial-step",
  Handlers.utils.hasMatchingTag("Action", "CompleteTutorialStep"),
  function(msg)
    local tutorialType = msg.TutorialType
    local stepCompleted = tonumber(msg.StepCompleted) or 1
    local timeSpent = tonumber(msg.TimeSpent) or 0

    -- Validate tutorial type
    if not tutorialType then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Success = "false",
        Error = "TutorialType required"
      })
      return
    end

    if not isValidTutorialType(tutorialType) then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Success = "false",
        Error = "Invalid tutorial type: " .. tutorialType
      })
      return
    end

    -- Parse player state
    local playerState = {}
    if msg.Data and msg.Data ~= "" then
      playerState = json.decode(msg.Data)
    end

    playerState = initializeTutorialState(playerState)

    -- Get tutorial definition
    local tutorial = TUTORIAL_DEFINITIONS[tutorialType]

    -- Check if this was the last step
    local tutorialCompleted = stepCompleted >= tutorial.totalSteps

    if tutorialCompleted then
      -- Mark tutorial as complete
      playerState = markTutorialComplete(tutorialType, playerState, timeSpent)
    end

    -- Get next tutorial
    local nextTutorial = nil
    if tutorialCompleted then
      nextTutorial = tutorial.nextTutorial
    end

    -- Response with completion status
    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      Data = json.encode({
        success = true,
        tutorialType = tutorialType,
        stepCompleted = stepCompleted,
        tutorialCompleted = tutorialCompleted,
        nextTutorial = nextTutorial,
        progressUpdated = {
          completedTutorials = playerState.completedTutorials,
          statistics = playerState.statistics
        }
      })
    })
  end
)

-- Handler: GetTutorialProgress
-- Return current tutorial state and statistics
Handlers.add("get-tutorial-progress",
  Handlers.utils.hasMatchingTag("Action", "GetTutorialProgress"),
  function(msg)
    -- Parse player state
    local playerState = {}
    if msg.Data and msg.Data ~= "" then
      playerState = json.decode(msg.Data)
    end

    playerState = initializeTutorialState(playerState)

    -- Build response with complete progress
    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      Data = json.encode({
        success = true,
        completedTutorials = playerState.completedTutorials or {},
        currentTutorial = playerState.currentTutorial,
        tutorialProgress = playerState.tutorialProgress,
        skillChecks = playerState.skillChecks or {},
        statistics = playerState.statistics or {
          tutorialsCompleted = 0,
          totalTimeSpent = 0,
          stepsCompleted = 0
        }
      })
    })
  end
)

-- Handler: CheckTutorialStatus
-- Query if specific tutorial is completed
Handlers.add("check-tutorial-status",
  Handlers.utils.hasMatchingTag("Action", "CheckTutorialStatus"),
  function(msg)
    local tutorialType = msg.TutorialType

    -- Validate tutorial type
    if not tutorialType then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Success = "false",
        Error = "TutorialType required"
      })
      return
    end

    if not isValidTutorialType(tutorialType) then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Success = "false",
        Error = "Invalid tutorial type: " .. tutorialType
      })
      return
    end

    -- Parse player state
    local playerState = {}
    if msg.Data and msg.Data ~= "" then
      playerState = json.decode(msg.Data)
    end

    playerState = initializeTutorialState(playerState)

    -- Check completion status
    local isCompleted = isTutorialCompleted(tutorialType, playerState)

    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      Data = json.encode({
        success = true,
        tutorialType = tutorialType,
        isCompleted = isCompleted
      })
    })
  end
)

-- ============================================================================
-- TUTORIAL SKILL VALIDATION HANDLER
-- ============================================================================

-- Handler: ValidateTutorialSkill
-- Check player skill progression and validate completion
Handlers.add("validate-tutorial-skill",
  Handlers.utils.hasMatchingTag("Action", "ValidateTutorialSkill"),
  function(msg)
    local tutorialType = msg.TutorialType
    local skillCheck = msg.SkillCheck

    -- Validate required parameters
    if not tutorialType then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Success = "false",
        Error = "TutorialType required"
      })
      return
    end

    if not skillCheck then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Success = "false",
        Error = "SkillCheck required"
      })
      return
    end

    if not isValidTutorialType(tutorialType) then
      ao.send({
        Target = msg.From,
        Action = "Error",
        Success = "false",
        Error = "Invalid tutorial type: " .. tutorialType
      })
      return
    end

    -- Parse player action data
    local actionData = {}
    if msg.Data and msg.Data ~= "" then
      actionData = json.decode(msg.Data)
    end

    -- Get tutorial definition
    local tutorial = TUTORIAL_DEFINITIONS[tutorialType]

    -- Check if this tutorial requires skill checks
    local requiresSkillCheck = false
    if tutorial.skillChecks then
      for _, requiredSkill in ipairs(tutorial.skillChecks) do
        if requiredSkill == skillCheck then
          requiresSkillCheck = true
          break
        end
      end
    end

    if not requiresSkillCheck then
      ao.send({
        Target = msg.From,
        Action = "SaveState",
        Success = "true",
        Data = json.encode({
          success = true,
          skillCheckPassed = true,
          skillCheckName = skillCheck,
          canProgress = true,
          feedback = "No skill check required for this tutorial"
        })
      })
      return
    end

    -- Validate specific skill checks
    local skillCheckPassed = false
    local feedback = ""

    if skillCheck == "starterSelected" then
      -- STARTER_SELECT tutorial
      skillCheckPassed = actionData.starterSelected == true
      feedback = skillCheckPassed
        and "Great! You successfully selected a starter Pokémon."
        or "Please select a starter Pokémon to continue."

    elseif skillCheck == "itemSelected" then
      -- SELECT_ITEM tutorial
      skillCheckPassed = actionData.itemSelected == true
      feedback = skillCheckPassed
        and "Excellent! You selected an item."
        or "Please select an item to continue."

    elseif skillCheck == "menuNavigated" then
      -- MENU tutorial
      skillCheckPassed = actionData.menuOpened == true and actionData.correctInput == true
      feedback = skillCheckPassed
        and "Perfect! You successfully navigated the menu."
        or "Please try opening the menu using the correct input."

    else
      -- Unknown skill check
      ao.send({
        Target = msg.From,
        Action = "Error",
        Success = "false",
        Error = "Unknown skill check: " .. skillCheck
      })
      return
    end

    -- Response with validation result
    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      Data = json.encode({
        success = true,
        skillCheckPassed = skillCheckPassed,
        skillCheckName = skillCheck,
        canProgress = skillCheckPassed,
        feedback = feedback
      })
    })
  end
)

-- ============================================================================
-- ADP INFO HANDLER
-- ============================================================================

-- Handler: Info
-- Return process information and capabilities (ADP v1.0 compliant)
Handlers.add("info",
  Handlers.utils.hasMatchingTag("Action", "Info"),
  function(msg)
    ao.send({
      Target = msg.From,
      Action = "SaveState",
      Success = "true",
      Data = json.encode({
        process = {
          name = "Tutorial Engine",
          version = "1.0.0",
          adpVersion = "1.0",
          capabilities = {
            "StartTutorial",
            "CompleteTutorialStep",
            "GetTutorialProgress",
            "CheckTutorialStatus",
            "ValidateTutorialSkill"
          },
          messageSchemas = {
            StartTutorial = {
              required = {"Action", "TutorialType", "Data"},
              tags = {"TutorialType"},
              data = "JSON: {enableTutorials, enableTouchControls, completedTutorials}"
            },
            CompleteTutorialStep = {
              required = {"Action", "TutorialType"},
              tags = {"TutorialType", "StepCompleted", "TimeSpent"},
              data = "JSON: {completedTutorials, statistics}"
            },
            GetTutorialProgress = {
              required = {"Action"},
              tags = {},
              data = "JSON: {completedTutorials, currentTutorial, statistics} (optional)"
            },
            CheckTutorialStatus = {
              required = {"Action", "TutorialType"},
              tags = {"TutorialType"},
              data = "JSON: {completedTutorials} (optional)"
            },
            ValidateTutorialSkill = {
              required = {"Action", "TutorialType", "SkillCheck"},
              tags = {"TutorialType", "SkillCheck"},
              data = "JSON: {playerAction, actionData}"
            }
          }
        },
        handlers = {
          "start-tutorial",
          "complete-tutorial-step",
          "get-tutorial-progress",
          "check-tutorial-status",
          "validate-tutorial-skill",
          "info"
        },
        tutorialTypes = {
          "INTRO",
          "ACCESS_MENU",
          "MENU",
          "STARTER_SELECT",
          "POKEDEX",
          "POKERUS",
          "STAT_CHANGE",
          "SELECT_ITEM",
          "EGG_GACHA"
        },
        documentation = {
          adpCompliance = "v1.0",
          selfDocumenting = true,
          description = "Interactive tutorial progression and skill validation system for PokéRogue"
        }
      })
    })
  end
)

print("Tutorial Engine Process loaded successfully")
