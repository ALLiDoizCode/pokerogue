-- Data Loader Utility for External Data References
-- Handles Arweave transaction references for large datasets

local DataLoader = {}

-- Mock external data references (would be actual Arweave transaction IDs in production)
local EXTERNAL_DATA_REFS = {
    EXTENDED_SPECIES_DATA = "tx_abc123_extended_species_data",
    COMPLETE_MOVE_LIST = "tx_def456_complete_move_list", 
    FULL_ITEM_DATABASE = "tx_ghi789_full_item_database",
    EXTENDED_ABILITIES = "tx_jkl012_extended_abilities"
}

-- Cache for loaded external data
local externalDataCache = {}

-- Mock function to simulate Arweave data loading
local function loadFromArweave(transactionId)
    -- In production, this would fetch from Arweave
    -- For testing, return mock data
    return {
        success = true,
        data = { message = "Mock external data for " .. transactionId },
        timestamp = os.time()
    }
end

-- Load external data with caching
function DataLoader.loadExternalData(referenceKey, forceReload)
    local transactionId = EXTERNAL_DATA_REFS[referenceKey]
    if not transactionId then
        return nil, "Unknown external data reference: " .. referenceKey
    end
    
    -- Check cache first (unless forced reload)
    if not forceReload and externalDataCache[referenceKey] then
        local cached = externalDataCache[referenceKey]
        local age = os.time() - cached.timestamp
        if age < 3600 then -- Cache for 1 hour
            return cached.data, nil
        end
    end
    
    -- Load from Arweave
    local result = loadFromArweave(transactionId)
    if result.success then
        externalDataCache[referenceKey] = {
            data = result.data,
            timestamp = result.timestamp
        }
        return result.data, nil
    else
        return nil, "Failed to load external data"
    end
end

-- Create fallback data for when external data is unavailable
function DataLoader.getFallbackData(referenceKey)
    local fallbackData = {
        EXTENDED_SPECIES_DATA = { message = "Basic species data available locally" },
        COMPLETE_MOVE_LIST = { message = "Core moves available locally" },
        FULL_ITEM_DATABASE = { message = "Essential items available locally" },
        EXTENDED_ABILITIES = { message = "Basic abilities available locally" }
    }
    
    return fallbackData[referenceKey] or { message = "No fallback available" }
end

-- Lazy loading pattern for oversized data segments
function DataLoader.lazyLoad(referenceKey, callback)
    -- Load data in background/on-demand
    local data, error = DataLoader.loadExternalData(referenceKey)
    if data then
        if callback then callback(data) end
        return data
    else
        -- Use fallback
        local fallback = DataLoader.getFallbackData(referenceKey)
        if callback then callback(fallback) end
        return fallback
    end
end

return DataLoader