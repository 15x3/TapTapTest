-- ============================================================================
-- 微言子页面模块 (WeChat Sub-Pages Module)
-- 包含：聊天详情、联系人详情
-- ============================================================================

local UI = require("urhox-libs/UI")
local WechatData = require("WechatData")
local ChatEventManager = require("ChatEventManager")
local ChatBubble = require("Utils.ChatBubble")
local ReplyManager = require("Level.ReplyManager")
local LevelManager = require("Level.LevelManager")
local GuideOverlay = require("UI.GuideOverlay")
local SoundManager = require("Utils.SoundManager")
local Colors = require("Utils.Colors")
local WechatCommon = require("WechatPagesCommon")

local M = {}

-- 模块级变量：事件系统状态
local wxActiveManager_ = nil       -- 当前活跃的 ChatEventManager 实例
local wxPendingScroll_ = nil        -- 需要滚动到底部的 ScrollView 引用
local wxTypingIndicator_ = nil      -- "正在输入"指示器 widget 引用
local wxTypingLabel_ = nil          -- 输入指示标签
local wxActiveInputField_ = nil    -- 当前聊天页的输入框引用
local wxActiveSendFunc_ = nil      -- 当前聊天页的发送函数引用
local wxInputBarPanel_ = nil       -- 输入栏外层 Panel，用于切换背景色
local wxPagesUpdateSubscribed_ = false  -- 是否已订阅 Update 事件

-- 自动填充：记录上一次输入框文本，用于检测文本变化（兼容中文输入法）
local wxLastInputText_ = ""

-- 关卡回复提示（replyHint）自动填充状态
local wxActiveChatName_ = ""
local wxReplyHintText_ = nil
local wxReplyHintIndex_ = 0
local wxReplyHintTotal_ = 0

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
local wxCopyToastLabel_ = nil   -- "已复制" toast Panel
local wxCopyToastTimer_ = 0     -- toast 剩余显示时间
local WX_COPY_TOAST_DURATION = 1.5

--- 确保 WechatPages 模块的 Update 标记已设置
local function ensureWxPagesUpdate()
    -- 不再独立订阅 Update 事件（会覆盖 main.lua 的 HandleUpdate）
    -- 改由 main.lua 的 HandleUpdate 统一调度 HandleWechatPagesUpdate
    wxPagesUpdateSubscribed_ = true
end

--- Update 事件处理：驱动事件管理器 + 延迟滚动 + 随意敲打键盘
function HandleWechatPagesUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()

    -- 驱动活跃的事件管理器
    if wxActiveManager_ then
        wxActiveManager_:Update(dt)

        -- "随意敲打键盘"：通过文本变化检测驱动自动填充（兼容中文输入法）
        if wxActiveManager_:IsWaitingInput() and wxActiveManager_:IsAutoFillEnabled() and wxActiveInputField_ then
            local currentText = wxActiveInputField_:GetValue() or ""
            if currentText ~= wxLastInputText_ then
                local result = wxActiveManager_:OnTextChanged(currentText)
                if result ~= nil then
                    wxActiveInputField_:SetValue(result)
                    wxLastInputText_ = result
                else
                    wxLastInputText_ = currentText
                end
            end
        end
    end

    -- 关卡回复提示自动填充（与 ChatEventManager 的 S4U 共用"随意敲打"范式）
    if wxReplyHintText_ and wxActiveInputField_
       and not (wxActiveManager_ and wxActiveManager_:IsWaitingInput()) then
        local currentText = wxActiveInputField_:GetValue() or ""
        if currentText ~= wxLastInputText_ and currentText ~= "" then
            local step = math.max(1, math.random(1, 2))
            wxReplyHintIndex_ = math.min(wxReplyHintIndex_ + step, wxReplyHintTotal_)
            local partial = utf8Sub(wxReplyHintText_, wxReplyHintIndex_)
            wxActiveInputField_:SetValue(partial)
            wxLastInputText_ = partial
        end
    end

    -- 处理延迟滚动
    if wxPendingScroll_ then
        local sv = wxPendingScroll_
        wxPendingScroll_ = nil
        sv:ScrollToBottom()
    end

    -- 复制 toast 计时
    if wxCopyToastTimer_ > 0 then
        wxCopyToastTimer_ = wxCopyToastTimer_ - dt
        if wxCopyToastTimer_ <= 0 and wxCopyToastLabel_ then
            wxCopyToastLabel_:SetVisible(false)
        end
    end
end

-- 输入框颜色常量
local INPUT_BG_AUTO   = { 255, 255, 255, 255 }  -- 自动输入/默认：白色
local INPUT_BG_MANUAL = { 34, 120, 69, 255 }     -- 手动输入：深绿色
local INPUT_TEXT_AUTO   = { 25, 25, 25, 255 }     -- 自动输入文字颜色
local INPUT_TEXT_MANUAL = { 255, 255, 255, 255 }  -- 手动输入文字颜色

-- 微言色彩体系（从共享模块引用）
local WX = WechatCommon.WX

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
    wxActiveInputField_ = nil
    wxActiveSendFunc_ = nil
    wxInputBarPanel_ = nil
    wxLastInputText_ = ""
    wxActiveChatName_ = chatName

    -- 初始化关卡回复提示自动填充
    local hint = ReplyManager.GetReplyHint("wechat", chatName)
    if hint then
        wxReplyHintText_ = hint
        wxReplyHintIndex_ = 0
        wxReplyHintTotal_ = utf8Len(hint)
    else
        wxReplyHintText_ = nil
        wxReplyHintIndex_ = 0
        wxReplyHintTotal_ = 0
    end

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

    -- 查找头像图片
    local chatAvatarImg = WechatData.GetAvatarImage(chatName)
    local selfAvatarImg = WechatData.SELF_AVATAR
    local bubbleOpts = {
        avatarImage = chatAvatarImg,
        selfAvatarImage = selfAvatarImg,
    }

    --- 添加一条消息气泡到列表
    local function addBubble(msg)
        if msg.msgType == "system" then
            msgListPanel:AddChild(ChatBubble.CreateSystemNotice(msg.text))
        else
            msgListPanel:AddChild(ChatBubble.Create(msg, chatIconBg, ChatBubble.WECHAT, bubbleOpts))
        end
        wxPendingScroll_ = scrollView
    end

    -- 加载关卡运行时消息（已投递的消息）
    local existingMsgs = WechatData.GetRuntimeMessages(chatName)
    for _, msg in ipairs(existingMsgs) do
        addBubble(msg)
    end

    -- 注册消息监听器（新消息到达时自动显示）
    WechatData.SetMessageListener(chatName, function(msg)
        addBubble(msg)
    end)

    -- 关卡模式下不加载场景事件（关卡消息完全由 LevelMessageScheduler + messages.csv 驱动）
    if not LevelManager.IsPlaying() then
        local scenarioEvents = WechatData.GetChatScenario(chatName)

        local manager = ChatEventManager.Create(scenarioEvents, {
            onMessage = function(msg)
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

            onAutoFill = function(partialText, isComplete)
            end,

            onBranchHint = function(hints, timeout)
            end,

            onBranchMatched = function(nextId, matchType)
            end,

            onInputStateChanged = function(isManual)
                if wxInputBarPanel_ then
                    if isManual == true then
                        wxInputBarPanel_:SetStyle({ backgroundColor = INPUT_BG_MANUAL })
                    else
                        wxInputBarPanel_:SetStyle({ backgroundColor = INPUT_BG_AUTO })
                    end
                end
            end,

            onDone = function()
            end,
        })

        wxActiveManager_ = manager
    end
    wxPendingScroll_ = scrollView

    -- 注册复制成功回调 → 显示 toast
    ChatBubble.SetOnCopied(function(text)
        if wxCopyToastLabel_ then
            wxCopyToastLabel_:SetVisible(true)
            wxCopyToastTimer_ = WX_COPY_TOAST_DURATION
        end
    end)

    -- 输入状态
    local inputValue = ""

    -- 发送消息
    local function sendMessage(text)
        if not text or text == "" then return end
        local trimmed = text:match("^%s*(.-)%s*$")
        if trimmed == "" then return end

        -- 播放发送音效
        SoundManager.PlaySFX(SoundManager.SFX.MSG_SENT, 0.5)

        -- 保存到数据层（AddMessage 会自动触发监听器 → addBubble，同时更新预览）
        WechatData.AddMessage(chatName, "我", trimmed)

        -- 清空输入框状态
        inputValue = ""
        wxLastInputText_ = ""
        if M._activeTextField then
            M._activeTextField:SetValue("")
        end

        -- 通知事件管理器：用户发了消息
        if wxActiveManager_ and wxActiveManager_:IsWaitingInput() then
            wxActiveManager_:OnUserMessage(trimmed)
        end

        -- 关卡模式：通知 ReplyManager 玩家回复了消息
        ReplyManager.OnUserReply("wechat", chatName, trimmed)

        -- 清除已消费的回复提示，检查是否有下一条待回复
        wxReplyHintText_ = nil
        wxReplyHintIndex_ = 0
        wxReplyHintTotal_ = 0
        local nextHint = ReplyManager.GetReplyHint("wechat", chatName)
        if nextHint then
            wxReplyHintText_ = nextHint
            wxReplyHintTotal_ = utf8Len(nextHint)
        end
    end

    -- 发送按钮（常驻显示）
    local sendBtn = UI.Button {
        width = 50, height = 30,
        backgroundColor = WX.green,
        hoverBackgroundColor = { 6, 170, 85, 255 },
        pressedBackgroundColor = { 5, 150, 75, 255 },
        borderRadius = 4,
        text = "发送",
        textColor = WX.white,
        fontSize = 11,
        onClick = function(self)
            if inputValue == "" then return end
            sendMessage(inputValue)
            inputValue = ""
            if M._activeTextField then
                M._activeTextField:SetValue("")
            end
        end,
    }

    -- 输入框：如果有回复提示，用提示文本做 placeholder
    local wxPlaceholderText = wxReplyHintText_
        and "随意输入以回复..."
        or "输入消息..."
    local textField = UI.TextField {
        flexGrow = 1, flexBasis = 0,
        height = 36,
        fontSize = 13,
        placeholder = wxPlaceholderText,
        value = "",
        borderRadius = 6,
        backgroundColor = WX.white,
        paddingHorizontal = 10,
        onChange = function(self, value)
            inputValue = value
        end,
        onSubmit = function(self, value)
            if value == "" then return end
            sendMessage(value)
            inputValue = ""
            self:SetValue("")
        end,
    }

    -- 缓存当前活跃的输入框引用
    M._activeTextField = textField

    -- 存储引用供"随意敲打键盘"功能使用
    wxActiveInputField_ = textField
    wxActiveSendFunc_ = sendMessage

    -- "已复制" toast 覆盖层
    wxCopyToastLabel_ = UI.Panel {
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

    local chatPanel = UI.Panel {
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
                wxActiveInputField_ = nil
                wxActiveSendFunc_ = nil
                wxInputBarPanel_ = nil
                wxLastInputText_ = ""
                wxCopyToastLabel_ = nil
                wxCopyToastTimer_ = 0
                ChatBubble.SetOnCopied(nil)
                onBack()
            end),
            -- 消息列表
            scrollView,
            -- 正在输入指示
            typingPanel,
            -- 底部输入栏（wxInputBarPanel_ 用于 onInputStateChanged 切换背景色）
            (function()
                wxInputBarPanel_ = UI.Panel {
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
                        UI.Button {
                            width = 40, height = 30,
                            backgroundColor = { 230, 230, 230, 255 },
                            hoverBackgroundColor = { 210, 210, 210, 255 },
                            pressedBackgroundColor = { 190, 190, 190, 255 },
                            borderRadius = 4,
                            text = "粘贴",
                            textColor = WX.text,
                            fontSize = 10,
                            onClick = function(self)
                                local clip = ui:GetClipboardText()
                                if clip and clip ~= "" and textField then
                                    local cur = textField:GetValue() or ""
                                    textField:SetValue(cur .. clip)
                                    inputValue = cur .. clip
                                    
                                end
                            end,
                        },
                        sendBtn,
                    },
                }
                return wxInputBarPanel_
            end)(),
            -- "已复制" toast 覆盖层（绝对定位）
            wxCopyToastLabel_,
        },
    }

    -- 首次进入有待回复消息的聊天 → 显示自动回复引导
    if wxReplyHintText_ then
        GuideOverlay.ShowOnce("guide_auto_reply", {
            title = "自动回复",
            lines = {
                "这条消息需要你回复",
                "随意敲几下键盘即可自动填充",
                "填充完成后点击「发送」",
            },
            parent = chatPanel,
        })
    end

    return chatPanel
end



-- ============================================================================
-- 联系人详情页面（个人名片）
-- ============================================================================

function M.CreateContactDetailPage(contact, onBack, onSendMessage)
    local colorSeed = string.byte(contact.initial, 1) or 65
    local avatarBg = Colors.GetAvatarColor(contact.initial)
    local detailAvatarImg = WechatData.GetAvatarImage(contact.name)

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

    -- 联系人详情头像
    local detailAvatar
    if detailAvatarImg then
        detailAvatar = UI.Panel {
            width = 56, height = 56,
            backgroundImage = detailAvatarImg,
            backgroundFit = "cover",
            borderRadius = 8,
        }
    else
        detailAvatar = UI.Panel {
            width = 56, height = 56,
            backgroundColor = avatarBg,
            borderRadius = 8,
            justifyContent = "center",
            alignItems = "center",
            children = {
                UI.Label { text = contact.initial, fontSize = 22, fontColor = { 255, 255, 255, 255 } },
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
                                    detailAvatar,
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
                                                text = "微言号: wx_" .. string.lower(contact.initial) .. string.format("%04d", colorSeed),
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
