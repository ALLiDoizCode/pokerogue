# SendMessage Pattern Fix for Aolite Tests

## Root Cause
The sendMessage utility function signature and Data encoding pattern must match the reference implementation in `pokemon-species-db.test.lua`.

## INCORRECT Pattern (Double JSON Encoding)
```lua
-- WRONG: sendMessage encodes data internally
local function sendMessage(action, data)
    local msg = {
        From = processId,
        Target = processId,
        Action = action,
        Data = json.encode(data or {})  -- ❌ Encoding here
    }
    aolite.send(msg)
    return aolite.getLastMsg(processId)
end

-- Then called with table:
local testData = { pokemon = { speciesId = 25 } }
local response = sendMessage("CalculateFriendship", testData)  -- ❌ Table passed
```

## CORRECT Pattern (Reference: pokemon-species-db.test.lua)
```lua
-- ✅ CORRECT: sendMessage expects pre-encoded string
local function sendMessage(action, tags, data)
    local msg = {
        From = processId,
        Target = processId,
        Action = action,
        Data = data or ""  -- ✅ Expects string
    }

    -- Add additional tags
    if tags then
        for k, v in pairs(tags) do
            msg[k] = tostring(v)
        end
    end

    aolite.send(msg)
    return aolite.getLastMsg(processId)
end

-- Then called with json-encoded string:
local testData = { pokemon = { speciesId = 25 } }
local response = sendMessage("CalculateFriendship", nil, json.encode(testData))  -- ✅ Pre-encoded
```

## Critical Requirements
1. **Spawn Tags**: Must include `{ { name = "On-Boot", value = "Data" } }` (not empty table)
2. **Data Encoding**: Caller json.encodes, sendMessage receives string
3. **Function Signature**: `sendMessage(action, tags, data)` - 3 parameters
4. **Tags Parameter**: nil when no extra tags, table when adding fields

## Batch Fix Command
```bash
# Find all sendMessage calls that need fixing
grep -n 'sendMessage(' testing/unit/friendship-engine.test.lua

# Pattern to fix (29 occurrences):
# FROM: sendMessage("Action", testData)
# TO:   sendMessage("Action", nil, json.encode(testData))

# FROM: sendMessage("Action", {})  
# TO:   sendMessage("Action", nil, "")
```

## Status
- ✅ Pattern identified and documented
- ✅ First 2 test calls fixed as proof-of-concept
- ⏳ Remaining 27 sendMessage calls need batch update
- ⏳ Apply same fix to all 10 remaining test rewrites
