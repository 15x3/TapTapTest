-- ============================================================================
-- ContextMenu - 上下文菜单组件
-- 功能: 长按/右键弹出的浮动菜单（转发/复制）
-- 样式: 像素风暗色菜单
-- ============================================================================

local UI = require("urhox-libs/UI")
local SoundManager = require("Utils.SoundManager")

local ContextMenu = {}

--- 当前显示的菜单（用于关闭）
---@type table|nil
local currentMenu_ = nil

--- 菜单挂载的父容器
---@type table|nil
local mountParent_ = nil

--- 像素风颜色
local COLORS = {
    MENU_BG      = { 40, 40, 60, 245 },
    MENU_BORDER  = { 80, 80, 110, 255 },
    ITEM_HOVER   = { 60, 60, 90, 255 },
    ITEM_PRESSED = { 80, 80, 120, 255 },
    TEXT_NORMAL  = { 220, 220, 240, 255 },
    TEXT_DIM     = { 140, 140, 170, 255 },
    DIVIDER      = { 60, 60, 90, 255 },
}

-- ============================================================================
-- 核心 API
-- ============================================================================

--- 设置菜单挂载容器（通常是 phoneFrame_）
---@param parent table UI 组件，菜单将 AddChild 到此容器
function ContextMenu.SetMountParent(parent)
    mountParent_ = parent
end

--- 显示上下文菜单
---@param items table[] 菜单项列表 { { label=string, onClick=function }, ... }
---@param x number 弹出位置 X（相对于 mountParent）
---@param y number 弹出位置 Y
function ContextMenu.Show(items, x, y)
    -- 先关闭已有菜单
    ContextMenu.Close()

    if not mountParent_ then
        print("[ContextMenu] 警告: 未设置 mountParent，无法显示菜单")
        return
    end

    SoundManager.PlaySFX(SoundManager.SFX.CONTEXT_MENU, 0.5)
    print(string.format("[ContextMenu] Show at (%.0f, %.0f) | items=%d", x, y, #items))

    -- 构建菜单项
    local menuChildren = {}
    for i, item in ipairs(items) do
        if item.type == "divider" then
            menuChildren[#menuChildren + 1] = UI.Panel {
                width = "100%",
                height = 1,
                backgroundColor = COLORS.DIVIDER,
            }
        else
            menuChildren[#menuChildren + 1] = UI.Button {
                width = "100%",
                height = 36,
                backgroundColor = { 0, 0, 0, 0 },
                hoverBackgroundColor = COLORS.ITEM_HOVER,
                pressedBackgroundColor = COLORS.ITEM_PRESSED,
                borderRadius = 0,
                paddingHorizontal = 16,
                justifyContent = "center",
                alignItems = "flex-start",
                onClick = function(self)
                    ContextMenu.Close()
                    if item.onClick then
                        item.onClick()
                    end
                end,
                children = {
                    UI.Label {
                        text = item.label or "",
                        fontSize = 12,
                        fontColor = item.disabled and COLORS.TEXT_DIM or COLORS.TEXT_NORMAL,
                        pointerEvents = "none",
                    },
                },
            }
        end
    end

    -- 菜单面板
    local menuPanel = UI.Panel {
        position = "absolute",
        left = x,
        top = y,
        minWidth = 120,
        backgroundColor = COLORS.MENU_BG,
        borderRadius = 6,
        borderWidth = 1,
        borderColor = COLORS.MENU_BORDER,
        flexDirection = "column",
        paddingVertical = 4,
        zIndex = 900,
        boxShadow = {
            { x = 0, y = 4, blur = 12, spread = 2, color = { 0, 0, 0, 150 } },
        },
        children = menuChildren,
    }

    -- 透明遮罩层（点击关闭菜单）
    local backdrop = UI.Button {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        backgroundColor = { 0, 0, 0, 1 },  -- 近似透明
        hoverBackgroundColor = { 0, 0, 0, 1 },
        pressedBackgroundColor = { 0, 0, 0, 1 },
        borderRadius = 0,
        zIndex = 899,
        onClick = function(self)
            ContextMenu.Close()
        end,
    }

    -- 将遮罩和菜单添加到父容器
    mountParent_:AddChild(backdrop)
    mountParent_:AddChild(menuPanel)

    currentMenu_ = {
        menuPanel = menuPanel,
        backdrop = backdrop,
    }
end

--- 关闭上下文菜单
function ContextMenu.Close()
    if not currentMenu_ or not mountParent_ then return end

    mountParent_:RemoveChild(currentMenu_.backdrop)
    mountParent_:RemoveChild(currentMenu_.menuPanel)
    currentMenu_ = nil
end

--- 是否正在显示
---@return boolean
function ContextMenu.IsVisible()
    return currentMenu_ ~= nil
end

return ContextMenu
