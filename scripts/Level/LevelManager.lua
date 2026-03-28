-- ============================================================================
-- LevelManager - 关卡生命周期管理器
-- 功能: 状态机管理 idle → briefing → playing → settlement → idle
-- 协调: LevelConfig, LevelTimer, LevelMessageScheduler, BriefingScreen, SettlementScreen
-- ============================================================================

local LevelConfig = require("Level.LevelConfig")
local LevelTimer = require("Level.LevelTimer")
local LevelMessageScheduler = require("Level.LevelMessageScheduler")
local SettlementReport = require("Level.SettlementReport")
local BriefingScreen = require("UI.BriefingScreen")
local SettlementScreen = require("UI.SettlementScreen")
local GameTime = require("Utils.GameTime")

local LevelManager = {}

--- 关卡状态枚举
local STATE = {
    IDLE       = "idle",
    BRIEFING   = "briefing",
    PLAYING    = "playing",
    SETTLEMENT = "settlement",
}

--- 当前状态
---@type string
local state_ = STATE.IDLE

--- 当前关卡数据
---@type table|nil
local levelData_ = nil

--- 外部回调表
---@type table
local callbacks_ = {}

-- ============================================================================
-- 核心 API
-- ============================================================================

--- 初始化 LevelManager
---@param cbs table 回调函数表:
---   onShowBriefing(panel)    — 显示简报画面（将 panel 放入 screenContainer）
---   onStartPlaying()         — 简报结束，恢复手机主界面并开始游戏
---   onShowSettlement(panel)  — 显示结算画面
---   onLevelEnd()             — 关卡彻底结束，回到主菜单/待机
---   onInjectChats(chats)     — 注入关卡聊天到 Data 层
---   onDeliverMessage(msg)    — 投放消息到对应 app/chat
---   onNotification(msg)      — 触发通知横幅
function LevelManager.Init(cbs)
    callbacks_ = cbs or {}
    state_ = STATE.IDLE
    levelData_ = nil
    print("[LevelManager] 初始化完成")
end

--- 启动关卡
---@param levelId string 关卡 ID（如 "level1"）
function LevelManager.StartLevel(levelId)
    if state_ ~= STATE.IDLE then
        print("[LevelManager] 警告: 当前不在 IDLE 状态，无法启动关卡")
        return
    end

    print(string.format("[LevelManager] 启动关卡: %s", levelId))

    -- 1. 加载关卡数据
    levelData_ = LevelConfig.Load(levelId)
    if not levelData_ then
        print("[LevelManager] 关卡数据加载失败!")
        return
    end

    -- 2. 进入简报状态
    state_ = STATE.BRIEFING

    -- 3. 创建简报画面
    local briefingPanel = BriefingScreen.Create(levelData_, function()
        -- 点击"开始" → 进入 playing 状态
        LevelManager.EnterPlaying()
    end)

    -- 4. 通知外部显示简报
    if callbacks_.onShowBriefing then
        callbacks_.onShowBriefing(briefingPanel)
    end

    print("[LevelManager] 进入简报状态")
end

--- 简报结束，进入游戏状态（内部调用）
function LevelManager.EnterPlaying()
    if state_ ~= STATE.BRIEFING then return end

    state_ = STATE.PLAYING
    local config = levelData_.config

    -- 1. 设置虚拟时间
    GameTime.SetTime(config.startHour, config.startMin)
    GameTime.ConsumeDirty()

    -- 2. 注入关卡聊天
    if callbacks_.onInjectChats and levelData_.chats then
        callbacks_.onInjectChats(levelData_.chats)
    end

    -- 3. 初始化消息调度器
    LevelMessageScheduler.Init(levelData_.messages, {
        onMessage = function(msg)
            if callbacks_.onDeliverMessage then
                callbacks_.onDeliverMessage(msg)
            end
        end,
        onNotification = function(msg)
            if callbacks_.onNotification then
                callbacks_.onNotification(msg)
            end
        end,
    })

    -- 4. 启动计时器
    LevelTimer.Start(config.duration)

    -- 5. 通知外部恢复手机界面
    if callbacks_.onStartPlaying then
        callbacks_.onStartPlaying()
    end

    print(string.format("[LevelManager] 进入游戏状态 | 时间 %02d:%02d | 时长 %ds",
        config.startHour, config.startMin, config.duration))
end

--- 每帧更新（仅在 PLAYING 状态有效）
---@param dt number 帧间隔
function LevelManager.Update(dt)
    if state_ ~= STATE.PLAYING then return end

    -- 更新消息调度
    local elapsed = LevelTimer.GetElapsed()
    LevelMessageScheduler.Update(elapsed)

    -- 检查是否到时间
    if LevelTimer.IsExpired() then
        LevelManager.EnterSettlement()
    end
end

--- 进入结算状态（内部调用或外部强制调用）
function LevelManager.EnterSettlement()
    if state_ ~= STATE.PLAYING then return end

    state_ = STATE.SETTLEMENT
    LevelTimer.Stop()

    print("[LevelManager] 进入结算状态")

    -- 生成结算报告
    local reportData = SettlementReport.Generate(levelData_)

    -- 创建结算画面
    local settlementPanel = SettlementScreen.Create(levelData_, reportData, function()
        -- 点击"返回" → 回到 IDLE
        LevelManager.EndLevel()
    end)

    -- 通知外部显示结算
    if callbacks_.onShowSettlement then
        callbacks_.onShowSettlement(settlementPanel)
    end
end

--- 结束关卡，回到 IDLE（内部调用）
function LevelManager.EndLevel()
    state_ = STATE.IDLE
    LevelTimer.Reset()
    LevelMessageScheduler.Reset()
    levelData_ = nil

    if callbacks_.onLevelEnd then
        callbacks_.onLevelEnd()
    end

    print("[LevelManager] 关卡结束，回到 IDLE")
end

-- ============================================================================
-- 查询 API
-- ============================================================================

--- 获取当前状态
---@return string
function LevelManager.GetState()
    return state_
end

--- 是否正在游戏中
---@return boolean
function LevelManager.IsPlaying()
    return state_ == STATE.PLAYING
end

--- 是否在简报或结算画面（UI 覆盖中）
---@return boolean
function LevelManager.IsOverlay()
    return state_ == STATE.BRIEFING or state_ == STATE.SETTLEMENT
end

--- 获取当前关卡数据
---@return table|nil
function LevelManager.GetLevelData()
    return levelData_
end

--- 获取状态枚举
---@return table
function LevelManager.STATE()
    return STATE
end

return LevelManager
