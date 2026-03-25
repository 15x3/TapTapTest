-- ============================================================================
-- 日志系统 (Logger Utility)
-- 功能: 统一的分级日志，替代散落的 print 调用
-- 用法:
--   local Log = require("Utils.Logger")
--   Log.info("MyModule", "初始化完成")
--   Log.warn("MyModule", "文件不存在: " .. path)
--   Log.error("MyModule", "加载失败", err)
-- ============================================================================

local Logger = {}

-- 日志级别
Logger.DEBUG = 0
Logger.INFO  = 1
Logger.WARN  = 2
Logger.ERROR = 3

--- 当前最低输出级别（低于此级别的日志不输出）
Logger.level = Logger.DEBUG

local LEVEL_NAMES = {
    [0] = "DEBUG",
    [1] = "INFO",
    [2] = "WARN",
    [3] = "ERROR",
}

--- 格式化并输出日志
---@param level number 日志级别
---@param tag string 模块标签
---@param ... any 日志内容（多个参数会用空格拼接）
local function log(level, tag, ...)
    if level < Logger.level then return end

    local parts = {}
    local args = { ... }
    for i = 1, #args do
        parts[i] = tostring(args[i])
    end
    local message = table.concat(parts, " ")

    local prefix = string.format("[%s][%s]", LEVEL_NAMES[level] or "?", tag)
    print(prefix .. " " .. message)
end

--- 调试日志
---@param tag string 模块标签
---@param ... any 日志内容
function Logger.debug(tag, ...)
    log(Logger.DEBUG, tag, ...)
end

--- 信息日志
---@param tag string 模块标签
---@param ... any 日志内容
function Logger.info(tag, ...)
    log(Logger.INFO, tag, ...)
end

--- 警告日志
---@param tag string 模块标签
---@param ... any 日志内容
function Logger.warn(tag, ...)
    log(Logger.WARN, tag, ...)
end

--- 错误日志
---@param tag string 模块标签
---@param ... any 日志内容
function Logger.error(tag, ...)
    log(Logger.ERROR, tag, ...)
end

return Logger
