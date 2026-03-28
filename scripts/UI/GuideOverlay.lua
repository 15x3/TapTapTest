-- ============================================================================
-- 引导层模块 (Guide Overlay)
-- 首次触发时显示操作提示，点击任意处关闭，每个 key 只显示一次
-- ============================================================================

local UI = require("urhox-libs/UI")
local SoundManager = require("Utils.SoundManager")

local M = {}

-- 已显示过的引导 key 集合（关卡内去重）
local shownKeys_ = {}

-- 当前正在显示的 overlay 引用（同时只显示一个）
---@type table|nil
local activeOverlay_ = nil

--- 重置所有引导状态（关卡重置时调用）
function M.Reset()
    shownKeys_ = {}
    activeOverlay_ = nil
end

--- 是否正在显示引导层
function M.IsShowing()
    return activeOverlay_ ~= nil
end

--- 检查某个引导 key 是否已显示过
---@param key string
---@return boolean
function M.HasShown(key)
    return shownKeys_[key] == true
end

--- 手动标记某个引导 key 为已显示
---@param key string
function M.MarkShown(key)
    shownKeys_[key] = true
end

--- 显示一次性引导层
---@param key string 引导唯一标识（同一 key 只显示一次）
---@param config table { title:string, lines:string[], parent:table }
---  title  - 标题文字
---  lines  - 提示内容行数组
---  parent - 要挂载到的父容器（需支持绝对定位子元素）
---@return boolean 是否成功显示（false = 已显示过或正在显示）
function M.ShowOnce(key, config)
    -- 已显示过 → 跳过
    if shownKeys_[key] then return false end
    -- 正在显示另一个 → 跳过
    if activeOverlay_ then return false end
    -- 缺少父容器 → 跳过
    if not config.parent then return false end

    shownKeys_[key] = true

    -- 构建提示文本行
    local contentChildren = {}

    if config.title then
        contentChildren[#contentChildren + 1] = UI.Label {
            text = config.title,
            fontSize = 14,
            fontColor = { 255, 255, 255, 255 },
            fontWeight = "bold",
            textAlign = "center",
            marginBottom = 8,
        }
    end

    if config.lines then
        for _, line in ipairs(config.lines) do
            contentChildren[#contentChildren + 1] = UI.Label {
                text = line,
                fontSize = 12,
                fontColor = { 240, 240, 240, 255 },
                textAlign = "center",
                marginBottom = 4,
            }
        end
    end

    -- 底部提示
    contentChildren[#contentChildren + 1] = UI.Label {
        text = "点击任意处关闭",
        fontSize = 10,
        fontColor = { 180, 180, 180, 200 },
        textAlign = "center",
        marginTop = 12,
    }

    -- 创建 overlay（半透明全屏遮罩 + 居中提示卡片）
    local overlay
    overlay = UI.Button {
        position = "absolute",
        top = 0, left = 0,
        width = "100%",
        height = "100%",
        backgroundColor = { 0, 0, 0, 160 },
        borderRadius = 0,
        justifyContent = "center",
        alignItems = "center",
        zIndex = 900,
        onClick = function(self)
            -- 点击关闭
            if overlay and config.parent then
                config.parent:RemoveChild(overlay)
            end
            activeOverlay_ = nil
        end,
        children = {
            UI.Panel {
                width = "75%",
                backgroundColor = { 40, 40, 50, 230 },
                borderRadius = 12,
                paddingVertical = 20,
                paddingHorizontal = 16,
                alignItems = "center",
                pointerEvents = "none",
                children = contentChildren,
            },
        },
    }

    config.parent:AddChild(overlay)
    activeOverlay_ = overlay
    SoundManager.PlaySFX(SoundManager.SFX.GUIDE_POPUP, 0.5)
    return true
end

return M
