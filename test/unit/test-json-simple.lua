-- Simple test for JSON mock
local mockJson = {
    encode = function(data)
        print("JSON encode called with data type: " .. type(data))
        return "mock_json_string"
    end
}

_G.json = mockJson

print("Testing JSON reference...")
print("json global exists: " .. tostring(json ~= nil))
print("Calling json.encode...")

local success, result = pcall(function()
    return json.encode({test = "data"})
end)

print("Success: " .. tostring(success))
print("Result: " .. tostring(result))