-- ============================================================================
-- DeskWidget - 桌面可拖动控件通用类
-- 用途: 在手机界面外的桌面区域创建可拖动控件
-- 支持: 拖动、点击、自定义子元素、自定义渲染
-- ============================================================================

local UI = require("urhox-libs/UI")

local DeskWidget = {}
DeskWidget.__index = DeskWidget

--- 拖动判定阈值（像素），移动距离小于此值视为点击
local CLICK_THRESHOLD = 5

--- 创建一个桌面可拖动控件
---@param opts table 配置项
---   opts.x          number   初始 X 位置（默认 20）
---   opts.y          number   初始 Y 位置（默认 20）
---   opts.width      number   控件宽度（默认 120）
---   opts.height     number   控件高度（默认 80）
---   opts.backgroundColor  table   背景色 {r,g,b,a}（默认半透明深色）
---   opts.borderRadius     number  圆角半径（默认 8）
---   opts.borderWidth      number  边框宽度（默认 0）
---   opts.borderColor      table   边框颜色
---   opts.boxShadow        table   阴影配置
---   opts.children         table   子元素列表（UI 组件）
---   opts.draggable        boolean 是否可拖动（默认 true）
---   opts.onClick          function(widget)  点击回调
---   opts.onDragStart      function(widget, x, y)  拖动开始回调
---   opts.onDragMove       function(widget, x, y)  拖动中回调
---   opts.onDragEnd        function(widget, x, y)  拖动结束回调
---   opts.onRender         function(widget)  自定义渲染回调（预留）
---@return table widget 控件实例
function DeskWidget.Create(opts)
    opts = opts or {}

    local self = setmetatable({}, DeskWidget)

    -- 配置
    self.x = opts.x or 20
    self.y = opts.y or 20
    self.width = opts.width or 120
    self.height = opts.height or 80
    self.draggable = opts.draggable ~= false -- 默认 true
    self.onClick = opts.onClick
    self.onDragStart = opts.onDragStart
    self.onDragMove = opts.onDragMove
    self.onDragEnd = opts.onDragEnd
    self.onRender = opts.onRender

    -- 拖动状态
    self._dragging = false
    self._offsetX = 0
    self._offsetY = 0
    self._totalMoved = 0

    -- 构建 UI 元素
    local widgetSelf = self
    self.element = UI.Panel {
        position = "absolute",
        left = self.x,
        top = self.y,
        width = self.width,
        height = self.height,
        backgroundColor = opts.backgroundColor or { 30, 30, 50, 200 },
        backgroundImage = opts.backgroundImage,
        backgroundFit = opts.backgroundFit,
        borderRadius = opts.borderRadius or 8,
        borderWidth = opts.borderWidth or 0,
        borderColor = opts.borderColor,
        boxShadow = opts.boxShadow or {
            { x = 0, y = 4, blur = 12, spread = 2, color = { 0, 0, 0, 120 } },
        },
        overflow = "hidden",
        flexDirection = "column",
        justifyContent = opts.justifyContent or "center",
        alignItems = opts.alignItems or "center",
        zIndex = opts.zIndex or 100,
        children = opts.children or {},

        onPointerDown = function(event, widget)
            if not widgetSelf.draggable then return end
            if not event:IsPrimaryAction() then return end
            widgetSelf._dragging = true
            widgetSelf._offsetX = event.x - (widget.props.left or 0)
            widgetSelf._offsetY = event.y - (widget.props.top or 0)
            widgetSelf._totalMoved = 0
            if widgetSelf.onDragStart then
                widgetSelf.onDragStart(widgetSelf, event.x, event.y)
            end
        end,

        onPointerMove = function(event, widget)
            if not widgetSelf._dragging then return end
            local newX = event.x - widgetSelf._offsetX
            local newY = event.y - widgetSelf._offsetY
            widgetSelf.x = newX
            widgetSelf.y = newY
            widgetSelf._totalMoved = widgetSelf._totalMoved
                + math.abs(event.deltaX or 0)
                + math.abs(event.deltaY or 0)
            widget:SetStyle({ left = newX, top = newY })
            if widgetSelf.onDragMove then
                widgetSelf.onDragMove(widgetSelf, newX, newY)
            end
        end,

        onPointerUp = function(event, widget)
            if not widgetSelf._dragging then return end
            widgetSelf._dragging = false
            if widgetSelf._totalMoved < CLICK_THRESHOLD then
                -- 移动距离极小，视为点击
                if widgetSelf.onClick then
                    widgetSelf.onClick(widgetSelf)
                end
            else
                if widgetSelf.onDragEnd then
                    widgetSelf.onDragEnd(widgetSelf, widgetSelf.x, widgetSelf.y)
                end
            end
        end,
    }

    return self
end

--- 获取 UI 元素（用于添加到父容器）
---@return table UI.Panel
function DeskWidget:GetElement()
    return self.element
end

--- 设置位置
---@param x number
---@param y number
function DeskWidget:SetPosition(x, y)
    self.x = x
    self.y = y
    if self.element then
        self.element:SetStyle({ left = x, top = y })
    end
end

--- 设置可见性
---@param visible boolean
function DeskWidget:SetVisible(visible)
    if self.element then
        self.element:SetStyle({ display = visible and "flex" or "none" })
    end
end

--- 设置是否可拖动
---@param draggable boolean
function DeskWidget:SetDraggable(draggable)
    self.draggable = draggable
end

--- 更新样式
---@param style table
function DeskWidget:SetStyle(style)
    if self.element then
        self.element:SetStyle(style)
    end
end

--- 添加子元素
---@param child table UI 组件
function DeskWidget:AddChild(child)
    if self.element then
        self.element:AddChild(child)
    end
end

--- 清除子元素
function DeskWidget:ClearChildren()
    if self.element then
        self.element:ClearChildren()
    end
end

return DeskWidget
