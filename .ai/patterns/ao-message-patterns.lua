-- AO Message Patterns: Tags vs Data Field
-- Guidelines for proper message structure in AO processes

-- ✅ CORRECT: Use tags for simple parameters
local speciesId = msg.SpeciesId or msg.Id
local operation = msg.Operation
if speciesId then
    processSpecies(tonumber(speciesId))
end

-- ✅ CORRECT: Use Data field for complex structures
local gameState = nil
if msg.Data and msg.Data ~= "" then
    gameState = json.decode(msg.Data)
end

-- ✅ CORRECT: Use Data field for large blobs
local imageData = msg.Data  -- Raw binary or base64 data
local documentContent = msg.Data  -- Large text content

-- ❌ FORBIDDEN: Simple parameters in Data field
local data = json.decode(msg.Data or "{}")
local id = data.id  -- Should be msg.Id tag instead

-- TAGS: Use for...
-- • Simple identifiers: SpeciesId, PlayerId, BattleId
-- • Enum-like values: Operation, Type, Category
-- • Small strings/numbers: Name, Level, Generation
-- • Flags: Confirmed, Force, Override

-- DATA FIELD: Use for...
-- • Complex objects: gameState, pokemonData, battleResult
-- • Large text content: documentation, descriptions, logs
-- • Binary data: images, files, encrypted payloads
-- • Arrays/lists: multiple items, batch operations
-- • Nested structures: configuration objects, schemas

-- Response Pattern 1: Simple response with individual tags
-- ⚠️ CRITICAL: All tag values MUST be strings
ao.send({
    Target = msg.From,
    Action = "SaveState",
    Success = "true",
    SpeciesId = tostring(result.id),
    SpeciesName = result.name,
    HP = tostring(result.baseStats.hp),
    Attack = tostring(result.baseStats.attack),
    Type1 = tostring(result.types[1]),
    Type2 = result.types[2] and tostring(result.types[2]) or "",
    Generation = tostring(result.generation)
})

-- Response Pattern 2: Complex response using Data field
ao.send({
    Target = msg.From,
    Action = "SaveState",
    Data = json.encode({
        species = speciesData,
        stats = baseStats,
        moves = availableMoves
    })
})

-- ❌ FORBIDDEN: Don't send simple data as JSON in Data field
ao.send({
    Target = msg.From,
    Action = "SaveState",
    Data = json.encode({
        speciesId = 123,
        name = "Pikachu",
        found = true
    })
})

-- Tag naming conventions:
-- • Use PascalCase: SpeciesId, PlayerName, BattleId
-- • Provide alternatives: msg.SpeciesId or msg.Id
-- • Convert strings to numbers: tonumber(msg.SpeciesId)
-- • Boolean flags: msg.Confirmed == "true"
-- • All values as strings: tostring(number), "true"/"false" for booleans
-- • Empty optional values: use "" instead of nil
