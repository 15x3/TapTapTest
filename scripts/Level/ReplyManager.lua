-- ============================================================================
-- ReplyManager - 回复操作管理器
-- 功能: 管理 wait_reply 消息的回复跟踪与关键词匹配
--
-- 流程:
--   1. LevelMessageScheduler 投放 wait_reply 类型消息
--   2. ReplyManager.OnWaitReplyDelivered() 注册待回复项
--   3. 玩家在对应聊天发送消息时，ChatPage 调用 ReplyManager.OnUserReply()
--   4. 关键词匹配 → 记录结果（供结算使用）
--   5. 超时未回复 → 标记为 timeout（由 Update 检查）
-- ============================================================================

local SentimentAnalyzer = require("Utils.SentimentAnalyzer")
local Log = require("Utils.Logger")

local ReplyManager = {}

local TAG = "[ReplyManager]"

--- 待回复项列表
--- { id=number, msg=table, deliveredAt=number, replied=boolean, replyText=string, keywords=string, result=string }
---@type table[]
local pendingReplies_ = {}

--- 已完成的回复记录（供结算使用）
---@type table[]
local replyLog_ = {}

--- 自增 ID
---@type number
local nextId_ = 1

--- 回复超时时间（秒）：超过此时间未回复则标记 timeout
---@type number
local REPLY_TIMEOUT = 180  -- 3 分钟

--- 外部回调
---@type table
local callbacks_ = {}

--- 是否已初始化
---@type boolean
local inited_ = false

-- ============================================================================
-- 核心 API
-- ============================================================================

--- 初始化
---@param cbs table|nil 回调函数:
---   onReplyResult(entry)      — 回复结果（匹配成功/失败）
---   onReplyTimeout(entry)     — 回复超时
---   onPendingReplyAdded(entry)— 新增待回复项（用于 UI 提示）
function ReplyManager.Init(cbs)
    pendingReplies_ = {}
    replyLog_ = {}
    nextId_ = 1
    callbacks_ = cbs or {}
    inited_ = true
    Log.info(TAG, "初始化完成")
end

--- 当 wait_reply 消息被投放时调用：注册待回复项
---@param msg table 消息数据（来自 LevelMessageScheduler）
---@param elapsedSec number 投放时的关卡已流逝秒数
function ReplyManager.OnWaitReplyDelivered(msg, elapsedSec)
    if not inited_ then return end

    local entry = {
        id           = nextId_,
        msg          = msg,
        app          = msg.app,
        chat         = msg.chat,
        sender       = msg.sender,
        content      = msg.content,
        keywords     = msg.keywords or "",
        replyHint    = msg.replyHint or "",
        chainId      = msg.chainId or "",
        chainName    = msg.chainName or "",
        deliveredAt  = elapsedSec,
        replied      = false,
        replyText    = "",
        result       = "pending",  -- pending | matched | unmatched | timeout
        matchedCount = 0,
        totalCount   = 0,
    }
    nextId_ = nextId_ + 1

    pendingReplies_[#pendingReplies_ + 1] = entry

    Log.info(TAG, string.format("注册待回复 #%d: %s/%s - %s (关键词: %s)",
        entry.id, msg.app, msg.chat, string.sub(msg.content, 1, 30), msg.keywords or "无"))

    if callbacks_.onPendingReplyAdded then
        callbacks_.onPendingReplyAdded(entry)
    end
end

--- 玩家在某聊天发送了消息时调用
---@param app string 应用 ID ("dingtalk" | "wechat")
---@param chatName string 聊天名称
---@param text string 玩家回复的文本
---@return table|nil entry 匹配到的待回复项（nil 表示该聊天没有待回复项）
function ReplyManager.OnUserReply(app, chatName, text)
    if not inited_ then return nil end

    -- 查找该聊天中最早的未回复项
    for i, entry in ipairs(pendingReplies_) do
        if not entry.replied and entry.app == app and entry.chat == chatName then
            entry.replied = true
            entry.replyText = text

            -- 关键词匹配检查
            if entry.keywords ~= "" then
                local matched, score = SentimentAnalyzer.MatchKeywords(text, entry.keywords)
                -- 统计总关键词数
                local totalKw = 0
                for _ in entry.keywords:gmatch("[^|]+") do
                    totalKw = totalKw + 1
                end
                entry.matchedCount = score
                entry.totalCount = totalKw
                entry.result = matched and "matched" or "unmatched"
            else
                -- 无关键词要求，回复即通过
                entry.result = "matched"
            end

            -- 记录到日志
            replyLog_[#replyLog_ + 1] = {
                id         = entry.id,
                app        = entry.app,
                chat       = entry.chat,
                content    = entry.content,
                replyText  = text,
                result     = entry.result,
                matchedKw  = entry.matchedCount,
                totalKw    = entry.totalCount,
                chainId    = entry.chainId,
                chainName  = entry.chainName,
            }

            Log.info(TAG, string.format("回复 #%d: %s | 匹配 %d/%d | 结果: %s",
                entry.id, string.sub(text, 1, 30),
                entry.matchedCount, entry.totalCount, entry.result))

            if callbacks_.onReplyResult then
                callbacks_.onReplyResult(entry)
            end

            return entry
        end
    end

    return nil  -- 没有匹配的待回复项
end

--- 每帧更新：检查超时的待回复项
---@param elapsedSec number 关卡已流逝秒数
function ReplyManager.Update(elapsedSec)
    if not inited_ then return end

    for _, entry in ipairs(pendingReplies_) do
        if not entry.replied and entry.result == "pending" then
            if (elapsedSec - entry.deliveredAt) >= REPLY_TIMEOUT then
                entry.result = "timeout"
                entry.replied = true

                replyLog_[#replyLog_ + 1] = {
                    id        = entry.id,
                    app       = entry.app,
                    chat      = entry.chat,
                    content   = entry.content,
                    replyText = "",
                    result    = "timeout",
                    matchedKw = 0,
                    totalKw   = entry.totalCount,
                    chainId   = entry.chainId,
                    chainName = entry.chainName,
                }

                Log.info(TAG, string.format("回复超时 #%d: %s/%s", entry.id, entry.app, entry.chat))

                if callbacks_.onReplyTimeout then
                    callbacks_.onReplyTimeout(entry)
                end
            end
        end
    end
end

-- ============================================================================
-- 查询 API
-- ============================================================================

--- 检查指定聊天是否有待回复项
---@param app string
---@param chatName string
---@return boolean
function ReplyManager.HasPendingReply(app, chatName)
    if not inited_ then return false end
    for _, entry in ipairs(pendingReplies_) do
        if not entry.replied and entry.app == app and entry.chat == chatName then
            return true
        end
    end
    return false
end

--- 获取指定聊天的待回复提示（replyHint / 自动填充文本）
---@param app string
---@param chatName string
---@return string|nil hint 回复提示文本，nil 表示没有待回复
function ReplyManager.GetReplyHint(app, chatName)
    if not inited_ then return nil end
    for _, entry in ipairs(pendingReplies_) do
        if not entry.replied and entry.app == app and entry.chat == chatName then
            return entry.replyHint ~= "" and entry.replyHint or nil
        end
    end
    return nil
end

--- 获取所有待回复项
---@return table[]
function ReplyManager.GetPendingReplies()
    local pending = {}
    for _, entry in ipairs(pendingReplies_) do
        if not entry.replied then
            pending[#pending + 1] = entry
        end
    end
    return pending
end

--- 获取回复日志（供结算使用）
---@return table[]
function ReplyManager.GetLog()
    return replyLog_
end

--- 重置
function ReplyManager.Reset()
    pendingReplies_ = {}
    replyLog_ = {}
    nextId_ = 1
    callbacks_ = {}
    inited_ = false
end

return ReplyManager
