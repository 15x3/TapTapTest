-- ============================================================================
-- CSV 解析器公共模块 (CSV Parser Utility)
-- 功能: 统一的 CSV 文件读取与解析，供所有 Data 模块复用
-- ============================================================================

local Log = require("Utils.Logger")

local CSVParser = {}

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

    local ok, headersOrErr, rows = pcall(CSVParser.Parse, content)
    if not ok then
        Log.error(tag, "CSV 解析失败:", tostring(headersOrErr))
        return {}, {}
    end
    return headersOrErr, rows
end

return CSVParser
