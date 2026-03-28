-- ============================================================================
-- FeedbackManager - 反馈触发与延迟投递管理器
-- 功能:
--   1. 正确操作后延迟发送正面反馈消息（on_correct）
--   2. 超时未操作时发送催促消息（on_timeout）
--   3. 错误目标操作时发送提示消息（on_wrong_target）
--
-- 规则来自 feedbacks.csv，trigger 格式: "on_correct:forward:聊天名"
-- ============================================================================

local Log = require("Utils.Logger")

local FeedbackManager = {}

local TAG = "[FeedbackManager]"

--- 规则索引：triggerKey → rule[]
---@type table<string, table[]>
local ruleIndex_ = {}

--- 超时监视列表
--- { sourceChat, watchType ("forward"|"reply"), deliveredAt, timeoutDelay, canceled, triggerKey }
---@type table[]
local timeoutWatches_ = {}

--- 延迟投递队列
--- { deliverAt, app, chat, sender, content, triggerKey }
---@type table[]
local deliveryQueue_ = {}

--- 已投递反馈日志（供结算参考）
---@type table[]
local feedbackLog_ = {}

--- 外部回调
---@type table
local callbacks_ = {}

---@type boolean
local inited_ = false

-- ============================================================================
-- 核心 API
-- ============================================================================

--- 初始化
---@param feedbackRules table[] 反馈规则（来自 LevelConfig.LoadFeedbacks）
---@param cbs table 回调: onDeliverFeedback(app, chat, sender, content)
function FeedbackManager.Init(feedbackRules, cbs)
    ruleIndex_ = {}
    timeoutWatches_ = {}
    deliveryQueue_ = {}
    feedbackLog_ = {}
    callbacks_ = cbs or {}
    inited_ = true

    -- 按 trigger 键索引规则
    for _, rule in ipairs(feedbackRules) do
        local key = rule.trigger
        if not ruleIndex_[key] then
            ruleIndex_[key] = {}
        end
        local list = ruleIndex_[key]
        list[#list + 1] = rule
    end

    Log.info(TAG, string.format("初始化完成 | 规则: %d 条", #feedbackRules))
end

--- 消息投放时调用：注册超时监视
--- 对有 forwardTarget 的消息注册转发超时；对 wait_reply 消息注册回复超时
---@param msg table 消息数据
---@param elapsedSec number 投放时的关卡已流逝秒数
function FeedbackManager.OnMessageDelivered(msg, elapsedSec)
    if not inited_ then return end

    -- 转发超时监视
    if msg.forwardTarget and msg.forwardTarget ~= "" then
        local timeoutKey = "on_timeout:forward:" .. msg.chat
        local rules = ruleIndex_[timeoutKey]
        if rules then
            for _, rule in ipairs(rules) do
                timeoutWatches_[#timeoutWatches_ + 1] = {
                    sourceChat   = msg.chat,
                    chainId      = msg.chainId or "",
                    watchType    = "forward",
                    deliveredAt  = elapsedSec,
                    timeoutDelay = rule.delay,
                    canceled     = false,
                    triggerKey   = timeoutKey,
                }
            end
            Log.info(TAG, string.format("注册转发超时监视: %s (chain:%s) | %ds后触发",
                msg.chat, msg.chainId or "?", rules[1].delay))
        end
    end

    -- 回复超时监视
    if msg.type == "wait_reply" then
        local timeoutKey = "on_timeout:reply:" .. msg.chat
        local rules = ruleIndex_[timeoutKey]
        if rules then
            for _, rule in ipairs(rules) do
                timeoutWatches_[#timeoutWatches_ + 1] = {
                    sourceChat   = msg.chat,
                    watchType    = "reply",
                    deliveredAt  = elapsedSec,
                    timeoutDelay = rule.delay,
                    canceled     = false,
                    triggerKey   = timeoutKey,
                }
            end
            Log.info(TAG, string.format("注册回复超时监视: %s | %ds后触发",
                msg.chat, rules[1].delay))
        end
    end
end

--- 正确转发时调用
---@param sourceChat string 原始消息来源聊天名
---@param chainId string|nil 信息链 ID（用于精确取消超时监视）
---@param elapsedSec number 当前关卡已流逝秒数
function FeedbackManager.OnCorrectForward(sourceChat, chainId, elapsedSec)
    if not inited_ then return end

    -- 取消该信息链的转发超时监视（按 chainId 精确取消，避免误取消同聊天其他链）
    for _, w in ipairs(timeoutWatches_) do
        if w.watchType == "forward" and not w.canceled then
            if chainId and chainId ~= "" and w.chainId ~= "" then
                if w.chainId == chainId then
                    w.canceled = true
                end
            else
                -- chainId 不可用时回退到 sourceChat 级别
                if w.sourceChat == sourceChat then
                    w.canceled = true
                end
            end
        end
    end

    -- 排队正面反馈（带延迟）
    FeedbackManager._queueAction("on_correct:forward:" .. sourceChat, elapsedSec)
end

--- 转发到错误目标时调用
---@param sourceChat string 原始消息来源聊天名
---@param chainId string|nil 信息链 ID
---@param elapsedSec number 当前关卡已流逝秒数
function FeedbackManager.OnWrongTargetForward(sourceChat, chainId, elapsedSec)
    if not inited_ then return end
    FeedbackManager._queueAction("on_wrong_target:forward:" .. sourceChat, elapsedSec)
end

--- 正确发布公告时调用
---@param elapsedSec number 当前关卡已流逝秒数
function FeedbackManager.OnCorrectAnnouncement(elapsedSec)
    if not inited_ then return end
    FeedbackManager._queueAction("on_correct:announce", elapsedSec)
end

--- 正确回复时调用
---@param chatName string 回复的聊天名
---@param elapsedSec number 当前关卡已流逝秒数
function FeedbackManager.OnCorrectReply(chatName, elapsedSec)
    if not inited_ then return end

    -- 取消该聊天的回复超时监视
    for _, w in ipairs(timeoutWatches_) do
        if w.sourceChat == chatName and w.watchType == "reply" and not w.canceled then
            w.canceled = true
        end
    end

    -- 排队正面反馈（带延迟）
    FeedbackManager._queueAction("on_correct:reply:" .. chatName, elapsedSec)
end

--- 每帧更新：检查超时 + 投递到期的反馈
---@param elapsedSec number 当前关卡已流逝秒数
function FeedbackManager.Update(elapsedSec)
    if not inited_ then return end

    -- 检查超时监视
    for _, w in ipairs(timeoutWatches_) do
        if not w.canceled and (elapsedSec - w.deliveredAt) >= w.timeoutDelay then
            w.canceled = true
            FeedbackManager._deliverImmediate(w.triggerKey, elapsedSec)
        end
    end

    -- 处理延迟投递队列
    local i = 1
    while i <= #deliveryQueue_ do
        local item = deliveryQueue_[i]
        if elapsedSec >= item.deliverAt then
            FeedbackManager._deliver(item, elapsedSec)
            table.remove(deliveryQueue_, i)
        else
            i = i + 1
        end
    end
end

-- ============================================================================
-- 内部方法
-- ============================================================================

--- 按 triggerKey 排队反馈（on_correct 系列使用）
---@param triggerKey string
---@param elapsedSec number
function FeedbackManager._queueAction(triggerKey, elapsedSec)
    local rules = ruleIndex_[triggerKey]
    if not rules then return end

    for _, rule in ipairs(rules) do
        deliveryQueue_[#deliveryQueue_ + 1] = {
            deliverAt  = elapsedSec + rule.delay,
            app        = rule.app,
            chat       = rule.chat,
            sender     = rule.sender,
            content    = rule.content,
            triggerKey  = triggerKey,
        }
        Log.info(TAG, string.format("排队反馈: %s | %ds后 → %s/%s",
            triggerKey, rule.delay, rule.app, rule.chat))
    end
end

--- 立即投递反馈（超时系列使用）
---@param triggerKey string
---@param elapsedSec number
function FeedbackManager._deliverImmediate(triggerKey, elapsedSec)
    local rules = ruleIndex_[triggerKey]
    if not rules then return end

    for _, rule in ipairs(rules) do
        FeedbackManager._deliver({
            app        = rule.app,
            chat       = rule.chat,
            sender     = rule.sender,
            content    = rule.content,
            triggerKey  = triggerKey,
        }, elapsedSec)
    end
end

--- 投递单条反馈消息
---@param item table { app, chat, sender, content, triggerKey }
---@param elapsedSec number
function FeedbackManager._deliver(item, elapsedSec)
    if callbacks_.onDeliverFeedback then
        callbacks_.onDeliverFeedback(item.app, item.chat, item.sender, item.content)
    end

    feedbackLog_[#feedbackLog_ + 1] = {
        triggerKey   = item.triggerKey,
        app          = item.app,
        chat         = item.chat,
        sender       = item.sender,
        content      = item.content,
        deliveredAt  = elapsedSec,
    }

    Log.info(TAG, string.format("投递反馈: %s → %s/%s: %s",
        item.triggerKey, item.app, item.chat, string.sub(item.content, 1, 30)))
end

-- ============================================================================
-- 查询 API
-- ============================================================================

--- 获取已投递反馈日志
---@return table[]
function FeedbackManager.GetLog()
    return feedbackLog_
end

--- 重置
function FeedbackManager.Reset()
    ruleIndex_ = {}
    timeoutWatches_ = {}
    deliveryQueue_ = {}
    feedbackLog_ = {}
    callbacks_ = {}
    inited_ = false
end

return FeedbackManager
