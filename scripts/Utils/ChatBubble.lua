-- ============================================================================
-- 聊天气泡公共组件 (Chat Bubble Component)
-- 功能: 统一的聊天气泡 UI 创建，供叮叮和微言聊天页面复用
-- 支持: 点击气泡复制消息文本到剪贴板
-- ============================================================================

local UI = require("urhox-libs/UI")

local ChatBubble = {}

--- 复制成功回调（由 ChatPage 注册，用于显示 toast 提示）
---@type fun(text: string)|nil
ChatBubble._onCopied = nil

--- 注册复制成功回调
---@param callback fun(text: string)|nil
function ChatBubble.SetOnCopied(callback)
    ChatBubble._onCopied = callback
end

--- 生成略深的 hover/pressed 颜色
---@param color table RGBA
---@param delta number 变暗幅度（0~255）
---@return table RGBA
local function darken(color, delta)
    return {
        math.max(0, color[1] - delta),
        math.max(0, color[2] - delta),
        math.max(0, color[3] - delta),
        color[4],
    }
end

-- ============================================================================
-- 气泡样式预设
-- ============================================================================

--- 叮叮风格配置
ChatBubble.DINGTALK = {
    selfBubbleColor  = { 149, 215, 255, 255 },
    otherBubbleColor = { 255, 255, 255, 255 },
    textColor        = { 25, 25, 25, 255 },
    selfAvatarColor  = { 100, 160, 220, 255 },
    avatarRadius     = 6,
    bubbleRadius     = 8,
    avatarSize       = 32,
}

--- 微言风格配置
ChatBubble.WECHAT = {
    selfBubbleColor  = { 149, 215, 105, 255 },
    otherBubbleColor = { 255, 255, 255, 255 },
    textColor        = { 25, 25, 25, 255 },
    selfAvatarColor  = { 100, 160, 220, 255 },
    avatarRadius     = 4,
    bubbleRadius     = 4,
    avatarSize       = 34,
}

-- ============================================================================
-- 气泡创建
-- ============================================================================

--- 创建聊天气泡
---@param msg table 消息数据 { sender, text }
---@param chatIconBg table|nil 对方头像背景色 RGBA
---@param style table|nil 风格配置（默认使用 DINGTALK）
---@return table UI 组件
function ChatBubble.Create(msg, chatIconBg, style)
    style = style or ChatBubble.DINGTALK

    local isSelf = msg.sender == "我"
    local bubbleBg = isSelf and style.selfBubbleColor or style.otherBubbleColor
    local alignRow = isSelf and "flex-end" or "flex-start"

    local avatarBg = isSelf and style.selfAvatarColor or (chatIconBg or { 80, 120, 200, 255 })
    local avatarText = isSelf and "我" or string.sub(msg.sender, 1, 3)

    local avatar = UI.Panel {
        width = style.avatarSize, height = style.avatarSize,
        backgroundColor = avatarBg,
        borderRadius = style.avatarRadius,
        justifyContent = "center",
        alignItems = "center",
        children = {
            UI.Label {
                text = avatarText,
                fontSize = 9,
                fontColor = { 255, 255, 255, 255 },
                textAlign = "center",
            },
        },
    }

    local displayText = msg.text
    if not displayText or displayText == "" then
        displayText = " "  -- 防止空文本导致布局异常
    end

    local bubble = UI.Button {
        maxWidth = "70%",
        backgroundColor = bubbleBg,
        hoverBackgroundColor = darken(bubbleBg, 15),
        pressedBackgroundColor = darken(bubbleBg, 30),
        borderRadius = style.bubbleRadius,
        paddingHorizontal = 10,
        paddingVertical = 8,
        onClick = function(self)
            if msg.text and msg.text ~= "" then
                ui:SetClipboardText(msg.text)
                if ChatBubble._onCopied then
                    ChatBubble._onCopied(msg.text)
                end
            end
        end,
        children = {
            UI.Label {
                text = displayText,
                fontSize = 11,
                fontColor = style.textColor,
                pointerEvents = "none",
            },
        },
    }

    -- 气泡行（头像 + 气泡，方向根据发送者不同）
    local rowChildren = isSelf and { bubble, avatar } or { avatar, bubble }

    return UI.Panel {
        width = "100%",
        flexDirection = "column",
        children = {
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                justifyContent = alignRow,
                alignItems = "flex-start",
                gap = 6,
                children = rowChildren,
            },
        },
    }
end

return ChatBubble
