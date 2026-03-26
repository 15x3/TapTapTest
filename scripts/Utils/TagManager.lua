-- ============================================================================
-- 全局标签管理器 (Tag Manager)
-- 功能: 全局标签存储，类似成就系统，由对话事件触发，用于最终结果统计
--
-- 使用方式:
--   local TagManager = require("Utils.TagManager")
--   TagManager.Add("好奇心|勇敢")   -- 批量添加（竖线分隔）
--   TagManager.Has("好奇心")         -- true
--   TagManager.GetAll()               -- { "好奇心", "勇敢" }
--   TagManager.Count()                -- 2
--   TagManager.Clear()                -- 清空
-- ============================================================================

local TM = {}

---@type table<string, boolean>
local tags_ = {}

--- 添加标签（支持竖线分隔批量添加）
---@param tagStr string 标签字符串，多个标签用竖线 "|" 分隔
function TM.Add(tagStr)
    if not tagStr or tagStr == "" then return end
    for tag in tagStr:gmatch("[^|]+") do
        local trimmed = tag:match("^%s*(.-)%s*$")
        if trimmed and trimmed ~= "" then
            tags_[trimmed] = true
        end
    end
end

--- 查询是否拥有某个标签
---@param tag string
---@return boolean
function TM.Has(tag)
    return tags_[tag] == true
end

--- 获取所有标签（返回数组）
---@return string[]
function TM.GetAll()
    local result = {}
    for tag, _ in pairs(tags_) do
        result[#result + 1] = tag
    end
    table.sort(result)
    return result
end

--- 获取标签总数
---@return number
function TM.Count()
    local count = 0
    for _ in pairs(tags_) do
        count = count + 1
    end
    return count
end

--- 清空所有标签
function TM.Clear()
    tags_ = {}
end

return TM
