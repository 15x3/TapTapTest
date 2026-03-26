-- ============================================================================
-- EventScheduler - 全局定时事件调度器
-- 功能: 在指定虚拟时间自动触发指定聊天的对话事件
--
-- 用法:
--   local EventScheduler = require("Utils.EventScheduler")
--
--   -- 注册定时事件（通常由 Data 层解析 CSV trigger_time 后自动调用）
--   EventScheduler.Register({
--     hour = 14, min = 30,
--     app = "dingtalk",
--     chatName = "张老师",
--     eventId = "notice_1",  -- 可选，从指定事件 ID 开始播放
--     once = true,           -- 默认 true，只触发一次
--     require_tag = "",      -- 可选，前置标签条件
--   })
--
--   -- 在 HandleUpdate 中每帧检查
--   local triggered = EventScheduler.CheckTriggers()
--   for _, event in ipairs(triggered) do
--       -- 处理触发...
--   end
-- ============================================================================

local GameTime = require("Utils.GameTime")
local TagManager = require("Utils.TagManager")

local Scheduler = {}

--- @class ScheduledEvent
--- @field hour number 小时 (0-23)
--- @field min number 分钟 (0-59)
--- @field app string "dingtalk" | "wechat"
--- @field chatName string 聊天名称（对应 CSV 的 chat_match）
--- @field eventId string|nil 可选，指定从哪个事件 ID 开始
--- @field once boolean 是否只触发一次（默认 true）
--- @field require_tag string|nil 可选，前置标签条件
--- @field _fired boolean 内部标记：是否已触发过（用于 once=true）

--- @type ScheduledEvent[]
local registered_ = {}

--- 上次检查时的虚拟日期标识（用于跨日重置）
--- @type string
local lastDateKey_ = ""

--- 当日已触发事件的唯一键集合（防止同一分钟内重复触发）
--- @type table<string, boolean>
local firedToday_ = {}

-- ============================================================================
-- 注册 API
-- ============================================================================

--- 注册一个定时事件
--- @param config table 配置表，必须包含 hour, min, app, chatName
function Scheduler.Register(config)
    if not config.hour or not config.min or not config.app or not config.chatName then
        print("[EventScheduler] 注册失败：缺少必要字段 (hour/min/app/chatName)")
        return
    end

    registered_[#registered_ + 1] = {
        hour        = config.hour,
        min         = config.min,
        app         = config.app,
        chatName    = config.chatName,
        eventId     = config.eventId or nil,
        once        = (config.once == nil) and true or config.once,
        require_tag = config.require_tag or "",
        _fired      = false,
    }

    print(string.format("[EventScheduler] 已注册: %02d:%02d → %s/%s%s",
        config.hour, config.min, config.app, config.chatName,
        config.eventId and (" (from " .. config.eventId .. ")") or ""))
end

--- 清除所有已注册的定时事件
function Scheduler.Clear()
    registered_ = {}
    firedToday_ = {}
    lastDateKey_ = ""
end

--- 获取已注册事件数量
--- @return number
function Scheduler.Count()
    return #registered_
end

-- ============================================================================
-- 检查触发
-- ============================================================================

--- 生成事件的唯一键（用于去重）
--- @param ev ScheduledEvent
--- @return string
local function makeKey(ev)
    return string.format("%s|%s|%s|%02d:%02d",
        ev.app, ev.chatName, ev.eventId or "", ev.hour, ev.min)
end

--- 检查 require_tag 条件是否满足
--- @param requireTag string 标签条件字符串，竖线分隔表示 OR
--- @return boolean
local function checkRequireTag(requireTag)
    if not requireTag or requireTag == "" then
        return true  -- 无条件限制
    end
    for tag in requireTag:gmatch("[^|]+") do
        local trimmed = tag:match("^%s*(.-)%s*$")
        if trimmed and trimmed ~= "" and TagManager.Has(trimmed) then
            return true  -- OR 逻辑：任一满足即可
        end
    end
    return false
end

--- 每帧调用：检查当前虚拟时间是否有应触发的事件
--- 返回本次需要触发的事件数组（可能为空）
--- @return ScheduledEvent[]
function Scheduler.CheckTriggers()
    if #registered_ == 0 then
        return {}
    end

    local now = GameTime.Now()
    local currentMinutes = now.hour * 60 + now.min
    local dateKey = string.format("%04d-%02d-%02d", now.year, now.month, now.day)

    -- 检测日期变更，重置当日触发记录
    if dateKey ~= lastDateKey_ then
        lastDateKey_ = dateKey
        firedToday_ = {}
    end

    local triggered = {}

    for _, ev in ipairs(registered_) do
        local eventMinutes = ev.hour * 60 + ev.min

        -- 时间未到，跳过
        if currentMinutes < eventMinutes then
            goto continue
        end

        -- once=true 且已永久触发过，跳过
        if ev.once and ev._fired then
            goto continue
        end

        -- 今日已触发过，跳过（防止同一分钟重复触发）
        local key = makeKey(ev)
        if firedToday_[key] then
            goto continue
        end

        -- require_tag 条件检查
        if not checkRequireTag(ev.require_tag) then
            goto continue
        end

        -- 满足所有条件，标记并收集
        ev._fired = true
        firedToday_[key] = true
        triggered[#triggered + 1] = ev

        print(string.format("[EventScheduler] 触发: %02d:%02d → %s/%s",
            ev.hour, ev.min, ev.app, ev.chatName))

        ::continue::
    end

    return triggered
end

return Scheduler
