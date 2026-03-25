-- ============================================================================
-- 钉钉待办页面 (Todo Page)
-- ============================================================================

local UI = require("urhox-libs/UI")
local DingtalkData = require("DingtalkData")
local Common = require("DingtalkPagesCommon")
local C = Common.C

local M = {}

function M.Create(onBack)
    local priorityColors = {
        high = C.red,
        medium = C.orange,
        low = C.blue,
    }
    local priorityLabels = {
        high = "紧急",
        medium = "普通",
        low = "较低",
    }

    local pageContainer = UI.Panel {
        width = "100%",
        height = "100%",
        backgroundColor = C.bg,
        flexDirection = "column",
    }

    local function refreshPage()
        pageContainer:ClearChildren()

        local todoData = DingtalkData.GetTodos()

        -- 统计
        local pendingCount = 0
        local doneCount = 0
        for _, todo in ipairs(todoData) do
            if todo.done then doneCount = doneCount + 1 else pendingCount = pendingCount + 1 end
        end

        -- 创建待办项 widget
        local function CreateTodoItem(todo, index)
            local pColor = priorityColors[todo.priority]
            return UI.Button {
                width = "100%",
                height = 56,
                backgroundColor = { 255, 255, 255, 255 },
                hoverBackgroundColor = { 248, 248, 248, 255 },
                pressedBackgroundColor = { 240, 240, 240, 255 },
                borderRadius = 0,
                flexDirection = "row",
                alignItems = "center",
                paddingHorizontal = 14,
                gap = 10,
                borderBottomWidth = 1,
                borderBottomColor = { 245, 245, 245, 255 },
                onClick = function(self)
                    DingtalkData.ToggleTodo(index)
                    refreshPage()
                end,
                children = {
                    -- 圆圈勾选框
                    UI.Panel {
                        width = 22, height = 22,
                        borderRadius = 11,
                        borderWidth = 2,
                        borderColor = todo.done and C.green or { 200, 200, 200, 255 },
                        backgroundColor = todo.done and C.green or { 0, 0, 0, 0 },
                        justifyContent = "center",
                        alignItems = "center",
                        pointerEvents = "none",
                        children = todo.done and {
                            UI.Label { text = "v", fontSize = 10, fontColor = C.white },
                        } or {},
                    },
                    -- 内容
                    UI.Panel {
                        flexGrow = 1, flexBasis = 0, flexShrink = 1,
                        flexDirection = "column",
                        gap = 3,
                        pointerEvents = "none",
                        children = {
                            UI.Label {
                                text = todo.text,
                                fontSize = 12,
                                fontColor = todo.done and C.textSec or C.text,
                            },
                            UI.Panel {
                                flexDirection = "row",
                                gap = 8,
                                alignItems = "center",
                                children = {
                                    UI.Panel {
                                        paddingHorizontal = 5,
                                        paddingVertical = 1,
                                        backgroundColor = { pColor[1], pColor[2], pColor[3], 25 },
                                        borderRadius = 3,
                                        children = {
                                            UI.Label { text = priorityLabels[todo.priority], fontSize = 8, fontColor = pColor },
                                        },
                                    },
                                    UI.Label { text = todo.due, fontSize = 9, fontColor = C.textSec },
                                },
                            },
                        },
                    },
                },
            }
        end

        -- 分类
        local pendingWidgets = {}
        local doneWidgets = {}
        for i, todo in ipairs(todoData) do
            if todo.done then
                doneWidgets[#doneWidgets + 1] = CreateTodoItem(todo, i)
            else
                pendingWidgets[#pendingWidgets + 1] = CreateTodoItem(todo, i)
            end
        end

        -- 顶栏（含 + 按钮）
        local header = UI.Panel {
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
                    onClick = function(self) onBack() end,
                },
                UI.Label {
                    text = string.format("待办 (%d)", pendingCount),
                    fontSize = 14,
                    fontColor = C.text,
                    flexGrow = 1,
                    flexBasis = 0,
                },
                UI.Button {
                    width = 30, height = 30,
                    backgroundColor = C.blue,
                    hoverBackgroundColor = { 38, 100, 230, 255 },
                    pressedBackgroundColor = { 28, 80, 200, 255 },
                    borderRadius = 15,
                    text = "+",
                    textColor = C.white,
                    fontSize = 16,
                    onClick = function(self)
                        local newText = ""
                        local newPriority = "medium"

                        local modal = UI.Modal {
                            title = "新增待办",
                            size = "sm",
                            closeOnOverlay = true,
                            showCloseButton = true,
                        }

                        local priContainer = UI.Panel {
                            width = "100%",
                            flexDirection = "row",
                            gap = 8,
                        }

                        local priOptions = {
                            { key = "high", label = "紧急", color = C.red },
                            { key = "medium", label = "普通", color = C.orange },
                            { key = "low", label = "较低", color = C.blue },
                        }

                        local function rebuildPriority()
                            priContainer:ClearChildren()
                            for _, opt in ipairs(priOptions) do
                                local sel = (newPriority == opt.key)
                                priContainer:AddChild(UI.Button {
                                    height = 26,
                                    paddingHorizontal = 12,
                                    backgroundColor = sel and opt.color or { 240, 240, 240, 255 },
                                    hoverBackgroundColor = sel and opt.color or { 230, 230, 230, 255 },
                                    pressedBackgroundColor = sel and opt.color or { 220, 220, 220, 255 },
                                    borderRadius = 13,
                                    text = opt.label,
                                    textColor = sel and C.white or C.text,
                                    fontSize = 10,
                                    onClick = function(s)
                                        newPriority = opt.key
                                        rebuildPriority()
                                    end,
                                })
                            end
                        end
                        rebuildPriority()

                        modal:AddContent(UI.Panel {
                            width = "100%",
                            flexDirection = "column",
                            gap = 12,
                            padding = 4,
                            children = {
                                UI.TextField {
                                    placeholder = "请输入待办内容...",
                                    onChange = function(s, v) newText = v end,
                                },
                                UI.Panel {
                                    flexDirection = "column",
                                    gap = 6,
                                    children = {
                                        UI.Label { text = "优先级", fontSize = 11, fontColor = C.textSec },
                                        priContainer,
                                    },
                                },
                            },
                        })

                        modal:SetFooter(UI.Panel {
                            flexDirection = "row",
                            gap = 8,
                            justifyContent = "flex-end",
                            width = "100%",
                            children = {
                                UI.Button {
                                    text = "取消",
                                    onClick = function(s) modal:Close() end,
                                },
                                UI.Button {
                                    text = "添加",
                                    variant = "primary",
                                    onClick = function(s)
                                        if newText ~= "" then
                                            DingtalkData.AddTodo(newText, newPriority)
                                            modal:Close()
                                            refreshPage()
                                        end
                                    end,
                                },
                            },
                        })

                        modal:Open()
                    end,
                },
            },
        }

        -- 滚动内容
        local scrollContent = {}
        -- 统计卡片
        scrollContent[#scrollContent + 1] = UI.Panel {
            width = "100%",
            backgroundColor = C.white,
            paddingVertical = 12,
            paddingHorizontal = 14,
            flexDirection = "row",
            justifyContent = "space-around",
            children = {
                UI.Panel {
                    alignItems = "center", gap = 2,
                    children = {
                        UI.Label { text = tostring(pendingCount), fontSize = 20, fontColor = C.blue },
                        UI.Label { text = "待处理", fontSize = 9, fontColor = C.textSec },
                    },
                },
                UI.Panel {
                    alignItems = "center", gap = 2,
                    children = {
                        UI.Label { text = tostring(doneCount), fontSize = 20, fontColor = C.green },
                        UI.Label { text = "已完成", fontSize = 9, fontColor = C.textSec },
                    },
                },
            },
        }
        scrollContent[#scrollContent + 1] = UI.Panel { width = "100%", height = 8, backgroundColor = C.bg }

        -- 待处理区
        scrollContent[#scrollContent + 1] = UI.Panel {
            width = "100%", height = 34,
            backgroundColor = C.white,
            paddingHorizontal = 14,
            justifyContent = "center",
            children = {
                UI.Label { text = string.format("待处理 (%d)", pendingCount), fontSize = 12, fontColor = C.text },
            },
        }
        if #pendingWidgets > 0 then
            scrollContent[#scrollContent + 1] = UI.Panel {
                width = "100%", backgroundColor = C.white,
                flexDirection = "column",
                children = pendingWidgets,
            }
        else
            scrollContent[#scrollContent + 1] = UI.Panel {
                width = "100%", backgroundColor = C.white,
                paddingVertical = 20, alignItems = "center",
                children = {
                    UI.Label { text = "全部完成，太棒了!", fontSize = 11, fontColor = C.textSec },
                },
            }
        end

        scrollContent[#scrollContent + 1] = UI.Panel { width = "100%", height = 8, backgroundColor = C.bg }

        -- 已完成区
        scrollContent[#scrollContent + 1] = UI.Panel {
            width = "100%", height = 34,
            backgroundColor = C.white,
            paddingHorizontal = 14,
            justifyContent = "center",
            children = {
                UI.Label { text = string.format("已完成 (%d)", doneCount), fontSize = 12, fontColor = C.textSec },
            },
        }
        if #doneWidgets > 0 then
            scrollContent[#scrollContent + 1] = UI.Panel {
                width = "100%", backgroundColor = C.white,
                flexDirection = "column",
                children = doneWidgets,
            }
        else
            scrollContent[#scrollContent + 1] = UI.Panel {
                width = "100%", backgroundColor = C.white,
                paddingVertical = 20, alignItems = "center",
                children = {
                    UI.Label { text = "暂无已完成的待办", fontSize = 11, fontColor = C.textSec },
                },
            }
        end

        pageContainer:AddChild(header)
        pageContainer:AddChild(UI.ScrollView {
            width = "100%",
            flexGrow = 1,
            flexBasis = 0,
            children = {
                UI.Panel {
                    width = "100%",
                    flexDirection = "column",
                    children = scrollContent,
                },
            },
        })
    end

    refreshPage()
    return pageContainer
end

return M
