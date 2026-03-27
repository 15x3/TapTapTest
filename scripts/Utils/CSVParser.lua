-- ============================================================================
-- CSV 解析器公共模块 (CSV Parser Utility)
-- 功能: 统一的 CSV 文件读取与解析，供所有 Data 模块复用
-- ============================================================================

local Log = require("Utils.Logger")

local CSVParser = {}

-- ============================================================================
-- 文件变更检测（基于文件系统修改时间）
-- ============================================================================

--- 缓存：资源路径 → 绝对文件系统路径的映射
---@type table<string, string>
local absPathCache_ = {}

--- 记录每个 CSV 文件上次加载时的修改时间
---@type table<string, integer>
local lastModTimes_ = {}

--- 将资源路径转为绝对文件系统路径（带缓存）
---@param resPath string 资源路径（如 "data/chats.csv"）
---@return string|nil absPath 绝对路径，找不到返回 nil
local function resolveAbsPath(resPath)
    if absPathCache_[resPath] then
        return absPathCache_[resPath]
    end
    -- 通过 ResourceCache 解析为绝对路径
    local absPath = cache:GetResourceFileName(resPath)
    if absPath and absPath ~= "" then
        absPathCache_[resPath] = absPath
        return absPath
    end
    return nil
end

--- 检查指定 CSV 文件是否自上次记录后发生变化
--- 使用 fileSystem:GetLastModifiedTime 直接读取磁盘上的文件修改时间，
--- 完全绕过 ResourceCache 的内容缓存
---@param path string 资源路径
---@return boolean changed 是否有变化（首次检查视为无变化）
function CSVParser.HasChanged(path)
    local absPath = resolveAbsPath(path)
    if not absPath then return false end

    local modTime = fileSystem:GetLastModifiedTime(absPath)
    if modTime == 0 then return false end  -- 文件不存在或无法访问

    local prev = lastModTimes_[path]
    if prev == nil then
        -- 首次记录，不算变化
        lastModTimes_[path] = modTime
        return false
    end

    if modTime ~= prev then
        lastModTimes_[path] = modTime  -- 更新记录
        Log.info("[HotReload]", "文件已变更:", path, "modTime:", prev, "→", modTime)
        return true
    end
    return false
end

--- 批量检查多个 CSV 文件是否有变化
---@param paths string[] 资源路径数组
---@return boolean anyChanged 是否有任何一个文件发生变化
function CSVParser.AnyChanged(paths)
    local changed = false
    for _, path in ipairs(paths) do
        if CSVParser.HasChanged(path) then
            changed = true
            -- 不 break，确保所有文件的修改时间都被更新
        end
    end
    return changed
end

--- 记录指定路径当前的修改时间（在加载后调用）
---@param path string 资源路径
function CSVParser.RecordModTime(path)
    local absPath = resolveAbsPath(path)
    if not absPath then return end
    local modTime = fileSystem:GetLastModifiedTime(absPath)
    if modTime ~= 0 then
        lastModTimes_[path] = modTime
    end
end

--- 清除所有变更检测记录（用于强制重载场景）
function CSVParser.ResetTracking()
    lastModTimes_ = {}
    absPathCache_ = {}
end

--- 从资源目录读取文件内容
---@param path string 资源路径（相对于 scripts/）
---@param tag string|nil 日志标签（如 "[DingtalkData]"）
---@return string|nil
function CSVParser.ReadFile(path, tag)
    tag = tag or "[CSVParser]"
    if not cache:Exists(path) then
        Log.warn(tag, "文件不存在:", path)
        return nil
    end
    local file = cache:GetFile(path)
    if not file then
        Log.error(tag, "无法打开文件:", path)
        return nil
    end
    local content = file:ReadString()
    file:Close()
    return content
end

--- 解析 CSV 内容为行数组（表头 + 数据行）
--- 支持简单 CSV（不含引号包裹字段）
---@param content string CSV 文本内容
---@return string[] headers 表头字段名数组
---@return table[] rows 数据行数组，每行为 { [字段名] = 值 } 的表
function CSVParser.Parse(content)
    if not content or content == "" then return {}, {} end

    local lines = {}
    -- 按行分割（兼容 \r\n 和 \n）
    for line in content:gmatch("[^\r\n]+") do
        -- 跳过空行和注释行
        local trimmed = line:match("^%s*(.-)%s*$")
        if trimmed ~= "" and trimmed:sub(1, 1) ~= "#" then
            lines[#lines + 1] = trimmed
        end
    end

    if #lines < 1 then return {}, {} end

    -- 解析表头
    local headers = {}
    for field in lines[1]:gmatch("([^,]*)") do
        headers[#headers + 1] = field:match("^%s*(.-)%s*$")  -- trim
    end

    -- 解析数据行
    local rows = {}
    for i = 2, #lines do
        local row = {}
        local colIdx = 1
        for field in lines[i]:gmatch("([^,]*)") do
            local key = headers[colIdx]
            if key then
                row[key] = field:match("^%s*(.-)%s*$")  -- trim
            end
            colIdx = colIdx + 1
        end
        rows[#rows + 1] = row
    end

    return headers, rows
end

--- 加载并解析 CSV 文件（ReadFile + Parse 的便捷组合）
--- 内置 pcall 保护，解析失败时返回空结果而非抛出异常
---@param path string 资源路径
---@param tag string|nil 日志标签
---@return string[] headers
---@return table[] rows
function CSVParser.Load(path, tag)
    tag = tag or "[CSVParser]"
    local content = CSVParser.ReadFile(path, tag)
    if not content then return {}, {} end

    -- 记录本次加载时的修改时间（供后续变更检测使用）
    CSVParser.RecordModTime(path)

    local ok, headersOrErr, rows = pcall(CSVParser.Parse, content)
    if not ok then
        Log.error(tag, "CSV 解析失败:", tostring(headersOrErr))
        return {}, {}
    end
    return headersOrErr, rows
end

return CSVParser
