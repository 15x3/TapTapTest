-- ============================================================================
-- 聊天气泡公共组件 (Chat Bubble Component)
-- 功能: 统一的聊天气泡 UI 创建，供叮叮和微言聊天页面复用
-- 支持: 长按/右键弹出上下文菜单（转发/复制），点击复制到剪贴板
-- ============================================================================

local UI = require("urhox-libs/UI")
local SoundManager = require("Utils.SoundManager")

local ChatBubble = {}

--- 复制成功回调（由 ChatPage 注册，用于显示 toast 提示）
---@type fun(text: string)|nil
ChatBubble._onCopied = nil

--- 上下文菜单回调（由关卡系统注册，长按/右键时触发）
--- 签名: function(msg, x, y)  msg=消息数据, x/y=弹出位置
---@type fun(msg: table, x: number, y: number)|nil
ChatBubble._onContextMenu = nil

--- 注册复制成功回调
---@param callback fun(text: string)|nil
function ChatBubble.SetOnCopied(callback)
    ChatBubble._onCopied = callback
end

--- 注册上下文菜单回调（关卡模式使用）
---@param callback fun(msg: table, x: number, y: number)|nil
function ChatBubble.SetOnContextMenu(callback)
    ChatBubble._onContextMenu = callback
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
---@param opts table|nil 扩展选项 { avatarImage=string, selfAvatarImage=string }
---@return table UI 组件
function ChatBubble.Create(msg, chatIconBg, style, opts)
    style = style or ChatBubble.DINGTALK
    opts = opts or {}

    local isSelf = msg.sender == "我"
    local bubbleBg = isSelf and style.selfBubbleColor or style.otherBubbleColor
    local alignRow = isSelf and "flex-end" or "flex-start"

    local avatarBg = isSelf and style.selfAvatarColor or (chatIconBg or { 80, 120, 200, 255 })
    local avatarText = isSelf and "我" or string.sub(msg.sender, 1, 3)

    -- 优先使用头像图片
    local avatarImg = isSelf and opts.selfAvatarImage or opts.avatarImage

    local avatar
    if avatarImg then
        avatar = UI.Panel {
            width = style.avatarSize, height = style.avatarSize,
            backgroundImage = avatarImg,
            backgroundFit = "cover",
            borderRadius = style.avatarRadius,
        }
    else
        avatar = UI.Panel {
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
    end

    local displayText = msg.text
    if not displayText or displayText == "" then
        displayText = " "  -- 防止空文本导致布局异常
    end

    -- 气泡面板：使用 Panel 实现 children 自适应尺寸 + 点击交互
    local bubble = UI.Panel {
        maxWidth = "70%",
        backgroundColor = bubbleBg,
        borderRadius = style.bubbleRadius,
        paddingHorizontal = 10,
        paddingVertical = 8,
        cursor = "pointer",

        -- 点击：弹出上下文菜单（PC左键 / 移动端轻触，统一入口）
        onClick = function(self)
            print(string.format("[ChatBubble] onClick triggered | _onContextMenu=%s | sender=%s",
                tostring(ChatBubble._onContextMenu ~= nil), msg.sender or "?"))
            if ChatBubble._onContextMenu then
                -- 使用引擎原始鼠标坐标，转换到 UI 基准坐标系
                local scale = UI.GetScale()
                local mx = input.mousePosition.x / scale
                local my = input.mousePosition.y / scale
                print(string.format("[ChatBubble] 弹出菜单 at (%.0f, %.0f) scale=%.2f", mx, my, scale))
                ChatBubble._onContextMenu(msg, mx, my)
                return
            end
            if msg.text and msg.text ~= "" then
                ui:SetClipboardText(msg.text)
                SoundManager.PlaySFX(SoundManager.SFX.COPY, 0.5)
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

--- 创建系统提示（居中灰色文字，无气泡无头像）
---@param text string 提示文字
---@return table UI 组件
function ChatBubble.CreateSystemNotice(text)
    return UI.Panel {
        width = "100%",
        flexDirection = "row",
        justifyContent = "center",
        paddingVertical = 6,
        children = {
            UI.Panel {
                backgroundColor = { 0, 0, 0, 60 },
                borderRadius = 4,
                paddingHorizontal = 10,
                paddingVertical = 4,
                children = {
                    UI.Label {
                        text = text or "",
                        fontSize = 10,
                        fontColor = { 160, 160, 180, 255 },
                        textAlign = "center",
                        pointerEvents = "none",
                    },
                },
            },
        },
    }
end

return ChatBubble
