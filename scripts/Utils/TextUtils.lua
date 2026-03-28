-- ============================================================================
-- 文本工具模块 (Text Utilities)
-- UTF-8 安全的文本截断等辅助函数
-- ============================================================================

local M = {}

--- UTF-8 字符串长度（按字符计数，非字节）
---@param s string|nil
---@return number
function M.utf8Len(s)
    if not s or s == "" then return 0 end
    local len = 0
    for _ in s:gmatch("[%z\1-\127\194-\253][\128-\191]*") do
        len = len + 1
    end
    return len
end

--- UTF-8 子串（取前 n 个字符）
---@param s string|nil
---@param n number
---@return string
function M.utf8Sub(s, n)
    if not s or s == "" or n <= 0 then return "" end
    local count = 0
    local pos = 1
    while pos <= #s and count < n do
        local byte = s:byte(pos)
        if byte < 128 then pos = pos + 1
        elseif byte < 224 then pos = pos + 2
        elseif byte < 240 then pos = pos + 3
        else pos = pos + 4
        end
        count = count + 1
    end
    return s:sub(1, pos - 1)
end

--- 截断文本，超过 maxLen 个字符时添加 "..."
---@param s string|nil 原始文本
---@param maxLen number 最大字符数
---@return string
function M.truncate(s, maxLen)
    if not s or s == "" then return s or "" end
    if M.utf8Len(s) <= maxLen then return s end
    return M.utf8Sub(s, maxLen) .. "..."
end

return M
