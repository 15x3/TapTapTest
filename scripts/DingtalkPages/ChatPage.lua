-- ============================================================================
-- 钉钉聊天详情页面 (Chat Page)
-- 事件驱动架构：支持自动消息播放、输入等待、随意敲打键盘
-- ============================================================================

local UI = require("urhox-libs/UI")
local DingtalkData = require("DingtalkData")
local ChatEventManager = require("ChatEventManager")
local ChatBubble = require("Utils.ChatBubble")
local Common = require("DingtalkPagesCommon")
local C = Common.C

local M = {}

-- 模块级变量：事件系统状态
local activeManager_ = nil
local pendingScroll_ = nil
local typingIndicator_ = nil
local activeInputField_ = nil
local activeSendFunc_ = nil
local updateSubscribed_ = false

-- "随意敲打键盘"功能：用于检测任意按键
local ANY_KEYS = {
    KEY_A, KEY_B, KEY_C, KEY_D, KEY_E, KEY_F, KEY_G, KEY_H, KEY_I, KEY_J,
    KEY_K, KEY_L, KEY_M, KEY_N, KEY_O, KEY_P, KEY_Q, KEY_R, KEY_S, KEY_T,
    KEY_U, KEY_V, KEY_W, KEY_X, KEY_Y, KEY_Z,
    KEY_0, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9,
    KEY_SPACE, KEY_RETURN, KEY_COMMA, KEY_PERIOD,
}

local function ensureUpdate()
    if updateSubscribed_ then return end
    updateSubscribed_ = true
    SubscribeToEvent("Update", "HandleDingtalkChatPageUpdate")
end

--- Update event handler
function HandleDingtalkChatPageUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    if activeManager_ then
        activeManager_:Update(dt)
        if activeManager_:IsWaitingInput() and activeInputField_ then
            -- 检测用户是否删除了文字（如果输入框文本比上次填充的短）
            local currentText = activeInputField_:GetValue() or ""
            local lastFillLength = activeInputField_.lastFillLength or 0
            if #currentText < lastFillLength then
                -- 用户删除了文字，重置填充进度
                activeManager_:ResetAutoFill()
            end

            -- 检测按键事件
            for _, key in ipairs(ANY_KEYS) do
                if input:GetKeyPress(key) then
                    activeManager_:OnKeyPress()
                    break
                end
            end
        end
    end
    if pendingScroll_ then
        local sv = pendingScroll_
        pendingScroll_ = nil
        sv:ScrollToBottom()
    end
end

--- 创建聊天详情页面
---@param chatName string 聊天对象名称
---@param chatIconBg table 聊天图标背景色
---@param onBack function 返回回调
---@return table UI.Panel
function M.Create(chatName, chatIconBg, onBack)
    -- 确保 Update 订阅已注册
    ensureUpdate()

    -- 停止之前的管理器
    activeManager_ = nil
    typingIndicator_ = nil
    activeInputField_ = nil
    activeSendFunc_ = nil

    -- 消息列表容器（用于动态添加气泡）
    local msgListContainer = UI.Panel {
        width = "100%",
        flexDirection = "column",
        paddingVertical = 10,
        paddingHorizontal = 10,
        gap = 10,
    }

    local scrollView = UI.ScrollView {
        width = "100%",
        flexGrow = 1,
        flexBasis = 0,
        children = { msgListContainer },
    }

    -- "正在输入"指示器
    local typingLabel = UI.Label {
        text = "",
        fontSize = 10,
        fontColor = C.textSec,
    }
    local typingPanel = UI.Panel {
        width = "100%",
        height = 0,   -- 默认隐藏
        paddingHorizontal = 14,
        justifyContent = "center",
        overflow = "hidden",
        children = { typingLabel },
    }
    typingIndicator_ = typingPanel

    -- 输入框引用
    ---@type any
    local inputField = nil

    --- 添加一条消息气泡到列表，并请求延迟滚动
    local function addBubble(msg)
        msgListContainer:AddChild(ChatBubble.Create(msg, chatIconBg, ChatBubble.DINGTALK))
        pendingScroll_ = scrollView
    end

    -- 加载场景事件并创建管理器
    local scenarioEvents = DingtalkData.GetChatScenario(chatName)

    local manager = ChatEventManager.Create(scenarioEvents, {
        onMessage = function(msg)
            -- 如果消息没有时间戳，使用当前时间
            if msg.time == "" then
                local t = os.date("*t")
                msg.time = string.format("%02d:%02d", t.hour, t.min)
                msg.showTime = false
            end
            addBubble(msg)
        end,

        onTyping = function(sender)
            if typingIndicator_ then
                typingLabel:SetText(sender .. " 正在输入...")
                typingIndicator_:SetHeight(20)
            end
        end,

        onTypingEnd = function()
            if typingIndicator_ then
                typingLabel:SetText("")
                typingIndicator_:SetHeight(0)
            end
        end,

        onAutoFill = function(partialText, isComplete)
            -- 更新输入框显示正在填充的文本
            if activeInputField_ then
                activeInputField_:SetValue(partialText)
                -- 保存当前填充长度，用于检测用户是否删除了文字
                activeInputField_.lastFillLength = #partialText
            end
        end,

        onDone = function()
            -- 所有事件播放完毕，不做特殊处理
        end,
    })

    activeManager_ = manager

    -- 初始历史消息加载完后，滚动到底部
    pendingScroll_ = scrollView

    -- 发送消息
    local function sendMessage(text)
        if not text or text == "" then return end
        local trimmed = text:match("^%s*(.-)%s*$")
        if trimmed == "" then return end

        -- 获取当前时间
        local t = os.date("*t")
        local timeStr = string.format("%02d:%02d", t.hour, t.min)

        -- 创建"我"发的消息气泡
        local newMsg = { sender = "我", text = trimmed, time = timeStr, showTime = true }
        addBubble(newMsg)

        -- 清空输入框
        if inputField then
            inputField:Clear()
        end

        -- 通知事件管理器：用户发了消息
        if activeManager_ and activeManager_:IsWaitingInput() then
            activeManager_:OnUserMessage(trimmed)
        end
    end

    -- 创建输入框
    inputField = UI.TextField {
        flexGrow = 1,
        height = 34,
        fontSize = 12,
        placeholder = "输入消息...",
        onSubmit = function(self, value)
            sendMessage(value)
        end,
    }

    -- 存储引用供"随意敲打键盘"功能使用
    activeInputField_ = inputField
    activeSendFunc_ = sendMessage

    return UI.Panel {
        width = "100%",
        height = "100%",
        backgroundColor = { 240, 240, 240, 255 },
        flexDirection = "column",
        children = {
            -- 顶栏
            UI.Panel {
                width = "100%",
                height = 44,
                backgroundColor = C.white,
                flexDirection = "row",
                alignItems = "center",
                paddingHorizontal = 12,
                borderBottomWidth = 1,
                borderBottomColor = C.border,
                children = {
                    UI.Button {
                        width = 30, height = 30,
                        backgroundColor = { 0, 0, 0, 0 },
                        hoverBackgroundColor = { 0, 0, 0, 15 },
                        pressedBackgroundColor = { 0, 0, 0, 30 },
                        borderRadius = 4,
                        text = "<",
                        textColor = C.text,
                        fontSize = 14,
                        onClick = function(self)
                            -- 离开聊天页面时清理管理器
                            activeManager_ = nil
                            typingIndicator_ = nil
                            activeInputField_ = nil
                            activeSendFunc_ = nil
                            onBack()
                        end,
                    },
                    UI.Label {
                        text = chatName,
                        fontSize = 13,
                        fontColor = C.text,
                        flexGrow = 1, flexBasis = 0,
                        flexShrink = 1,
                        maxLines = 1,
                        textAlign = "center",
                    },
                    UI.Panel { width = 30, height = 30 },
                },
            },
            -- 消息列表
            scrollView,
            -- 正在输入指示
            typingPanel,
            -- 输入栏
            UI.Panel {
                width = "100%",
                height = 48,
                backgroundColor = C.white,
                flexDirection = "row",
                alignItems = "center",
                paddingHorizontal = 10,
                gap = 8,
                borderTopWidth = 1,
                borderTopColor = C.border,
                children = {
                    inputField,
                    UI.Button {
                        width = 50, height = 30,
                        backgroundColor = C.blue,
                        hoverBackgroundColor = { 38, 100, 220, 255 },
                        pressedBackgroundColor = { 28, 80, 190, 255 },
                        borderRadius = 4,
                        text = "发送",
                        textColor = C.white,
                        fontSize = 11,
                        onClick = function(self)
                            if inputField then
                                sendMessage(inputField:GetValue())
                            end
                        end,
                    },
                },
            },
        },
    }
end

return M
