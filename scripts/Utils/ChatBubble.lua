-- ============================================================================
-- 聊天气泡公共组件 (Chat Bubble Component)
-- 功能: 统一的聊天气泡 UI 创建，供钉钉和微信聊天页面复用
-- ============================================================================

local UI = require("urhox-libs/UI")

local ChatBubble = {}

-- ============================================================================
-- 气泡样式预设
-- ============================================================================

--- 钉钉风格配置
ChatBubble.DINGTALK = {
    selfBubbleColor  = { 149, 215, 255, 255 },
    otherBubbleColor = { 255, 255, 255, 255 },
    textColor        = { 25, 25, 25, 255 },
    selfAvatarColor  = { 100, 160, 220, 255 },
    avatarRadius     = 6,
    bubbleRadius     = 8,
    avatarSize       = 32,
}

--- 微信风格配置
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

    local bubble = UI.Panel {
        maxWidth = "70%",
        backgroundColor = bubbleBg,
        borderRadius = style.bubbleRadius,
        paddingHorizontal = 10,
        paddingVertical = 8,
        children = {
            UI.Label {
                text = displayText,
                fontSize = 11,
                fontColor = style.textColor,
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
