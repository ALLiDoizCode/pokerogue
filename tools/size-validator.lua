-- Size Validation Tool for AO Processes
-- Enforces <500KB constraint per process

local SIZE_LIMIT_BYTES = 500 * 1024 -- 500KB in bytes

local function validateProcessSize(filePath)
  local file = io.open(filePath, "r")
  if not file then
    return false, "File not found: " .. filePath
  end
  
  file:seek("end")
  local size = file:seek()
  file:close()
  
  if size > SIZE_LIMIT_BYTES then
    return false, string.format("Process %s exceeds 500KB limit: %d bytes (%.1fKB)", 
                                filePath, size, size/1024)
  end
  
  return true, string.format("Process %s is within size limit: %d bytes (%.1fKB)",
                            filePath, size, size/1024)
end

local function scanProcessFiles(processDir)
  local files = {}
  local dir = processDir or "processes"
  
  -- Use shell command to find Lua files
  local handle = io.popen("find " .. dir .. " -name '*.lua' 2>/dev/null")
  if handle then
    for line in handle:lines() do
      table.insert(files, line)
    end
    handle:close()
  end
  
  return files
end

local function formatBytes(bytes)
  if bytes < 1024 then
    return string.format("%d B", bytes)
  elseif bytes < 1024 * 1024 then
    return string.format("%.2f KB", bytes / 1024)
  else
    return string.format("%.2f MB", bytes / (1024 * 1024))
  end
end

local function validateAllProcesses(processDir)
  local results = {}
  local totalViolations = 0
  local files = scanProcessFiles(processDir)
  
  print("🔍 AO Process Size Validation")
  print("=" .. string.rep("=", 60))
  print("Maximum allowed size: " .. formatBytes(SIZE_LIMIT_BYTES))
  print("")
  
  if #files == 0 then
    print("⚠️  No Lua files found in " .. (processDir or "processes") .. " directory")
    return {
      totalProcesses = 0,
      violations = 0,
      results = results,
      passed = true
    }
  end
  
  print("📁 Process Files Analysis:")
  print(string.format("%-40s %12s %8s %8s", "File", "Size", "% of Max", "Status"))
  print(string.rep("-", 72))
  
  for _, filepath in ipairs(files) do
    local isValid, message = validateProcessSize(filepath)
    local filename = filepath:gsub(".*/", "") -- Get just filename
    
    local file = io.open(filepath, "r")
    local size = 0
    if file then
      file:seek("end")
      size = file:seek()
      file:close()
    end
    
    local percentage = (size / SIZE_LIMIT_BYTES) * 100
    local status = isValid and "✅ VALID" or "❌ TOO LARGE"
    
    print(string.format("%-40s %12s %7.1f%% %s", 
      filename, 
      formatBytes(size), 
      percentage, 
      status
    ))
    
    table.insert(results, {
      filepath = filepath,
      valid = isValid,
      size = size,
      message = message
    })
    
    if not isValid then
      totalViolations = totalViolations + 1
    end
  end
  
  print(string.rep("-", 72))
  print(string.format("📊 Summary: %d total, %d valid, %d invalid", 
    #files, #files - totalViolations, totalViolations))
  
  if totalViolations > 0 then
    print("\n❌ VALIDATION FAILED: " .. totalViolations .. " file(s) exceed size limit")
    print("\n💡 Optimization suggestions:")
    print("  • Move large data to external Arweave transactions")
    print("  • Minify Lua code and remove comments")
    print("  • Use data references instead of embedding")
    print("  • Split large processes into smaller specialized ones")
  else
    print("\n✅ All process files are within size constraints!")
  end
  
  return {
    totalProcesses = #files,
    violations = totalViolations,
    results = results,
    passed = totalViolations == 0
  }
end

-- Run validation if called directly
if arg and arg[0] and arg[0]:match("size%-validator%.lua$") then
  local success = validateAllProcesses("processes")
  os.exit(success.passed and 0 or 1)
end

-- Export functions for use in build pipeline
return {
  validateProcessSize = validateProcessSize,
  validateAllProcesses = validateAllProcesses,
  scanProcessFiles = scanProcessFiles,
  formatBytes = formatBytes,
  SIZE_LIMIT_BYTES = SIZE_LIMIT_BYTES
}