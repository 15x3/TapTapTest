-- ============================================================================
-- ForwardManager - 转发操作管理器
-- 功能: 管理消息转发逻辑（目标验证、消息投递、结果记录）
-- 规则: 以"班主任"身份直接发出原文（非引用格式）
-- ============================================================================

local UI = require("urhox-libs/UI")

local ForwardManager = {}

--- 关卡数据（来自 LevelConfig.Load）
---@type table|nil
local levelData_ = nil

--- 可转发的目标聊天列表 { name=string, app=string }[]
---@type table[]
local targets_ = {}

--- 转发操作记录（供结算使用）
---@type table[]
local forwardLog_ = {}

--- 外部回调
---@type table
local callbacks_ = {}

-- ============================================================================
-- 核心 API
-- ============================================================================

--- 初始化
---@param levelData table 关卡数据
---@param cbs table 回调函数:
---   onForwardSuccess(msg, targetChat) — 转发成功
---   onForwardWrongTarget(msg, targetChat) — 转发到错误目标
---   onDeliverMessage(app, chatName, sender, text) — 实际投递消息到 Data 层
---   onShowTargetSelector(targets, onSelect) — 显示目标选择 UI
function ForwardManager.Init(levelData, cbs)
    levelData_ = levelData
    callbacks_ = cbs or {}
    forwardLog_ = {}

    -- 提取可转发目标
    targets_ = {}
    if levelData.chats then
        for _, chat in ipairs(levelData.chats) do
            if chat.isTarget then
                targets_[#targets_ + 1] = {
                    name = chat.name,
                    app  = chat.app,
                }
            end
        end
    end

    print(string.format("[ForwardManager] 初始化完成 | 可转发目标: %d 个", #targets_))
end

--- 获取可转发目标列表
---@return table[]
function ForwardManager.GetTargets()
    return targets_
end

--- 开始转发流程（弹出目标选择）
---@param msg table 要转发的消息 { sender, text, chat, app, ... }
function ForwardManager.StartForward(msg)
    if #targets_ == 0 then
        print("[ForwardManager] 没有可转发目标")
        return
    end

    -- 调用外部 UI 显示目标选择
    if callbacks_.onShowTargetSelector then
        callbacks_.onShowTargetSelector(targets_, function(targetChat)
            ForwardManager.ExecuteForward(msg, targetChat)
        end)
    end
end

--- 执行转发
---@param msg table 原始消息
---@param targetChat table { name=string, app=string }
function ForwardManager.ExecuteForward(msg, targetChat)
    -- 检查转发目标是否正确（支持管道分隔的多目标: "群A|群B"）
    local isCorrect = false
    if msg.forwardTarget and msg.forwardTarget ~= "" then
        for validTarget in msg.forwardTarget:gmatch("[^|]+") do
            if targetChat.name == validTarget then
                isCorrect = true
                break
            end
        end
    else
        -- 消息没有指定转发目标，任何转发目标都算"操作"（非错误）
        isCorrect = true
    end

    -- 记录转发操作
    local logEntry = {
        timestamp  = os.time(),
        msgContent = msg.content or msg.text or "",
        msgChat    = msg.chat or "",
        msgApp     = msg.app or "",
        targetChat = targetChat.name,
        targetApp  = targetChat.app,
        isCorrect  = isCorrect,
        chainId    = msg.chainId or "",
        chainName  = msg.chainName or "",
    }
    forwardLog_[#forwardLog_ + 1] = logEntry

    -- 投递消息到目标聊天（以"班主任"身份发送，带 [转发] 前缀）
    if callbacks_.onDeliverMessage then
        local forwardText = "[转发] " .. (msg.content or msg.text or "")
        callbacks_.onDeliverMessage(targetChat.app, targetChat.name, "班主任", forwardText)
    end

    -- 触发结果回调
    if isCorrect then
        print(string.format("[ForwardManager] 转发成功: %s → %s/%s",
            string.sub(msg.content or "", 1, 20), targetChat.app, targetChat.name))
        if callbacks_.onForwardSuccess then
            callbacks_.onForwardSuccess(msg, targetChat)
        end
    else
        print(string.format("[ForwardManager] 转发到错误目标: %s → %s/%s (正确目标: %s)",
            string.sub(msg.content or "", 1, 20), targetChat.app, targetChat.name, msg.forwardTarget or ""))
        if callbacks_.onForwardWrongTarget then
            callbacks_.onForwardWrongTarget(msg, targetChat)
        end
    end
end

--- 获取转发操作日志
---@return table[]
function ForwardManager.GetLog()
    return forwardLog_
end

--- 重置
function ForwardManager.Reset()
    levelData_ = nil
    targets_ = {}
    forwardLog_ = {}
    callbacks_ = {}
end

return ForwardManager
