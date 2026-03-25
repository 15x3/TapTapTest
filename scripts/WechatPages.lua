-- ============================================================================
-- 微信子页面模块 (WeChat Sub-Pages Module)
-- 包含：聊天详情、联系人详情
-- ============================================================================

local UI = require("urhox-libs/UI")
local WechatData = require("WechatData")
local ChatEventManager = require("ChatEventManager")

local M = {}

-- 模块级变量：事件系统状态
local wxActiveManager_ = nil       -- 当前活跃的 ChatEventManager 实例
local wxPendingScroll_ = nil        -- 需要滚动到底部的 ScrollView 引用
local wxTypingIndicator_ = nil      -- "正在输入"指示器 widget 引用
local wxTypingLabel_ = nil          -- 输入指示标签
local wxPagesUpdateSubscribed_ = false  -- 是否已订阅 Update 事件

--- 确保 WechatPages 模块的 Update 事件已订阅（只订阅一次）
local function ensureWxPagesUpdate()
    if wxPagesUpdateSubscribed_ then return end
    wxPagesUpdateSubscribed_ = true
    SubscribeToEvent("Update", "HandleWechatPagesUpdate")
end

--- Update 事件处理：驱动事件管理器 + 延迟滚动
function HandleWechatPagesUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()

    -- 驱动活跃的事件管理器
    if wxActiveManager_ then
        wxActiveManager_:Update(dt)
    end

    -- 处理延迟滚动
    if wxPendingScroll_ then
        local sv = wxPendingScroll_
        wxPendingScroll_ = nil
        sv:ScrollToBottom()
    end
end

-- 微信色彩体系
local WX = {
    green      = { 7, 193, 96, 255 },
    darkGreen  = { 54, 132, 86, 255 },
    headerBg   = { 237, 237, 237, 255 },
    bg         = { 237, 237, 237, 255 },
    white      = { 255, 255, 255, 255 },
    text       = { 25, 25, 25, 255 },
    textSec    = { 153, 153, 153, 255 },
    border     = { 225, 225, 225, 255 },
    chatBg     = { 240, 240, 240, 255 },
    selfBubble = { 149, 215, 105, 255 },
}

-- ============================================================================
-- 通用顶栏
-- ============================================================================

local function CreateHeader(title, onBack, rightChildren)
    local children = {
        UI.Button {
            width = 30, height = 30,
            backgroundColor = { 0, 0, 0, 0 },
            hoverBackgroundColor = { 0, 0, 0, 10 },
            pressedBackgroundColor = { 0, 0, 0, 20 },
            borderRadius = 4,
            text = "<",
            textColor = WX.text,
            fontSize = 14,
            onClick = function(self) onBack() end,
        },
        UI.Label {
            text = title,
            fontSize = 14,
            fontColor = WX.text,
            flexGrow = 1,
            flexBasis = 0,
            textAlign = "center",
            maxLines = 1,
        },
    }
    if rightChildren then
        children[#children + 1] = rightChildren
    else
        children[#children + 1] = UI.Panel { width = 30, height = 30 }
    end

    return UI.Panel {
        width = "100%",
        height = 44,
        backgroundColor = WX.headerBg,
        flexDirection = "row",
        alignItems = "center",
        paddingHorizontal = 8,
        borderBottomWidth = 1,
        borderBottomColor = { 210, 210, 210, 255 },
        children = children,
    }
end

-- ============================================================================
-- 聊天详情页面
-- ============================================================================

function M.CreateChatPage(chatName, chatIconBg, onBack)
    -- 确保 Update 订阅已注册
    ensureWxPagesUpdate()

    -- 停止之前的管理器
    wxActiveManager_ = nil
    wxTypingIndicator_ = nil
    wxTypingLabel_ = nil

    -- 消息列表容器（用于动态追加气泡）
    local msgListPanel = UI.Panel {
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
        children = { msgListPanel },
    }

    -- "正在输入"指示器
    local typingLabel = UI.Label {
        text = "",
        fontSize = 10,
        fontColor = WX.textSec,
    }
    wxTypingLabel_ = typingLabel

    local typingPanel = UI.Panel {
        width = "100%",
        height = 0,   -- 默认隐藏
        paddingHorizontal = 14,
        justifyContent = "center",
        overflow = "hidden",
        children = { typingLabel },
    }
    wxTypingIndicator_ = typingPanel

    --- 添加一条消息气泡到列表
    local function addBubble(msg)
        msgListPanel:AddChild(M._createChatBubble(msg, chatIconBg))
        wxPendingScroll_ = scrollView
    end

    -- 加载场景事件并创建管理器
    local scenarioEvents = WechatData.GetChatScenario(chatName)

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
            if wxTypingIndicator_ then
                wxTypingLabel_:SetText(sender .. " 正在输入...")
                wxTypingIndicator_:SetHeight(20)
            end
        end,

        onTypingEnd = function()
            if wxTypingIndicator_ then
                wxTypingLabel_:SetText("")
                wxTypingIndicator_:SetHeight(0)
            end
        end,

        onDone = function()
            -- 所有事件播放完毕
        end,
    })

    wxActiveManager_ = manager
    wxPendingScroll_ = scrollView

    -- 输入状态
    local inputValue = ""

    -- 发送消息
    local function sendMessage(text)
        if not text or text == "" then return end
        local trimmed = text:match("^%s*(.-)%s*$")
        if trimmed == "" then return end

        -- 获取当前时间
        local t = os.date("*t")
        local timeStr = string.format("%02d:%02d", t.hour, t.min)

        -- 更新数据层
        WechatData.UpdateChatPreview(chatName, trimmed)

        -- 创建"我"发的消息气泡
        local newMsg = { sender = "我", text = trimmed, time = timeStr, showTime = true }
        addBubble(newMsg)

        -- 通知事件管理器：用户发了消息
        if wxActiveManager_ and wxActiveManager_:IsWaitingInput() then
            wxActiveManager_:OnUserMessage(trimmed)
        end
    end

    -- 发送按钮（初始隐藏，输入时显示）
    local sendBtn = UI.Button {
        width = 44, height = 28,
        backgroundColor = WX.green,
        hoverBackgroundColor = { 6, 170, 85, 255 },
        pressedBackgroundColor = { 5, 150, 75, 255 },
        borderRadius = 4,
        text = "发送",
        textColor = WX.white,
        fontSize = 11,
        visible = false,
        onClick = function(self)
            if inputValue == "" then return end
            sendMessage(inputValue)
            inputValue = ""
            if M._activeTextField then
                M._activeTextField:SetValue("")
            end
            self:SetVisible(false)
        end,
    }

    -- + 号按钮（输入为空时显示）
    local plusBtn = UI.Panel {
        width = 28, height = 28,
        justifyContent = "center",
        alignItems = "center",
        children = {
            UI.Label { text = "+", fontSize = 18, fontColor = WX.textSec },
        },
    }

    -- 输入框
    local textField = UI.TextField {
        flexGrow = 1, flexBasis = 0,
        height = 36,
        fontSize = 13,
        placeholder = "输入消息...",
        value = "",
        borderRadius = 6,
        backgroundColor = WX.white,
        paddingHorizontal = 10,
        onChange = function(self, value)
            inputValue = value
            local hasText = (value ~= "")
            sendBtn:SetVisible(hasText)
            plusBtn:SetVisible(not hasText)
        end,
        onSubmit = function(self, value)
            if value == "" then return end
            sendMessage(value)
            inputValue = ""
            self:SetValue("")
            sendBtn:SetVisible(false)
            plusBtn:SetVisible(true)
        end,
    }

    -- 缓存当前活跃的输入框引用
    M._activeTextField = textField

    return UI.Panel {
        width = "100%",
        height = "100%",
        backgroundColor = WX.chatBg,
        flexDirection = "column",
        children = {
            CreateHeader(chatName, function()
                -- 离开聊天页面时清理管理器
                wxActiveManager_ = nil
                wxTypingIndicator_ = nil
                wxTypingLabel_ = nil
                onBack()
            end),
            -- 消息列表
            scrollView,
            -- 正在输入指示
            typingPanel,
            -- 底部输入栏
            UI.Panel {
                width = "100%",
                minHeight = 50,
                backgroundColor = { 245, 245, 245, 255 },
                flexDirection = "row",
                alignItems = "center",
                paddingHorizontal = 8,
                paddingVertical = 7,
                gap = 6,
                borderTopWidth = 1,
                borderTopColor = { 210, 210, 210, 255 },
                children = {
                    textField,
                    UI.Panel {
                        width = 28, height = 28,
                        justifyContent = "center",
                        alignItems = "center",
                        children = {
                            UI.Label { text = ":)", fontSize = 14, fontColor = WX.textSec },
                        },
                    },
                    plusBtn,
                    sendBtn,
                },
            },
        },
    }
end

--- 聊天气泡
function M._createChatBubble(msg, chatIconBg)
    local isSelf = msg.sender == "我"
    local bubbleBg = isSelf and WX.selfBubble or WX.white
    local alignRow = isSelf and "flex-end" or "flex-start"

    local avatarBg = isSelf and { 100, 160, 220, 255 } or (chatIconBg or { 80, 120, 200, 255 })
    local avatarText = isSelf and "我" or string.sub(msg.sender, 1, 3)

    local avatar = UI.Panel {
        width = 34, height = 34,
        backgroundColor = avatarBg,
        borderRadius = 4,
        justifyContent = "center",
        alignItems = "center",
        children = {
            UI.Label { text = avatarText, fontSize = 9, fontColor = WX.white, textAlign = "center" },
        },
    }

    local bubble = UI.Panel {
        maxWidth = "68%",
        backgroundColor = bubbleBg,
        borderRadius = 4,
        paddingHorizontal = 10,
        paddingVertical = 8,
        children = {
            UI.Label {
                text = msg.text,
                fontSize = 11,
                fontColor = WX.text,
                whiteSpace = "normal",
            },
        },
    }

    local items = {}

    if msg.showTime then
        items[#items + 1] = UI.Panel {
            width = "100%",
            alignItems = "center",
            marginBottom = 4,
            children = {
                UI.Panel {
                    paddingHorizontal = 8, paddingVertical = 2,
                    backgroundColor = { 200, 200, 200, 80 },
                    borderRadius = 4,
                    children = {
                        UI.Label { text = msg.time or "", fontSize = 9, fontColor = WX.textSec },
                    },
                },
            },
        }
    end

    local rowChildren = isSelf and { bubble, avatar } or { avatar, bubble }

    items[#items + 1] = UI.Panel {
        width = "100%",
        flexDirection = "row",
        justifyContent = alignRow,
        alignItems = "flex-start",
        gap = 6,
        children = rowChildren,
    }

    return UI.Panel {
        width = "100%",
        flexDirection = "column",
        children = items,
    }
end

-- ============================================================================
-- 联系人详情页面（个人名片）
-- ============================================================================

function M.CreateContactDetailPage(contact, onBack, onSendMessage)
    local colorSeed = string.byte(contact.initial, 1) or 65
    local avatarColors = {
        { 80, 130, 220, 255 },
        { 200, 90, 90, 255 },
        { 60, 170, 100, 255 },
        { 180, 120, 60, 255 },
        { 140, 80, 200, 255 },
        { 60, 170, 180, 255 },
    }
    local avatarBg = avatarColors[(colorSeed % #avatarColors) + 1]

    local infoRows = {}
    if contact.remark and contact.remark ~= "" then
        infoRows[#infoRows + 1] = UI.Panel {
            width = "100%",
            paddingVertical = 12,
            paddingHorizontal = 16,
            flexDirection = "row",
            justifyContent = "space-between",
            backgroundColor = WX.white,
            borderBottomWidth = 1,
            borderBottomColor = { 240, 240, 240, 255 },
            children = {
                UI.Label { text = "备注", fontSize = 12, fontColor = WX.textSec },
                UI.Label { text = contact.remark, fontSize = 12, fontColor = WX.text },
            },
        }
    end

    return UI.Panel {
        width = "100%",
        height = "100%",
        backgroundColor = WX.bg,
        flexDirection = "column",
        children = {
            CreateHeader("详细资料", onBack),
            UI.ScrollView {
                width = "100%",
                flexGrow = 1,
                flexBasis = 0,
                children = {
                    UI.Panel {
                        width = "100%",
                        flexDirection = "column",
                        children = {
                            -- 头像和名称区域
                            UI.Panel {
                                width = "100%",
                                backgroundColor = WX.white,
                                paddingVertical = 20,
                                paddingHorizontal = 16,
                                flexDirection = "row",
                                alignItems = "center",
                                gap = 14,
                                children = {
                                    UI.Panel {
                                        width = 56, height = 56,
                                        backgroundColor = avatarBg,
                                        borderRadius = 8,
                                        justifyContent = "center",
                                        alignItems = "center",
                                        children = {
                                            UI.Label { text = contact.initial, fontSize = 22, fontColor = { 255, 255, 255, 255 } },
                                        },
                                    },
                                    UI.Panel {
                                        flexGrow = 1, flexShrink = 1,
                                        flexDirection = "column",
                                        gap = 4,
                                        children = {
                                            UI.Label {
                                                text = contact.name,
                                                fontSize = 16,
                                                fontColor = WX.text,
                                                fontWeight = "bold",
                                            },
                                            UI.Label {
                                                text = "微信号: wx_" .. string.lower(contact.initial) .. string.format("%04d", colorSeed),
                                                fontSize = 11,
                                                fontColor = WX.textSec,
                                            },
                                        },
                                    },
                                },
                            },
                            UI.Panel { width = "100%", height = 8, backgroundColor = WX.bg },
                            -- 信息区
                            UI.Panel {
                                width = "100%",
                                flexDirection = "column",
                                children = infoRows,
                            },
                            UI.Panel { width = "100%", height = 8, backgroundColor = WX.bg },
                            -- 朋友圈入口
                            UI.Panel {
                                width = "100%",
                                backgroundColor = WX.white,
                                paddingVertical = 12,
                                paddingHorizontal = 16,
                                flexDirection = "row",
                                justifyContent = "space-between",
                                alignItems = "center",
                                children = {
                                    UI.Label { text = "朋友圈", fontSize = 13, fontColor = WX.text },
                                    UI.Label { text = ">", fontSize = 13, fontColor = WX.textSec },
                                },
                            },
                            UI.Panel { width = "100%", height = 8, backgroundColor = WX.bg },
                            -- 发消息按钮
                            UI.Panel {
                                width = "100%",
                                paddingVertical = 16,
                                paddingHorizontal = 16,
                                children = {
                                    UI.Button {
                                        width = "100%",
                                        height = 44,
                                        backgroundColor = WX.green,
                                        hoverBackgroundColor = { 6, 170, 85, 255 },
                                        pressedBackgroundColor = { 5, 150, 75, 255 },
                                        borderRadius = 6,
                                        text = "发消息",
                                        textColor = WX.white,
                                        fontSize = 14,
                                        onClick = function(self)
                                            if onSendMessage then
                                                onSendMessage(contact, avatarBg)
                                            else
                                                onBack()
                                            end
                                        end,
                                    },
                                },
                            },
                        },
                    },
                },
            },
        },
    }
end

return M
