-- ============================================================================
-- LevelMessageScheduler - 关卡消息时间轴调度器
-- 功能: 按 time_offset 投放消息到对应 app/chat
-- 替代 EventScheduler 在关卡模式下的角色
-- ============================================================================

local Log = require("Utils.Logger")

local Scheduler = {}

local TAG = "[LevelMsgScheduler]"

--- 消息列表（已按 timeOffset 排序）
---@type table[]
local messages_ = {}

--- 下一个待投放消息的索引
---@type number
local nextIndex_ = 1

--- 回调函数表
---@type table
local callbacks_ = {}

--- 是否已初始化
---@type boolean
local inited_ = false

-- ============================================================================
-- 核心 API
-- ============================================================================

--- 初始化调度器
---@param messages table[] 从 LevelConfig 加载的消息列表（已排序）
---@param cbs table 回调: { onMessage(msg), onNotification(msg) }
function Scheduler.Init(messages, cbs)
    messages_ = messages or {}
    nextIndex_ = 1
    callbacks_ = cbs or {}
    inited_ = true
    Log.info(TAG, string.format("初始化完成，共 %d 条消息", #messages_))
end

--- 每帧更新：检查并投放到时消息
---@param elapsedSec number 关卡已流逝秒数
function Scheduler.Update(elapsedSec)
    if not inited_ then return end

    while nextIndex_ <= #messages_ do
        local msg = messages_[nextIndex_]
        if msg.timeOffset <= elapsedSec then
            -- 投放消息
            Log.info(TAG, string.format("投放消息 [%d/%d] @%.0fs: %s/%s - %s: %s",
                nextIndex_, #messages_, msg.timeOffset,
                msg.app, msg.chat, msg.sender,
                string.sub(msg.content, 1, 30)))

            if callbacks_.onMessage then
                callbacks_.onMessage(msg)
            end

            -- 触发通知（非系统消息才通知）
            if msg.type ~= "system" and callbacks_.onNotification then
                callbacks_.onNotification(msg)
            end

            nextIndex_ = nextIndex_ + 1
        else
            break  -- 后续消息时间还未到
        end
    end
end

--- 是否所有消息都已投放
---@return boolean
function Scheduler.IsAllDelivered()
    return nextIndex_ > #messages_
end

--- 获取进度信息
---@return number delivered 已投放数量
---@return number total 总数量
function Scheduler.GetProgress()
    return math.min(nextIndex_ - 1, #messages_), #messages_
end

--- 获取所有消息（供结算统计使用）
---@return table[]
function Scheduler.GetAllMessages()
    return messages_
end

--- 获取已投放的消息列表
---@return table[]
function Scheduler.GetDeliveredMessages()
    local delivered = {}
    for i = 1, math.min(nextIndex_ - 1, #messages_) do
        delivered[#delivered + 1] = messages_[i]
    end
    return delivered
end

--- 重置调度器
function Scheduler.Reset()
    messages_ = {}
    nextIndex_ = 1
    callbacks_ = {}
    inited_ = false
end

return Scheduler
