-- ============================================================================
-- Dialogue Navigation Engine Process
-- ============================================================================
-- Epic 19: Mystery Encounter System
-- Story 19.2: Dialogue Tree Navigation & Flow Migration
--
-- Purpose: Stateless AO process for dialogue tree navigation, option
--          validation, token replacement, and consequence calculation
--
-- Architecture: Dialogue flow state machine (intro → options → selected → outro)
--               Integrates with Story 19.1 requirement validators
--               ADP v1.0 compliant with self-documentation
--
-- Process Size Estimate: ~150 KB (well within 500KB limit)
-- Performance Target: All handlers <10ms execution
-- ============================================================================

local json = require("json")

-- ============================================================================
-- Mock AO Environment for Testing
-- ============================================================================
-- This section provides compatibility when running outside AO runtime
if not ao then
    ao = {
        send = function(msg)
            print("Mock ao.send:", json.encode(msg))
        end,
        id = "dialogue_navigation_engine_process_id"
    }
end

if not Handlers then
    Handlers = {
        add = function(name, matcher, handler)
            print("Handler registered:", name)
        end,
        utils = {
            hasMatchingTag = function(tagName, tagValue)
                return function(msg)
                    if type(tagValue) == "table" then
                        for _, v in ipairs(tagValue) do
                            if msg[tagName] == v then
                                return true
                            end
                        end
                        return false
                    else
                        return msg[tagName] == tagValue
                    end
                end
            end
        }
    }
end

-- ============================================================================
-- Dialogue Phase Enumerations
-- ============================================================================

local DIALOGUE_PHASES = {
    INTRO = "intro",
    OPTIONS = "options",
    SELECTED = "selected",
    OUTRO = "outro"
}

local CONSEQUENCE_TYPES = {
    IMMEDIATE = "immediate",
    DEFERRED = "deferred"
}

local TEXT_STYLES = {
    DEFAULT = "default",
    EMPHASIS = "emphasis",
    WARNING = "warning",
    SUCCESS = "success"
}

-- ============================================================================
-- Process Metadata (ADP v1.0 Compliance)
-- ============================================================================

local PROCESS_METADATA = {
    name = "Dialogue Navigation Engine",
    version = "1.0.0",
    adpVersion = "1.0",
    processId = ao.id or "dialogue-navigation-engine-adp",
    description = "Stateless dialogue tree navigation, option validation, token replacement, and consequence calculation",
    capabilities = {
        "GetDialogueFlow",
        "ValidateOptionSelection",
        "ProcessDialogueTokens",
        "GetOptionConsequences",
        "TrackDialogueChoice",
        "Info"
    },
    handlers = {
        GetDialogueFlow = {
            description = "Retrieve dialogue content for specific phase of encounter",
            inputTags = {"EncounterType", "DialoguePhase"},
            inputData = "Encounter definition JSON",
            outputTags = {"PhaseType", "Success", "Error"},
            outputData = "Dialogue content JSON for requested phase",
            required = {"EncounterType", "DialoguePhase"}
        },
        ValidateOptionSelection = {
            description = "Validate if player can select specific option based on requirements",
            inputTags = {"EncounterType", "OptionIndex"},
            inputData = "Game state JSON",
            outputTags = {"Valid", "OptionEnabled", "RequirementsMet", "Error"},
            outputData = "Validation result with failed requirements list",
            required = {"EncounterType", "OptionIndex"}
        },
        ProcessDialogueTokens = {
            description = "Replace {{tokenName}} placeholders with actual values",
            inputTags = {"DialogueText"},
            inputData = "Dialogue tokens map JSON",
            outputTags = {"Success", "TokenCount"},
            outputData = "Processed text with tokens replaced",
            required = {"DialogueText"}
        },
        GetOptionConsequences = {
            description = "Calculate consequences of selecting specific option",
            inputTags = {"EncounterType", "OptionIndex"},
            inputData = "Game state JSON",
            outputTags = {"HasConsequences", "ConsequenceType", "Success"},
            outputData = "Consequence definition JSON",
            required = {"EncounterType", "OptionIndex"}
        },
        TrackDialogueChoice = {
            description = "Record player choice for narrative continuity tracking",
            inputTags = {"EncounterType", "OptionIndex"},
            inputData = "Dialogue history JSON",
            outputTags = {"ChoiceRecorded", "TotalChoices", "Success"},
            outputData = "Updated dialogue history JSON",
            required = {"EncounterType", "OptionIndex"}
        },
        Info = {
            description = "Self-documentation handler (ADP v1.0 compliance)",
            inputTags = {"Action"},
            inputData = "None",
            outputTags = {"Success"},
            outputData = "Process metadata JSON",
            required = {"Action"}
        }
    }
}

-- ============================================================================
-- ADP v1.0 Info Handler
-- ============================================================================

Handlers.add("info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Success = "true",
            Data = json.encode({
                process = {
                    name = PROCESS_METADATA.name,
                    version = PROCESS_METADATA.version,
                    adpVersion = PROCESS_METADATA.adpVersion,
                    description = PROCESS_METADATA.description,
                    capabilities = PROCESS_METADATA.capabilities
                },
                handlers = PROCESS_METADATA.handlers,
                documentation = {
                    adpCompliance = "v1.0",
                    selfDocumenting = true,
                    epic = "Epic 19: Mystery Encounter System",
                    story = "Story 19.2: Dialogue Tree Navigation & Flow Migration"
                }
            })
        })
    end
)

-- ============================================================================
-- Dialogue Flow Data Structures
-- ============================================================================

-- TextDisplay: Individual dialogue message with optional speaker and style
-- [Source: src/data/mystery-encounters/mystery-encounter-dialogue.ts:3-7]
local function createTextDisplay(speaker, text, style)
    return {
        speaker = speaker,  -- Optional speaker name
        text = text or "",  -- Dialogue text content or i18n key
        style = style or TEXT_STYLES.DEFAULT  -- Optional text styling
    }
end

-- OptionTextDisplay: Button labels, tooltips, and selected dialogue for each choice
-- [Source: src/data/mystery-encounters/mystery-encounter-dialogue.ts:9-17]
local function createOptionTextDisplay(config)
    config = config or {}
    return {
        buttonLabel = config.buttonLabel or "",  -- Main button text (keep short)
        buttonTooltip = config.buttonTooltip,  -- Optional tooltip on hover
        disabledButtonLabel = config.disabledButtonLabel,  -- Text when option disabled
        disabledButtonTooltip = config.disabledButtonTooltip,
        secondOptionPrompt = config.secondOptionPrompt,  -- Secondary confirmation prompt
        selected = config.selected or {},  -- Dialogue shown after selecting option (TextDisplay[])
        style = config.style or TEXT_STYLES.DEFAULT
    }
end

-- EncounterOptionsDialogue: Container with title, description, query, and options array
-- [Source: src/data/mystery-encounters/mystery-encounter-dialogue.ts:19-25]
local function createEncounterOptionsDialogue(config)
    config = config or {}

    -- Validation: Minimum 2 options required
    local options = config.options or {}
    if #options < 2 then
        return nil, "EncounterOptionsDialogue requires minimum 2 options"
    end

    return {
        title = config.title,  -- Top of description box
        description = config.description,  -- Middle of description box
        query = config.query,  -- Question at bottom (keep short)
        options = options  -- Minimum 2 options required
    }
end

-- MysteryEncounterDialogue: Top-level flow (intro → encounterOptionsDialogue → outro)
-- [Source: src/data/mystery-encounters/mystery-encounter-dialogue.ts:70-74]
local function createMysteryEncounterDialogue(config)
    config = config or {}
    return {
        intro = config.intro or {},  -- Opening dialogue sequence (TextDisplay[])
        encounterOptionsDialogue = config.encounterOptionsDialogue,  -- Choice presentation
        outro = config.outro or {}  -- Closing dialogue sequence (TextDisplay[])
    }
end

-- ============================================================================
-- Dialogue Flow Navigation Functions
-- ============================================================================

-- Get dialogue flow for specific phase of encounter
-- [Source: Implementation Guidance section]
local function getDialogueFlow(encounterType, dialoguePhase, encounterDefinition)
    if not encounterDefinition then
        return nil, "Encounter definition required"
    end

    local dialogue = encounterDefinition.dialogue

    if dialoguePhase == DIALOGUE_PHASES.INTRO then
        return dialogue and dialogue.intro or {}
    elseif dialoguePhase == DIALOGUE_PHASES.OPTIONS then
        return dialogue and dialogue.encounterOptionsDialogue or {}
    elseif dialoguePhase == DIALOGUE_PHASES.SELECTED then
        -- For SELECTED phase, requires optionIndex to know which option's selected dialogue to show
        -- This will be handled in the handler with optionIndex parameter
        return nil, "SELECTED phase requires optionIndex parameter"
    elseif dialoguePhase == DIALOGUE_PHASES.OUTRO then
        return dialogue and dialogue.outro or {}
    else
        return nil, "Invalid dialogue phase: " .. tostring(dialoguePhase)
    end
end

-- Validate dialogue phase transitions
-- Legal transitions: INTRO → OPTIONS, OPTIONS → SELECTED, SELECTED → OUTRO
-- [Source: Story requirements - flow state machine]
local function validateDialoguePhaseTransition(fromPhase, toPhase)
    -- Define legal transitions
    local legalTransitions = {
        [DIALOGUE_PHASES.INTRO] = {[DIALOGUE_PHASES.OPTIONS] = true},
        [DIALOGUE_PHASES.OPTIONS] = {[DIALOGUE_PHASES.SELECTED] = true},
        [DIALOGUE_PHASES.SELECTED] = {[DIALOGUE_PHASES.OUTRO] = true}
    }

    -- Allow same-phase transitions (idempotent)
    if fromPhase == toPhase then
        return true
    end

    -- Check if transition is legal
    if legalTransitions[fromPhase] and legalTransitions[fromPhase][toPhase] then
        return true
    end

    return false, "Illegal phase transition: " .. tostring(fromPhase) .. " → " .. tostring(toPhase)
end

-- ============================================================================
-- Placeholder Handlers (To Be Implemented)
-- ============================================================================

-- Handler: GetDialogueFlow
-- Retrieve dialogue content for specific phase of encounter
-- [Source: API Specifications section]
Handlers.add("get-dialogue-flow",
    Handlers.utils.hasMatchingTag("Action", "GetDialogueFlow"),
    function(msg)
        -- Validate required parameters
        local encounterType = msg.EncounterType
        local dialoguePhase = msg.DialoguePhase
        local optionIndex = msg.OptionIndex  -- Optional, required for SELECTED phase

        if not encounterType then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "EncounterType required"
            })
            return
        end

        if not dialoguePhase then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "DialoguePhase required"
            })
            return
        end

        -- Parse encounter definition from Data field
        local encounterDefinition = nil
        if msg.Data and msg.Data ~= "" then
            encounterDefinition = json.decode(msg.Data)
        end

        if not encounterDefinition then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Encounter definition required in Data field"
            })
            return
        end

        -- Get dialogue flow for requested phase
        local dialogueContent, error

        if dialoguePhase == DIALOGUE_PHASES.SELECTED then
            -- SELECTED phase requires optionIndex
            if not optionIndex then
                ao.send({
                    Target = msg.From,
                    Action = "Error",
                    Error = "OptionIndex required for SELECTED phase"
                })
                return
            end

            local optionIdx = tonumber(optionIndex)
            if not optionIdx then
                ao.send({
                    Target = msg.From,
                    Action = "Error",
                    Error = "Invalid OptionIndex (must be number)"
                })
                return
            end

            -- Retrieve selected dialogue from specific option
            if encounterDefinition.options and encounterDefinition.options[optionIdx] then
                dialogueContent = encounterDefinition.options[optionIdx].dialogue and
                                 encounterDefinition.options[optionIdx].dialogue.selected or {}
            else
                ao.send({
                    Target = msg.From,
                    Action = "Error",
                    Error = "Invalid option index: " .. tostring(optionIdx)
                })
                return
            end
        else
            -- Get dialogue for other phases (INTRO, OPTIONS, OUTRO)
            dialogueContent, error = getDialogueFlow(encounterType, dialoguePhase, encounterDefinition)

            if error then
                ao.send({
                    Target = msg.From,
                    Action = "Error",
                    Error = error
                })
                return
            end
        end

        -- Send successful response
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            PhaseType = dialoguePhase,
            Success = "true",
            Data = json.encode(dialogueContent)
        })
    end
)

-- ============================================================================
-- Option Selection Validation Functions
-- ============================================================================

-- Requirement validator registry (embedded from Story 19.1: mystery-encounter-engine.lua)
-- [Source: processes/mystery-encounter-engine.lua:715-753]
local REQUIREMENT_VALIDATORS = {
    WaveRange = function(req, gameState)
        local wave = gameState.waveIndex or 0
        return wave >= req.minWave and wave <= req.maxWave
    end,

    PartySize = function(req, gameState)
        local party = gameState.party or {}
        local partySize = #party
        return partySize >= req.minSize
    end,

    HealthRatio = function(req, gameState)
        local party = gameState.party or {}
        for _, pokemon in ipairs(party) do
            if pokemon.hp and pokemon.maxHp then
                local ratio = pokemon.hp / pokemon.maxHp
                if req.minRatio and ratio < req.minRatio then
                    return false
                end
                if req.maxRatio and ratio > req.maxRatio then
                    return false
                end
            end
        end
        return true
    end,

    StatusEffect = function(req, gameState)
        local party = gameState.party or {}
        local matchCount = 0
        for _, pokemon in ipairs(party) do
            if pokemon.status and pokemon.status == req.statusEffect then
                matchCount = matchCount + 1
            end
        end
        return matchCount >= (req.minCount or 1)
    end,

    MoneyRequirement = function(req, gameState)
        local money = gameState.money or 0
        return money >= req.minMoney
    end
}

-- Validate a single requirement (embedded from Story 19.1)
-- [Source: processes/mystery-encounter-engine.lua:756-762]
local function validateRequirement(requirement, gameState)
    local validator = REQUIREMENT_VALIDATORS[requirement.type]
    if not validator then
        return false  -- Unknown requirement type defaults to invalid
    end
    return validator(requirement, gameState)
end

-- Validate all option requirements
-- [Source: src/data/mystery-encounters/mystery-encounter-option.ts:75-94]
local function validateOptionRequirements(option, gameState)
    if not option or not option.requirements then
        return {valid = true, optionEnabled = true, requirementsMet = true, failedRequirements = {}}
    end

    local failedRequirements = {}

    -- Check scene requirements (EncounterSceneRequirement)
    for _, req in ipairs(option.requirements) do
        if not validateRequirement(req, gameState) then
            table.insert(failedRequirements, {
                type = req.type,
                reason = "Requirement not met"
            })
        end
    end

    -- Check primary Pokemon requirements (if specified)
    if option.primaryPokemonRequirement then
        local primaryPokemon = gameState.primaryPokemon
        if not primaryPokemon or not validateRequirement(option.primaryPokemonRequirement, {party = {primaryPokemon}}) then
            table.insert(failedRequirements, {
                type = "PrimaryPokemonRequirement",
                reason = "Primary Pokemon does not meet requirements"
            })
        end
    end

    -- Check secondary Pokemon requirements (if specified)
    if option.secondaryPokemonRequirement then
        local secondaryPokemon = gameState.secondaryPokemon
        if not secondaryPokemon or not validateRequirement(option.secondaryPokemonRequirement, {party = {secondaryPokemon}}) then
            table.insert(failedRequirements, {
                type = "SecondaryPokemonRequirement",
                reason = "Secondary Pokemon does not meet requirements"
            })
        end
    end

    local requirementsMet = #failedRequirements == 0

    return {
        valid = requirementsMet,
        optionEnabled = requirementsMet,
        requirementsMet = requirementsMet,
        failedRequirements = failedRequirements
    }
end

-- Check if option is enabled (all requirements met)
-- [Source: src/data/mystery-encounters/mystery-encounter-option.ts:75-94]
local function checkOptionEnabled(option, gameState)
    local validation = validateOptionRequirements(option, gameState)
    return validation.optionEnabled
end

-- Handler: ValidateOptionSelection
-- Validate if player can select specific option based on requirements
-- [Source: API Specifications section]
Handlers.add("validate-option-selection",
    Handlers.utils.hasMatchingTag("Action", "ValidateOptionSelection"),
    function(msg)
        -- Validate required parameters
        local encounterType = msg.EncounterType
        local optionIndex = msg.OptionIndex

        if not encounterType then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "EncounterType required"
            })
            return
        end

        if not optionIndex then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "OptionIndex required"
            })
            return
        end

        -- Parse game state from Data field
        local gameState = {}
        if msg.Data and msg.Data ~= "" then
            gameState = json.decode(msg.Data)
        end

        -- Parse option index
        local optionIdx = tonumber(optionIndex)
        if not optionIdx then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Invalid OptionIndex (must be number)"
            })
            return
        end

        -- Get option definition from game state
        -- Note: Options should be provided in gameState.encounter.options
        local encounter = gameState.encounter
        if not encounter or not encounter.options then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Encounter definition with options required in gameState"
            })
            return
        end

        local option = encounter.options[optionIdx]
        if not option then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Invalid option index: " .. tostring(optionIdx)
            })
            return
        end

        -- Validate option requirements
        local validation = validateOptionRequirements(option, gameState)

        -- Send successful response
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Valid = tostring(validation.valid),
            OptionEnabled = tostring(validation.optionEnabled),
            RequirementsMet = tostring(validation.requirementsMet),
            Success = "true",
            Data = json.encode({
                failedRequirements = validation.failedRequirements,
                disabledButtonLabel = option.dialogue and option.dialogue.disabledButtonLabel,
                disabledButtonTooltip = option.dialogue and option.dialogue.disabledButtonTooltip
            })
        })
    end
)

-- ============================================================================
-- Dialogue Token Replacement Functions
-- ============================================================================

-- Process dialogue tokens - replace {{tokenName}} placeholders with values
-- [Source: src/data/mystery-encounters/utils/encounter-dialogue-utils.ts:14-45]
local function processDialogueTokens(text, dialogueTokens)
    if not text or text == "" then
        return text, 0
    end

    if not dialogueTokens then
        dialogueTokens = {}
    end

    local processedText = text
    local tokenCount = 0

    -- Replace {{tokenName}} with values from dialogueTokens map
    -- Using Lua pattern matching: {{(.-)}} captures token name
    processedText = string.gsub(processedText, "{{(.-)}}",  function(tokenName)
        local tokenValue = dialogueTokens[tokenName]
        if tokenValue ~= nil then
            tokenCount = tokenCount + 1
            return tostring(tokenValue)
        else
            -- Missing token - return placeholder with warning marker
            return "{{" .. tokenName .. "}}"
        end
    end)

    return processedText, tokenCount
end

-- Validate dialogue tokens - verify all required tokens are present
-- [Source: Implementation Guidance section]
local function validateDialogueTokens(text, dialogueTokens)
    if not text or text == "" then
        return {valid = true, missingTokens = {}}
    end

    if not dialogueTokens then
        dialogueTokens = {}
    end

    local missingTokens = {}

    -- Find all {{tokenName}} patterns
    for tokenName in string.gmatch(text, "{{(.-)}}") do
        if dialogueTokens[tokenName] == nil then
            table.insert(missingTokens, tokenName)
        end
    end

    return {
        valid = #missingTokens == 0,
        missingTokens = missingTokens
    }
end

-- Handler: ProcessDialogueTokens
-- Replace {{tokenName}} placeholders with actual values
-- [Source: API Specifications section]
Handlers.add("process-dialogue-tokens",
    Handlers.utils.hasMatchingTag("Action", "ProcessDialogueTokens"),
    function(msg)
        -- Validate required parameters
        local dialogueText = msg.DialogueText

        if not dialogueText then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "DialogueText required"
            })
            return
        end

        -- Parse dialogue tokens from Data field
        local dialogueTokens = {}
        if msg.Data and msg.Data ~= "" then
            dialogueTokens = json.decode(msg.Data)
        end

        -- Process token replacement
        local processedText, tokenCount = processDialogueTokens(dialogueText, dialogueTokens)

        -- Send successful response
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Success = "true",
            TokenCount = tostring(tokenCount),
            Data = processedText
        })
    end
)

-- ============================================================================
-- Consequence Calculation Functions
-- ============================================================================

-- Create consequence definition structure
-- [Source: Implementation Guidance section]
local function createConsequenceDefinition(config)
    config = config or {}
    return {
        consequenceType = config.consequenceType or CONSEQUENCE_TYPES.IMMEDIATE,
        rewards = config.rewards or {},
        penalties = config.penalties or {},
        stateChanges = config.stateChanges or {}
    }
end

-- Calculate option consequences
-- [Source: src/data/mystery-encounters/mystery-encounter-option.ts:56-62]
local function calculateOptionConsequences(option, gameState)
    if not option then
        return nil, "Option required for consequence calculation"
    end

    -- Consequences are predefined in option configuration
    local hasConsequences = option.consequences ~= nil

    if not hasConsequences then
        return {
            hasConsequences = false,
            consequenceType = CONSEQUENCE_TYPES.IMMEDIATE,
            rewards = {},
            penalties = {},
            stateChanges = {}
        }
    end

    -- Return predefined consequences
    return {
        hasConsequences = true,
        consequenceType = option.consequences.consequenceType or CONSEQUENCE_TYPES.IMMEDIATE,
        rewards = option.consequences.rewards or {},
        penalties = option.consequences.penalties or {},
        stateChanges = option.consequences.stateChanges or {}
    }
end

-- Validate consequences
-- [Source: Implementation Guidance section]
local function validateConsequences(consequences)
    if not consequences then
        return {valid = true, errors = {}}
    end

    local errors = {}

    -- Validate rewards (no negative items)
    if consequences.rewards then
        for itemType, amount in pairs(consequences.rewards) do
            if type(amount) == "number" and amount < 0 then
                table.insert(errors, "Negative reward amount for " .. itemType)
            end
        end
    end

    -- Validate penalties (ensure valid state changes)
    if consequences.penalties then
        for itemType, amount in pairs(consequences.penalties) do
            if type(amount) == "number" and amount < 0 then
                table.insert(errors, "Negative penalty amount for " .. itemType)
            end
        end
    end

    -- Validate state changes (basic structure check)
    if consequences.stateChanges then
        if type(consequences.stateChanges) ~= "table" then
            table.insert(errors, "State changes must be a table")
        end
    end

    return {
        valid = #errors == 0,
        errors = errors
    }
end

-- Handler: GetOptionConsequences
-- Calculate consequences of selecting specific option
-- [Source: API Specifications section]
Handlers.add("get-option-consequences",
    Handlers.utils.hasMatchingTag("Action", "GetOptionConsequences"),
    function(msg)
        -- Validate required parameters
        local encounterType = msg.EncounterType
        local optionIndex = msg.OptionIndex

        if not encounterType then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "EncounterType required"
            })
            return
        end

        if not optionIndex then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "OptionIndex required"
            })
            return
        end

        -- Parse game state from Data field
        local gameState = {}
        if msg.Data and msg.Data ~= "" then
            gameState = json.decode(msg.Data)
        end

        -- Parse option index
        local optionIdx = tonumber(optionIndex)
        if not optionIdx then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Invalid OptionIndex (must be number)"
            })
            return
        end

        -- Get option definition from game state
        local encounter = gameState.encounter
        if not encounter or not encounter.options then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Encounter definition with options required in gameState"
            })
            return
        end

        local option = encounter.options[optionIdx]
        if not option then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Invalid option index: " .. tostring(optionIdx)
            })
            return
        end

        -- Calculate consequences
        local consequences = calculateOptionConsequences(option, gameState)

        -- Validate consequences
        local validation = validateConsequences(consequences)
        if not validation.valid then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Invalid consequences: " .. table.concat(validation.errors, ", ")
            })
            return
        end

        -- Send successful response
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            HasConsequences = tostring(consequences.hasConsequences),
            ConsequenceType = consequences.consequenceType,
            Success = "true",
            Data = json.encode({
                rewards = consequences.rewards,
                penalties = consequences.penalties,
                stateChanges = consequences.stateChanges
            })
        })
    end
)

-- ============================================================================
-- Dialogue Choice Tracking Functions
-- ============================================================================

-- Track dialogue choice
-- [Source: Implementation Guidance section]
local function trackDialogueChoice(encounterType, optionIndex, dialogueHistory, timestamp)
    dialogueHistory = dialogueHistory or {}

    -- Record choice with timestamp (use msg.Timestamp, not os.time())
    local choice = {
        encounterType = encounterType,
        optionIndex = optionIndex,
        timestamp = timestamp or 0,
        consequencesApplied = false  -- Will be updated when consequences are applied
    }

    table.insert(dialogueHistory, choice)

    return {
        choiceRecorded = true,
        totalChoices = #dialogueHistory,
        dialogueHistory = dialogueHistory
    }
end

-- Get dialogue history
-- [Source: Implementation Guidance section]
local function getDialogueHistory(dialogueHistory, encounterTypeFilter)
    dialogueHistory = dialogueHistory or {}

    if not encounterTypeFilter then
        return dialogueHistory
    end

    -- Filter by encounter type
    local filtered = {}
    for _, choice in ipairs(dialogueHistory) do
        if choice.encounterType == encounterTypeFilter then
            table.insert(filtered, choice)
        end
    end

    return filtered
end

-- Handler: TrackDialogueChoice
-- Record player choice for narrative continuity tracking
-- [Source: API Specifications section]
Handlers.add("track-dialogue-choice",
    Handlers.utils.hasMatchingTag("Action", "TrackDialogueChoice"),
    function(msg)
        -- Validate required parameters
        local encounterType = msg.EncounterType
        local optionIndex = msg.OptionIndex

        if not encounterType then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "EncounterType required"
            })
            return
        end

        if not optionIndex then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "OptionIndex required"
            })
            return
        end

        -- Parse dialogue history from Data field
        local dialogueHistory = {}
        if msg.Data and msg.Data ~= "" then
            dialogueHistory = json.decode(msg.Data)
        end

        -- Parse option index
        local optionIdx = tonumber(optionIndex)
        if not optionIdx then
            ao.send({
                Target = msg.From,
                Action = "Error",
                Error = "Invalid OptionIndex (must be number)"
            })
            return
        end

        -- Track choice with timestamp from message
        local timestamp = msg.Timestamp or 0
        local result = trackDialogueChoice(encounterType, optionIdx, dialogueHistory, timestamp)

        -- Send successful response
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            ChoiceRecorded = tostring(result.choiceRecorded),
            TotalChoices = tostring(result.totalChoices),
            Success = "true",
            Data = json.encode(result.dialogueHistory)
        })
    end
)

print("Dialogue Navigation Engine process initialized.")
