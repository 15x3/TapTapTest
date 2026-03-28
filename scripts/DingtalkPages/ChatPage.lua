-- ============================================================================
-- 叮叮聊天详情页面 (Chat Page)
-- 事件驱动架构：支持自动消息播放、输入等待、随意敲打键盘
-- ============================================================================

local UI = require("urhox-libs/UI")
local DingtalkData = require("DingtalkData")
local ChatEventManager = require("ChatEventManager")
local ChatBubble = require("Utils.ChatBubble")
local ReplyManager = require("Level.ReplyManager")
local LevelManager = require("Level.LevelManager")
local Common = require("DingtalkPagesCommon")
local C = Common.C

local M = {}

-- 输入框颜色常量
local INPUT_BG_AUTO   = { 255, 255, 255, 255 }  -- 自动输入/默认：白色
local INPUT_BG_MANUAL = { 34, 120, 69, 255 }     -- 手动输入：深绿色
local INPUT_TEXT_AUTO   = { 25, 25, 25, 255 }     -- 自动输入文字颜色
local INPUT_TEXT_MANUAL = { 255, 255, 255, 255 }  -- 手动输入文字颜色（白色，配深绿背景）

-- 模块级变量：事件系统状态
local activeManager_ = nil
local pendingScroll_ = nil
local typingIndicator_ = nil
local activeInputField_ = nil
local activeSendFunc_ = nil
local inputBarPanel_ = nil    -- 输入栏外层 Panel，用于切换背景色
local updateSubscribed_ = false

-- 自动填充：记录上一次输入框文本，用于检测文本变化（兼容中文输入法）
local lastInputText_ = ""

-- 关卡回复提示（replyHint）自动填充状态
local activeChatName_ = ""    -- 当前聊天名
local replyHintText_ = nil    -- 当前提示文本
local replyHintIndex_ = 0     -- 已填充字符数
local replyHintTotal_ = 0     -- 总字符数

--- UTF-8 字符串长度
local function utf8Len(s)
    if not s or s == "" then return 0 end
    local len = 0
    for _ in s:gmatch("[%z\1-\127\194-\253][\128-\191]*") do
        len = len + 1
    end
    return len
end

--- UTF-8 子串（取前 n 个字符）
local function utf8Sub(s, n)
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

-- 复制 toast 相关
local copyToastLabel_ = nil   -- "已复制" toast Label
local copyToastTimer_ = 0     -- toast 剩余显示时间
local COPY_TOAST_DURATION = 1.5

local function ensureUpdate()
    -- 不再独立订阅 Update 事件（会覆盖 main.lua 的 HandleUpdate）
    -- 改由 main.lua 的 HandleUpdate 统一调度 HandleDingtalkChatPageUpdate
    updateSubscribed_ = true
end

--- Update event handler
function HandleDingtalkChatPageUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    if activeManager_ then
        activeManager_:Update(dt)

        -- "随意敲打键盘"：通过文本变化检测驱动自动填充（兼容中文输入法）
        if activeManager_:IsWaitingInput() and activeManager_:IsAutoFillEnabled() and activeInputField_ then
            local currentText = activeInputField_:GetValue() or ""
            if currentText ~= lastInputText_ then
                local result = activeManager_:OnTextChanged(currentText)
                if result ~= nil then
                    activeInputField_:SetValue(result)
                    lastInputText_ = result
                else
                    lastInputText_ = currentText
                end
            end
        end
    end
    -- 关卡回复提示自动填充（与 ChatEventManager 的 S4U 共用"随意敲打"范式）
    if replyHintText_ and activeInputField_
       and not (activeManager_ and activeManager_:IsWaitingInput()) then
        local currentText = activeInputField_:GetValue() or ""
        if currentText ~= lastInputText_ and currentText ~= "" then
            -- 玩家有新输入 → 推进自动填充
            local step = math.max(1, math.random(1, 2))
            replyHintIndex_ = math.min(replyHintIndex_ + step, replyHintTotal_)
            local partial = utf8Sub(replyHintText_, replyHintIndex_)
            activeInputField_:SetValue(partial)
            lastInputText_ = partial
        end
    end

    if pendingScroll_ then
        local sv = pendingScroll_
        pendingScroll_ = nil
        sv:ScrollToBottom()
    end

    -- 复制 toast 计时
    if copyToastTimer_ > 0 then
        copyToastTimer_ = copyToastTimer_ - dt
        if copyToastTimer_ <= 0 and copyToastLabel_ then
            copyToastLabel_:SetVisible(false)
        end
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
    lastInputText_ = ""
    activeChatName_ = chatName

    -- 初始化关卡回复提示自动填充
    local hint = ReplyManager.GetReplyHint("dingtalk", chatName)
    if hint then
        replyHintText_ = hint
        replyHintIndex_ = 0
        replyHintTotal_ = utf8Len(hint)
    else
        replyHintText_ = nil
        replyHintIndex_ = 0
        replyHintTotal_ = 0
    end

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
        if msg.msgType == "system" then
            msgListContainer:AddChild(ChatBubble.CreateSystemNotice(msg.text))
        else
            msgListContainer:AddChild(ChatBubble.Create(msg, chatIconBg, ChatBubble.DINGTALK))
        end
        pendingScroll_ = scrollView
    end

    -- 加载关卡运行时消息（已投递的消息）
    local existingMsgs = DingtalkData.GetRuntimeMessages(chatName)
    for _, msg in ipairs(existingMsgs) do
        addBubble(msg)
    end

    -- 注册消息监听器（新消息到达时自动显示）
    DingtalkData.SetMessageListener(chatName, function(msg)
        addBubble(msg)
    end)

    -- 关卡模式下不加载场景事件（关卡消息完全由 LevelMessageScheduler + messages.csv 驱动）
    if not LevelManager.IsPlaying() then
        local scenarioEvents = DingtalkData.GetChatScenario(chatName)

        local manager = ChatEventManager.Create(scenarioEvents, {
            onMessage = function(msg)
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
            end,

            onBranchHint = function(hints, timeout)
            end,

            onBranchMatched = function(nextId, matchType)
            end,

            onInputStateChanged = function(isManual)
                if inputBarPanel_ then
                    if isManual == true then
                        inputBarPanel_:SetStyle({ backgroundColor = INPUT_BG_MANUAL })
                    else
                        inputBarPanel_:SetStyle({ backgroundColor = INPUT_BG_AUTO })
                    end
                end
            end,

            onDone = function()
            end,
        })

        activeManager_ = manager
    end

    -- 注册复制成功回调 → 显示 toast
    ChatBubble.SetOnCopied(function(text)
        if copyToastLabel_ then
            copyToastLabel_:SetVisible(true)
            copyToastTimer_ = COPY_TOAST_DURATION
        end
    end)

    -- 初始历史消息加载完后，滚动到底部
    pendingScroll_ = scrollView

    -- 发送消息
    local function sendMessage(text)
        if not text or text == "" then return end
        local trimmed = text:match("^%s*(.-)%s*$")
        if trimmed == "" then return end

        -- 保存到数据层（AddMessage 会自动触发监听器 → addBubble）
        DingtalkData.AddMessage(chatName, "我", trimmed)

        -- 清空输入框
        if inputField then
            inputField:Clear()
        end
        lastInputText_ = ""

        -- 通知事件管理器：用户发了消息
        -- IsWaitingInput() 现在同时覆盖 wait_input 和 wait_choice 状态
        if activeManager_ and activeManager_:IsWaitingInput() then
            activeManager_:OnUserMessage(trimmed)
        end

        -- 关卡模式：通知 ReplyManager 玩家回复了消息
        ReplyManager.OnUserReply("dingtalk", chatName, trimmed)

        -- 清除已消费的回复提示，检查是否有下一条待回复
        replyHintText_ = nil
        replyHintIndex_ = 0
        replyHintTotal_ = 0
        local nextHint = ReplyManager.GetReplyHint("dingtalk", chatName)
        if nextHint then
            replyHintText_ = nextHint
            replyHintTotal_ = utf8Len(nextHint)
        end
    end

    -- 创建输入框：如果有回复提示，用提示文本做 placeholder
    local placeholderText = replyHintText_
        and "随意输入以回复..."
        or "输入消息..."
    inputField = UI.TextField {
        flexGrow = 1,
        height = 34,
        fontSize = 12,
        placeholder = placeholderText,
        onSubmit = function(self, value)
            sendMessage(value)
        end,
    }

    -- 存储引用供"随意敲打键盘"功能使用
    activeInputField_ = inputField
    activeSendFunc_ = sendMessage

    -- "已复制" toast 覆盖层
    copyToastLabel_ = UI.Panel {
        position = "absolute",
        top = "45%",
        alignSelf = "center",
        backgroundColor = { 0, 0, 0, 180 },
        borderRadius = 8,
        paddingHorizontal = 20,
        paddingVertical = 10,
        visible = false,
        children = {
            UI.Label {
                text = "已复制",
                fontSize = 13,
                fontColor = { 255, 255, 255, 255 },
            },
        },
    }

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
                            inputBarPanel_ = nil
                            lastInputText_ = ""
                            copyToastLabel_ = nil
                            copyToastTimer_ = 0
                            ChatBubble.SetOnCopied(nil)
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
            -- 输入栏（inputBarPanel_ 用于 onInputStateChanged 切换背景色）
            (function()
                inputBarPanel_ = UI.Panel {
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
                        width = 40, height = 30,
                        backgroundColor = { 230, 230, 230, 255 },
                        hoverBackgroundColor = { 210, 210, 210, 255 },
                        pressedBackgroundColor = { 190, 190, 190, 255 },
                        borderRadius = 4,
                        text = "粘贴",
                        textColor = C.text,
                        fontSize = 10,
                        onClick = function(self)
                            local clip = ui:GetClipboardText()
                            if clip and clip ~= "" and inputField then
                                local cur = inputField:GetValue() or ""
                                inputField:SetValue(cur .. clip)
                            end
                        end,
                    },
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
                }
                return inputBarPanel_
            end)(),
            -- "已复制" toast 覆盖层（绝对定位）
            copyToastLabel_,
        },
    }
end

return M
