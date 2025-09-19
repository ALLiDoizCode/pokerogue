-- ============================================================================
-- Pokemon Species Database Process - ADP v1.0 Compliant
-- AO Process Implementation for PokéRogue with Self-Documentation Protocol
-- ============================================================================

-- Global declarations for AO environment compatibility
local json = json or { 
    encode = function(t) return "encoded_json" end, 
    decode = function(s) return {} end 
}
local ao = ao or { 
    send = function(msg) return true end,
    id = "pokemon-species-db-adp"
}

-- ============================================================================
-- ADP v1.0 COMPLIANT PROCESS METADATA
-- ============================================================================

local PROCESS_METADATA = {
    name = "Pokemon Species Database",
    version = "1.1.0-adp",
    adpVersion = "1.0",
    description = "ADP v1.0 compliant Pokemon species database with embedded data for fast querying",
    capabilities = {
        "GetSpecies",
        "GetEvolutionChain", 
        "GetBaseStats",
        "HealthCheck",
        "Info"
    },
    messageSchemas = {
        GetSpecies = {
            required = {"Action", "Data", "Timestamp"},
            dataSchema = {
                anyOf = {
                    {properties = {id = {type = "number"}}},
                    {properties = {name = {type = "string"}}}
                }
            },
            response = {
                properties = {
                    id = {type = "number"},
                    name = {type = "string"},
                    baseStats = {type = "array"},
                    types = {type = "array"},
                    abilities = {type = "array"},
                    evolutionChain = {type = "object"}
                }
            }
        },
        GetEvolutionChain = {
            required = {"Action", "Data", "Timestamp"},
            dataSchema = {
                properties = {
                    id = {type = "number", required = true}
                }
            },
            response = {
                properties = {
                    chain = {type = "array", description = "Evolution chain from base to final form"}
                }
            }
        },
        GetBaseStats = {
            required = {"Action", "Data", "Timestamp"},
            dataSchema = {
                properties = {
                    id = {type = "number", required = true}
                }
            },
            response = {
                properties = {
                    hp = {type = "number"},
                    attack = {type = "number"},
                    defense = {type = "number"},
                    specialAttack = {type = "number"},
                    specialDefense = {type = "number"},
                    speed = {type = "number"}
                }
            }
        },
        HealthCheck = {
            required = {"Action", "Timestamp"},
            response = {
                properties = {
                    status = {type = "string"},
                    speciesCount = {type = "number"},
                    version = {type = "string"}
                }
            }
        },
        Info = {
            required = {"Action", "Timestamp"},
            response = {
                properties = {
                    process = {type = "object"},
                    handlers = {type = "array"},
                    documentation = {type = "object"}
                }
            }
        }
    },
    performance = {
        targetResponseTime = "sub-100ms",
        rateLimit = "100 queries per minute",
        memoryEfficient = true
    }
}

-- ============================================================================
-- RATE LIMITING AND PERFORMANCE MONITORING
-- ============================================================================

local RATE_LIMIT_MAX = 100 -- queries per minute per address
local rateLimitCounters = {}
local performanceStartTime = nil

-- Input validation framework
local function validateInput(message)
    if type(message) ~= "table" then
        return false, "Message must be a table"
    end
    
    if not message.Action or type(message.Action) ~= "string" then
        return false, "Action field is required and must be a string"
    end
    
    if message.Action ~= "HealthCheck" and message.Action ~= "Info" then
        if not message.Data or type(message.Data) ~= "table" then
            return false, "Data field is required and must be a table for " .. message.Action
        end
    end
    
    if not message.Timestamp or type(message.Timestamp) ~= "number" then
        return false, "Timestamp field is required and must be a number"
    end
    
    return true, nil
end

-- Rate limiting implementation
local function checkRateLimit(address)
    local currentTime = os.time()
    local currentMinute = math.floor(currentTime / 60)
    
    if not rateLimitCounters[address] then
        rateLimitCounters[address] = {
            minute = currentMinute,
            count = 0
        }
    end
    
    local counter = rateLimitCounters[address]
    
    -- Reset counter if we're in a new minute
    if counter.minute ~= currentMinute then
        counter.minute = currentMinute
        counter.count = 0
    end
    
    -- Check if rate limit exceeded
    if counter.count >= RATE_LIMIT_MAX then
        return false, "Rate limit exceeded: maximum " .. RATE_LIMIT_MAX .. " queries per minute"
    end
    
    -- Increment counter
    counter.count = counter.count + 1
    return true, nil
end

-- Performance monitoring hooks
local function startPerformanceMonitoring()
    performanceStartTime = os.clock()
end

local function endPerformanceMonitoring()
    if performanceStartTime then
        local responseTime = (os.clock() - performanceStartTime) * 1000 -- Convert to milliseconds
        performanceStartTime = nil
        return responseTime
    end
    return nil
end

-- ============================================================================
-- POKEMON DATA CONSTANTS AND DATABASE
-- ============================================================================

local SPECIES = {
    BULBASAUR = 1, IVYSAUR = 2, VENUSAUR = 3,
    CHARMANDER = 4, CHARMELEON = 5, CHARIZARD = 6,
    SQUIRTLE = 7, WARTORTLE = 8, BLASTOISE = 9,
    CATERPIE = 10, METAPOD = 11, BUTTERFREE = 12,
    WEEDLE = 13, KAKUNA = 14, BEEDRILL = 15,
    PIDGEY = 16, PIDGEOTTO = 17, PIDGEOT = 18,
    RATTATA = 19, RATICATE = 20, SPEAROW = 21,
    FEAROW = 22, EKANS = 23, ARBOK = 24,
    PIKACHU = 25, RAICHU = 26, SANDSHREW = 27,
    SANDSLASH = 28, NIDORAN_F = 29, NIDORINA = 30,
    NIDOQUEEN = 31, NIDORAN_M = 32, NIDORINO = 33,
    NIDOKING = 34, CLEFAIRY = 35, CLEFABLE = 36,
    VULPIX = 37, NINETALES = 38, JIGGLYPUFF = 39,
    WIGGLYTUFF = 40, ZUBAT = 41, GOLBAT = 42,
    ODDISH = 43, GLOOM = 44, VILEPLUME = 45,
    PARAS = 46, PARASECT = 47, VENONAT = 48,
    VENOMOTH = 49, DIGLETT = 50, DUGTRIO = 51,
    MEOWTH = 52, PERSIAN = 53, PSYDUCK = 54,
    GOLDUCK = 55, MANKEY = 56, PRIMEAPE = 57,
    GROWLITHE = 58, ARCANINE = 59, POLIWAG = 60,
    POLIWHIRL = 61, POLIWRATH = 62, ABRA = 63,
    KADABRA = 64, ALAKAZAM = 65, MACHOP = 66,
    MACHOKE = 67, MACHAMP = 68, BELLSPROUT = 69,
    WEEPINBELL = 70, VICTREEBEL = 71, TENTACOOL = 72,
    TENTACRUEL = 73, GEODUDE = 74, GRAVELER = 75,
    GOLEM = 76, PONYTA = 77, RAPIDASH = 78,
    SLOWPOKE = 79, SLOWBRO = 80, MAGNEMITE = 81,
    MAGNETON = 82, FARFETCHD = 83, DODUO = 84,
    DODRIO = 85, SEEL = 86, DEWGONG = 87,
    GRIMER = 88, MUK = 89, SHELLDER = 90,
    CLOYSTER = 91, GASTLY = 92, HAUNTER = 93,
    GENGAR = 94, ONIX = 95, DROWZEE = 96,
    HYPNO = 97, KRABBY = 98, KINGLER = 99,
    VOLTORB = 100, ELECTRODE = 101, EXEGGCUTE = 102,
    EXEGGUTOR = 103, CUBONE = 104, MAROWAK = 105,
    HITMONLEE = 106, HITMONCHAN = 107, LICKITUNG = 108,
    KOFFING = 109, WEEZING = 110, RHYHORN = 111,
    RHYDON = 112, CHANSEY = 113, TANGELA = 114,
    KANGASKHAN = 115, HORSEA = 116, SEADRA = 117,
    GOLDEEN = 118, SEAKING = 119, STARYU = 120,
    STARMIE = 121, MR_MIME = 122, SCYTHER = 123,
    JYNX = 124, ELECTABUZZ = 125, MAGMAR = 126,
    PINSIR = 127, TAUROS = 128, MAGIKARP = 129,
    GYARADOS = 130, LAPRAS = 131, DITTO = 132,
    EEVEE = 133, VAPOREON = 134, JOLTEON = 135,
    FLAREON = 136, PORYGON = 137, OMANYTE = 138,
    OMASTAR = 139, KABUTO = 140, KABUTOPS = 141,
    AERODACTYL = 142, SNORLAX = 143, ARTICUNO = 144,
    ZAPDOS = 145, MOLTRES = 146, DRATINI = 147,
    DRAGONAIR = 148, DRAGONITE = 149, MEWTWO = 150,
    MEW = 151
}

local POKEMON_TYPE = {
    NORMAL = 0, FIGHTING = 1, FLYING = 2, POISON = 3,
    GROUND = 4, ROCK = 5, BUG = 6, GHOST = 7,
    STEEL = 8, FIRE = 9, WATER = 10, GRASS = 11,
    ELECTRIC = 12, PSYCHIC = 13, ICE = 14, DRAGON = 15,
    DARK = 16, FAIRY = 17
}

local ABILITY = {
    NONE = 0, OVERGROW = 65, BLAZE = 66, TORRENT = 67,
    SWARM = 68, CHLOROPHYLL = 34, SOLAR_POWER = 94,
    RAIN_DISH = 44, STATIC = 9, LIGHTNING_ROD = 31,
    PRESSURE = 46, UNNERVE = 186
}

-- Embedded Species Database (Optimized for size and lookup speed)
local SpeciesDatabase = {
    [SPECIES.BULBASAUR] = {
        id = 1, n = "Bulbasaur", 
        bs = {45, 49, 49, 65, 65, 45}, -- baseStats: HP, ATK, DEF, SPATK, SPDEF, SPD
        t = {POKEMON_TYPE.GRASS, POKEMON_TYPE.POISON}, -- types
        ab = {ABILITY.OVERGROW, ABILITY.CHLOROPHYLL}, -- abilities: normal, hidden
        h = 7, w = 69, -- height (decimeters), weight (hectograms)
        ec = {to = SPECIES.IVYSAUR, lv = 16}, -- evolutionChain
        lm = { -- levelMoves
            [1] = {1, 45}, -- Tackle, Growl (move IDs)
            [3] = {73}, -- Leech Seed
            [6] = {22}, -- Vine Whip
            [9] = {77}, -- Poison Powder
            [12] = {79}, -- Sleep Powder
            [15] = {75}, -- Razor Leaf
            [18] = {230}, -- Sweet Scent
            [21] = {74}, -- Growth
            [24] = {235}, -- Synthesis
            [27] = {202}, -- Giga Drain
        }
    },
    [SPECIES.IVYSAUR] = {
        id = 2, n = "Ivysaur",
        bs = {60, 62, 63, 80, 80, 60},
        t = {POKEMON_TYPE.GRASS, POKEMON_TYPE.POISON},
        ab = {ABILITY.OVERGROW, ABILITY.CHLOROPHYLL},
        h = 10, w = 130,
        ec = {fr = SPECIES.BULBASAUR, to = SPECIES.VENUSAUR, lv = 32},
        lm = {
            [1] = {1, 45, 73, 22}, -- Inherited from Bulbasaur
            [18] = {230}, -- Sweet Scent
            [21] = {74}, -- Growth
            [24] = {235}, -- Synthesis
            [28] = {202}, -- Giga Drain
        }
    },
    [SPECIES.VENUSAUR] = {
        id = 3, n = "Venusaur",
        bs = {80, 82, 83, 100, 100, 80},
        t = {POKEMON_TYPE.GRASS, POKEMON_TYPE.POISON},
        ab = {ABILITY.OVERGROW, ABILITY.CHLOROPHYLL},
        h = 20, w = 1000,
        ec = {fr = SPECIES.IVYSAUR},
        lm = {
            [1] = {1, 45, 73, 22}, -- Inherited moves
            [32] = {76}, -- Petal Dance (evolution move)
        }
    },
    [SPECIES.CHARMANDER] = {
        id = 4, n = "Charmander",
        bs = {39, 52, 43, 60, 50, 65},
        t = {POKEMON_TYPE.FIRE},
        ab = {ABILITY.BLAZE, ABILITY.SOLAR_POWER},
        h = 6, w = 85,
        ec = {to = SPECIES.CHARMELEON, lv = 16},
        lm = {
            [1] = {10, 45}, -- Scratch, Growl
            [7] = {52}, -- Ember
            [10] = {108}, -- Smokescreen
            [16] = {99}, -- Rage
            [19] = {163}, -- Scary Face
            [25] = {83}, -- Fire Fang
            [28] = {184}, -- Slash
            [34] = {53}, -- Flamethrower
            [37] = {109}, -- Fire Spin
        }
    },
    [SPECIES.CHARMELEON] = {
        id = 5, n = "Charmeleon",
        bs = {58, 64, 58, 80, 65, 80},
        t = {POKEMON_TYPE.FIRE},
        ab = {ABILITY.BLAZE, ABILITY.SOLAR_POWER},
        h = 11, w = 190,
        ec = {fr = SPECIES.CHARMANDER, to = SPECIES.CHARIZARD, lv = 36},
        lm = {
            [1] = {10, 45, 52}, -- Inherited moves
            [17] = {163}, -- Scary Face
            [20] = {83}, -- Fire Fang
            [27] = {184}, -- Slash
            [35] = {53}, -- Flamethrower
        }
    },
    [SPECIES.CHARIZARD] = {
        id = 6, n = "Charizard",
        bs = {78, 84, 78, 109, 85, 100},
        t = {POKEMON_TYPE.FIRE, POKEMON_TYPE.FLYING},
        ab = {ABILITY.BLAZE, ABILITY.SOLAR_POWER},
        h = 17, w = 905,
        ec = {fr = SPECIES.CHARMELEON},
        lm = {
            [1] = {10, 45, 52, 17}, -- Inherited + Wing Attack
            [36] = {53}, -- Flamethrower (evolution move)
            [41] = {200}, -- Heat Wave
            [47] = {63}, -- Hyper Beam
        }
    },
    [SPECIES.SQUIRTLE] = {
        id = 7, n = "Squirtle",
        bs = {44, 48, 65, 50, 64, 43},
        t = {POKEMON_TYPE.WATER},
        ab = {ABILITY.TORRENT, ABILITY.RAIN_DISH},
        h = 5, w = 90,
        ec = {to = SPECIES.WARTORTLE, lv = 16},
        lm = {
            [1] = {1, 39}, -- Tackle, Tail Whip
            [4] = {55}, -- Water Gun
            [7] = {110}, -- Withdraw
            [10] = {145}, -- Bubble
            [13] = {5}, -- Bite
            [16] = {229}, -- Rapid Spin
            [19] = {109}, -- Protect
            [22] = {56}, -- Hydro Pump
        }
    },
    [SPECIES.WARTORTLE] = {
        id = 8, n = "Wartortle",
        bs = {59, 63, 80, 65, 80, 58},
        t = {POKEMON_TYPE.WATER},
        ab = {ABILITY.TORRENT, ABILITY.RAIN_DISH},
        h = 10, w = 225,
        ec = {fr = SPECIES.SQUIRTLE, to = SPECIES.BLASTOISE, lv = 36},
        lm = {
            [1] = {1, 39, 55}, -- Inherited moves
            [20] = {109}, -- Protect
            [24] = {56}, -- Hydro Pump
            [28] = {182}, -- Iron Defense
        }
    },
    [SPECIES.BLASTOISE] = {
        id = 9, n = "Blastoise",
        bs = {79, 83, 100, 85, 105, 78},
        t = {POKEMON_TYPE.WATER},
        ab = {ABILITY.TORRENT, ABILITY.RAIN_DISH},
        h = 16, w = 855,
        ec = {fr = SPECIES.WARTORTLE},
        lm = {
            [1] = {1, 39, 55, 56}, -- Inherited + Hydro Pump
            [36] = {56}, -- Hydro Pump (evolution move)
            [42] = {199}, -- Hydro Cannon
        }
    },
    [SPECIES.PIKACHU] = {
        id = 25, n = "Pikachu",
        bs = {35, 55, 40, 50, 50, 90},
        t = {POKEMON_TYPE.ELECTRIC},
        ab = {ABILITY.STATIC, ABILITY.LIGHTNING_ROD},
        h = 4, w = 60,
        ec = {to = SPECIES.RAICHU, it = "thunder_stone"}, -- item evolution
        lm = {
            [1] = {84, 45}, -- Thunder Shock, Growl
            [5] = {39}, -- Tail Whip
            [10] = {86}, -- Thunder Wave
            [13] = {98}, -- Quick Attack
            [18] = {129}, -- Swift
            [26] = {97}, -- Agility
            [33] = {87}, -- Thunder
            [42] = {113}, -- Light Screen
        }
    },
    [SPECIES.RAICHU] = {
        id = 26, n = "Raichu",
        bs = {60, 90, 55, 90, 80, 110},
        t = {POKEMON_TYPE.ELECTRIC},
        ab = {ABILITY.STATIC, ABILITY.LIGHTNING_ROD},
        h = 8, w = 300,
        ec = {fr = SPECIES.PIKACHU},
        lm = {
            [1] = {84, 45, 98, 86, 87}, -- Key inherited moves
        }
    },
    [SPECIES.MEWTWO] = {
        id = 150, n = "Mewtwo",
        bs = {106, 110, 90, 154, 90, 130},
        t = {POKEMON_TYPE.PSYCHIC},
        ab = {ABILITY.PRESSURE, ABILITY.UNNERVE},
        h = 20, w = 1220,
        ec = {}, -- No evolution
        lm = {
            [1] = {93, 50}, -- Confusion, Disable
            [8] = {104}, -- Barrier
            [15] = {129}, -- Swift
            [22] = {60}, -- Psybeam
            [29] = {94}, -- Psychic
            [36] = {109}, -- Recover
            [43] = {118}, -- Psycho Cut
            [50] = {105}, -- Amnesia
            [57] = {115}, -- Reflect
            [64] = {63}, -- Hyper Beam
            [71] = {144}, -- Psystrike
        }
    }
}

-- Create optimized indexes for fast lookup
local nameIndex = {}
for speciesId, data in pairs(SpeciesDatabase) do
    nameIndex[data.n:lower()] = data
end

-- ============================================================================
-- QUERY HANDLERS
-- ============================================================================

local function getSpeciesById(speciesId)
    return SpeciesDatabase[speciesId]
end

local function getSpeciesByName(name)
    return nameIndex[name:lower()]
end

local function getEvolutionChain(speciesId)
    local species = SpeciesDatabase[speciesId]
    if not species then
        return nil
    end
    
    local chain = {}
    
    -- Find base species (go backward)
    local current = species
    while current and current.ec and current.ec.fr do
        current = SpeciesDatabase[current.ec.fr]
        if current then
            table.insert(chain, 1, current)
        end
    end
    
    -- Add current species
    table.insert(chain, species)
    
    -- Find evolved forms (go forward)
    current = species
    while current and current.ec and current.ec.to do
        current = SpeciesDatabase[current.ec.to]
        if current then
            table.insert(chain, current)
        end
    end
    
    return chain
end

local function getBaseStats(speciesId)
    local species = SpeciesDatabase[speciesId]
    if not species then
        return nil
    end
    
    return {
        hp = species.bs[1],
        attack = species.bs[2],
        defense = species.bs[3],
        specialAttack = species.bs[4],
        specialDefense = species.bs[5],
        speed = species.bs[6]
    }
end

-- ============================================================================
-- AO MESSAGE HANDLERS - ADP v1.0 COMPLIANT
-- ============================================================================

-- ADP v1.0 Required: Info handler for self-documentation
Handlers.add("info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        -- Start performance monitoring
        startPerformanceMonitoring()
        
        -- Validate input
        local success, result = pcall(validateInput, msg)
        if not success or not result then
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Error = result or "Invalid input for Info",
                ProcessId = ao.id,
                Timestamp = tostring(os.time())
            })
            return
        end
        
        -- Count loaded species
        local speciesCount = 0
        for _ in pairs(SpeciesDatabase) do
            speciesCount = speciesCount + 1
        end
        
        local responseTime = endPerformanceMonitoring()
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = {
                process = PROCESS_METADATA,
                handlers = {
                    "GetSpecies", "GetEvolutionChain", "GetBaseStats", 
                    "HealthCheck", "Info"
                },
                documentation = {
                    adpCompliance = "v1.0",
                    selfDocumenting = true,
                    speciesCount = speciesCount,
                    performanceTarget = "sub-100ms",
                    lastResponseTime = responseTime and (responseTime .. "ms") or "unknown"
                }
            },
            ProcessId = ao.id,
            Timestamp = tostring(os.time())
        })
    end
)

-- Pokemon species query handler
Handlers.add("pokemon-species-query", 
    Handlers.utils.hasMatchingTag("Action", {"GetSpecies", "GetEvolutionChain", "GetBaseStats"}),
    function(msg)
        -- Start performance monitoring
        startPerformanceMonitoring()
        
        -- Input validation
        local success, validationError = pcall(validateInput, msg)
        if not success or not validationError then
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Error = validationError or "Input validation failed",
                ProcessId = ao.id,
                Timestamp = tostring(os.time())
            })
            return
        end
        
        -- Rate limiting check
        local senderAddress = msg.From or "unknown"
        local rateLimitOk, rateLimitError = checkRateLimit(senderAddress)
        if not rateLimitOk then
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Error = rateLimitError,
                ProcessId = ao.id,
                Timestamp = tostring(os.time())
            })
            return
        end
        
        -- Process the query
        local querySuccess, result = pcall(function()
            local action = msg.Action
            local data = msg.Data
            
            if action == "GetSpecies" then
                if data.id then
                    return getSpeciesById(data.id)
                elseif data.name then
                    return getSpeciesByName(data.name)
                else
                    error("GetSpecies requires either 'id' or 'name' in Data")
                end
            elseif action == "GetEvolutionChain" then
                if not data.id then
                    error("GetEvolutionChain requires 'id' in Data")
                end
                return getEvolutionChain(data.id)
            elseif action == "GetBaseStats" then
                if not data.id then
                    error("GetBaseStats requires 'id' in Data")
                end
                return getBaseStats(data.id)
            else
                error("Unknown action: " .. action)
            end
        end)
        
        -- Check performance requirement
        local responseTime = endPerformanceMonitoring()
        if responseTime and responseTime > 100 then
            -- Log performance warning but don't fail the request
            print("Warning: Query response time " .. responseTime .. "ms exceeds 100ms target")
        end
        
        if querySuccess and result then
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Data = result,
                ProcessId = ao.id,
                Timestamp = tostring(os.time()),
                ResponseTime = responseTime and (responseTime .. "ms") or "unknown"
            })
        else
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Error = "Query processing failed: " .. tostring(result),
                ProcessId = ao.id,
                Timestamp = tostring(os.time())
            })
        end
    end
)

-- Health check handler
Handlers.add("health-check",
    Handlers.utils.hasMatchingTag("Action", "HealthCheck"),
    function(msg)
        -- Start performance monitoring
        startPerformanceMonitoring()
        
        -- Validate input
        local success, result = pcall(validateInput, msg)
        if not success or not result then
            ao.send({
                Target = msg.From,
                Action = "SaveState",
                Error = result or "Invalid input for HealthCheck",
                ProcessId = ao.id,
                Timestamp = tostring(os.time())
            })
            return
        end
        
        -- Count loaded species
        local speciesCount = 0
        for _ in pairs(SpeciesDatabase) do
            speciesCount = speciesCount + 1
        end
        
        local responseTime = endPerformanceMonitoring()
        
        ao.send({
            Target = msg.From,
            Action = "SaveState",
            Data = {
                status = "healthy",
                processId = ao.id,
                speciesCount = speciesCount,
                version = PROCESS_METADATA.version,
                adpCompliant = true,
                responseTime = responseTime and (responseTime .. "ms") or "unknown"
            },
            ProcessId = ao.id,
            Timestamp = tostring(os.time())
        })
    end
)

-- ============================================================================
-- PROCESS INITIALIZATION
-- ============================================================================

-- Log initialization
local speciesCount = 0
for _ in pairs(SpeciesDatabase) do
    speciesCount = speciesCount + 1
end

print("Pokemon Species Database Process (ADP v1.0) initialized:")
print("- Process ID: " .. ao.id)
print("- Version: " .. PROCESS_METADATA.version)
print("- Species loaded: " .. speciesCount)
print("- ADP Compliance: " .. PROCESS_METADATA.adpVersion)
print("- Self-documenting: enabled")
print("- Rate limiting: " .. RATE_LIMIT_MAX .. " queries/minute")
print("- Performance target: sub-100ms")

return {
    metadata = PROCESS_METADATA,
    handlers = {"GetSpecies", "GetEvolutionChain", "GetBaseStats", "HealthCheck", "Info"},
    speciesCount = speciesCount
}