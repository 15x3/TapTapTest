-- ============================================================================
-- 钉钉子页面模块 (DingTalk Sub-Pages Module)
-- 包含：日历、待办、DING、聊天详情
-- ============================================================================

local UI = require("urhox-libs/UI")

local M = {}

-- 通用颜色
local C = {
    blue       = { 48, 118, 255, 255 },
    bg         = { 245, 245, 245, 255 },
    white      = { 255, 255, 255, 255 },
    text       = { 25, 25, 25, 255 },
    textSec    = { 153, 153, 153, 255 },
    border     = { 235, 235, 235, 255 },
    red        = { 250, 80, 80, 255 },
    green      = { 60, 180, 90, 255 },
    orange     = { 255, 160, 50, 255 },
    lightBlue  = { 230, 240, 255, 255 },
}

-- ============================================================================
-- 通用：子页面顶栏
-- ============================================================================
local function CreateSubHeader(title, onBack)
    return UI.Panel {
        width = "100%",
        height = 44,
        backgroundColor = C.white,
        flexDirection = "row",
        alignItems = "center",
        paddingHorizontal = 12,
        borderBottomWidth = 1,
        borderBottomColor = C.border,
        gap = 8,
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
                text = title,
                fontSize = 14,
                fontColor = C.text,
                flexGrow = 1,
                flexBasis = 0,
            },
        },
    }
end

-- ============================================================================
-- 日历页面
-- ============================================================================
function M.CreateCalendarPage(onBack)
    local t = os.date("*t")
    local year = t.year
    local month = t.month
    local today = t.day

    -- 计算本月信息
    local firstWeekday = os.date("*t", os.time({ year = year, month = month, day = 1 })).wday
    local daysInMonth = os.date("*t", os.time({ year = year, month = month + 1, day = 0 })).day

    -- 日程数据
    local events = {
        [today] = { { time = "09:00", title = "班主任例会", color = C.blue } },
        [today + 1] = { { time = "14:00", title = "教研组活动", color = C.green } },
        [today + 3] = { { time = "10:00", title = "月度总结会", color = C.orange } },
    }

    -- 星期标题行
    local weekLabels = { "日", "一", "二", "三", "四", "五", "六" }
    local weekRow = {}
    for _, wl in ipairs(weekLabels) do
        weekRow[#weekRow + 1] = UI.Label {
            text = wl,
            fontSize = 10,
            fontColor = C.textSec,
            width = "14.28%",
            textAlign = "center",
            height = 20,
        }
    end

    -- 日期网格
    local dayWidgets = {}
    -- 空白填充（月初前的空格）
    for i = 1, firstWeekday - 1 do
        dayWidgets[#dayWidgets + 1] = UI.Panel { width = "14.28%", height = 34 }
    end
    -- 日期
    for day = 1, daysInMonth do
        local isToday = (day == today)
        local hasEvent = events[day] ~= nil
        local dayChildren = {
            UI.Label {
                text = tostring(day),
                fontSize = 11,
                fontColor = isToday and C.white or C.text,
                textAlign = "center",
            },
        }
        if hasEvent and not isToday then
            dayChildren[#dayChildren + 1] = UI.Panel {
                width = 4, height = 4,
                backgroundColor = C.blue,
                borderRadius = 2,
                marginTop = 1,
            }
        end
        dayWidgets[#dayWidgets + 1] = UI.Panel {
            width = "14.28%",
            height = 34,
            alignItems = "center",
            justifyContent = "center",
            children = {
                UI.Panel {
                    width = 28, height = 28,
                    borderRadius = 14,
                    backgroundColor = isToday and C.blue or { 0, 0, 0, 0 },
                    justifyContent = "center",
                    alignItems = "center",
                    children = dayChildren,
                },
            },
        }
    end

    -- 当日日程列表
    local todayEvents = events[today] or {}
    local eventItems = {}
    if #todayEvents == 0 then
        eventItems[#eventItems + 1] = UI.Panel {
            width = "100%",
            paddingVertical = 20,
            alignItems = "center",
            children = {
                UI.Label { text = "今日暂无日程", fontSize = 11, fontColor = C.textSec },
            },
        }
    else
        for _, ev in ipairs(todayEvents) do
            eventItems[#eventItems + 1] = UI.Panel {
                width = "100%",
                flexDirection = "row",
                alignItems = "center",
                paddingVertical = 10,
                paddingHorizontal = 14,
                gap = 10,
                borderBottomWidth = 1,
                borderBottomColor = { 245, 245, 245, 255 },
                children = {
                    UI.Panel {
                        width = 3, height = 30,
                        backgroundColor = ev.color,
                        borderRadius = 2,
                    },
                    UI.Panel {
                        flexDirection = "column",
                        gap = 2,
                        children = {
                            UI.Label { text = ev.title, fontSize = 12, fontColor = C.text },
                            UI.Label { text = ev.time, fontSize = 10, fontColor = C.textSec },
                        },
                    },
                },
            }
        end
    end

    return UI.Panel {
        width = "100%",
        height = "100%",
        backgroundColor = C.bg,
        flexDirection = "column",
        children = {
            CreateSubHeader("日历", onBack),
            UI.ScrollView {
                width = "100%",
                flexGrow = 1,
                flexBasis = 0,
                children = {
                    UI.Panel {
                        width = "100%",
                        flexDirection = "column",
                        children = {
                            -- 月份标题
                            UI.Panel {
                                width = "100%",
                                height = 40,
                                backgroundColor = C.white,
                                justifyContent = "center",
                                alignItems = "center",
                                children = {
                                    UI.Label {
                                        text = string.format("%d年%d月", year, month),
                                        fontSize = 13,
                                        fontColor = C.text,
                                    },
                                },
                            },
                            -- 星期标题
                            UI.Panel {
                                width = "100%",
                                backgroundColor = C.white,
                                flexDirection = "row",
                                flexWrap = "wrap",
                                paddingHorizontal = 4,
                                children = weekRow,
                            },
                            -- 日期网格
                            UI.Panel {
                                width = "100%",
                                backgroundColor = C.white,
                                flexDirection = "row",
                                flexWrap = "wrap",
                                paddingHorizontal = 4,
                                paddingBottom = 8,
                                children = dayWidgets,
                            },
                            -- 分隔
                            UI.Panel { width = "100%", height = 8, backgroundColor = C.bg },
                            -- 今日日程标题
                            UI.Panel {
                                width = "100%",
                                height = 36,
                                backgroundColor = C.white,
                                flexDirection = "row",
                                alignItems = "center",
                                paddingHorizontal = 14,
                                children = {
                                    UI.Label {
                                        text = string.format("今日日程 (%d月%d日)", month, today),
                                        fontSize = 12,
                                        fontColor = C.text,
                                    },
                                },
                            },
                            -- 日程列表
                            UI.Panel {
                                width = "100%",
                                backgroundColor = C.white,
                                flexDirection = "column",
                                children = eventItems,
                            },
                        },
                    },
                },
            },
        },
    }
end

-- ============================================================================
-- 待办页面（可交互：切换完成状态、添加新待办）
-- ============================================================================

-- DING 数据（模块级持久化，提前声明供统计函数使用）
local dingData_ = {
    { sender = "教务处-李主任", time = "今天 14:20", content = "请各班主任于今天下班前提交本班学生出勤统计表，谢谢配合。", status = "unread", urgent = true },
    { sender = "校长办公室", time = "今天 11:05", content = "明天上午9:00在会议室召开全体教职工大会，请准时参加。", status = "unread", urgent = true },
    { sender = "年级组长-王老师", time = "今天 09:30", content = "本周五下午第三节课改为年级组教研活动，请提前准备好材料。", status = "read", urgent = false },
    { sender = "人事处", time = "昨天 16:45", content = "教师资格证年审通知，请于本月底前完成线上申报。", status = "read", urgent = false },
    { sender = "后勤部", time = "昨天 10:00", content = "3号教学楼电梯维保通知，3月25日停用一天。", status = "read", urgent = false },
    { sender = "工会-张委员", time = "3月20日", content = "教职工运动会报名截止本周日，请尽快报名。", status = "confirmed", urgent = false },
    { sender = "教务处-李主任", time = "3月18日", content = "期中考试监考安排已发布，请查收。", status = "confirmed", urgent = false },
}

-- 待办数据（模块级持久化，页面刷新后数据保留）
local todoData_ = {
    { text = "提交3月教学总结报告", done = false, priority = "high", due = "今天" },
    { text = "审核学生请假申请 (3份)", done = false, priority = "high", due = "今天" },
    { text = "准备下周班会课件", done = false, priority = "medium", due = "本周五" },
    { text = "更新班级通讯录", done = false, priority = "low", due = "下周一" },
    { text = "填写教师培训意向表", done = true, priority = "medium", due = "已完成" },
    { text = "检查教室多媒体设备", done = true, priority = "low", due = "已完成" },
    { text = "提交2月考勤表", done = true, priority = "high", due = "已完成" },
}

--- 获取待处理待办数量（供主界面小红点使用）
function M.GetPendingTodoCount()
    local count = 0
    for _, todo in ipairs(todoData_) do
        if not todo.done then count = count + 1 end
    end
    return count
end

--- 获取未读 DING 数量（供主界面小红点使用）
function M.GetUnreadDingCount()
    local count = 0
    for _, d in ipairs(dingData_) do
        if d.status == "unread" then count = count + 1 end
    end
    return count
end

---@type fun()|nil
local todoRefreshFn_ = nil

function M.CreateTodoPage(onBack)
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

    -- 外层容器（用于刷新整个页面内容）
    local pageContainer = UI.Panel {
        width = "100%",
        height = "100%",
        backgroundColor = C.bg,
        flexDirection = "column",
    }

    -- 刷新函数：重建页面内容
    local function refreshPage()
        pageContainer:ClearChildren()

        -- 统计
        local pendingCount = 0
        local doneCount = 0
        for _, todo in ipairs(todoData_) do
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
                    -- 切换完成状态
                    todoData_[index].done = not todoData_[index].done
                    if todoData_[index].done then
                        todoData_[index].due = "已完成"
                    end
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
        for i, todo in ipairs(todoData_) do
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
                -- "+" 添加按钮（弹窗让用户输入）
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

                        -- 优先级选择器容器
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
                                            table.insert(todoData_, 1, {
                                                text = newText,
                                                done = false,
                                                priority = newPriority,
                                                due = "今天",
                                            })
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

    todoRefreshFn_ = refreshPage
    refreshPage()
    return pageContainer
end

-- ============================================================================
-- DING 页面（含一键已读功能）
-- ============================================================================

function M.CreateDingPage(onBack)
    local statusLabels = { unread = "未读", read = "已读", confirmed = "已确认" }
    local statusColors = { unread = C.red, read = C.blue, confirmed = C.green }

    local pageContainer = UI.Panel {
        width = "100%",
        height = "100%",
        backgroundColor = C.bg,
        flexDirection = "column",
    }

    local function refreshPage()
        pageContainer:ClearChildren()

        -- 统计未读
        local unreadCount = 0
        for _, d in ipairs(dingData_) do
            if d.status == "unread" then unreadCount = unreadCount + 1 end
        end

        -- 创建 DING 列表项
        local dingItems = {}
        for _, ding in ipairs(dingData_) do
            local sColor = statusColors[ding.status]
            dingItems[#dingItems + 1] = UI.Panel {
                width = "100%",
                backgroundColor = C.white,
                paddingVertical = 12,
                paddingHorizontal = 14,
                flexDirection = "column",
                gap = 6,
                borderBottomWidth = 1,
                borderBottomColor = { 245, 245, 245, 255 },
                children = {
                    -- 发送者行
                    UI.Panel {
                        flexDirection = "row",
                        justifyContent = "space-between",
                        alignItems = "center",
                        children = {
                            UI.Panel {
                                flexDirection = "row",
                                alignItems = "center",
                                gap = 6,
                                flexShrink = 1,
                                children = {
                                    UI.Panel {
                                        width = 20, height = 20,
                                        backgroundColor = ding.urgent and C.red or C.blue,
                                        borderRadius = 4,
                                        justifyContent = "center",
                                        alignItems = "center",
                                        children = {
                                            UI.Label { text = "D", fontSize = 10, fontColor = C.white },
                                        },
                                    },
                                    UI.Label {
                                        text = ding.sender,
                                        fontSize = 12,
                                        fontColor = C.text,
                                        maxLines = 1,
                                        flexShrink = 1,
                                    },
                                },
                            },
                            UI.Label { text = ding.time, fontSize = 9, fontColor = C.textSec },
                        },
                    },
                    -- 内容
                    UI.Label {
                        text = ding.content,
                        fontSize = 11,
                        fontColor = { 60, 60, 60, 255 },
                        maxLines = 2,
                        whiteSpace = "normal",
                    },
                    -- 状态标签
                    UI.Panel {
                        flexDirection = "row",
                        justifyContent = "flex-end",
                        children = {
                            UI.Panel {
                                paddingHorizontal = 8,
                                paddingVertical = 2,
                                backgroundColor = { sColor[1], sColor[2], sColor[3], 20 },
                                borderRadius = 3,
                                children = {
                                    UI.Label { text = statusLabels[ding.status], fontSize = 9, fontColor = sColor },
                                },
                            },
                        },
                    },
                },
            }
        end

        -- 顶栏（含一键已读按钮）
        local headerChildren = {
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
                text = unreadCount > 0 and string.format("DING (%d条未读)", unreadCount) or "DING",
                fontSize = 14,
                fontColor = C.text,
                flexGrow = 1,
                flexBasis = 0,
            },
        }

        -- 只在有未读时显示"一键已读"按钮
        if unreadCount > 0 then
            headerChildren[#headerChildren + 1] = UI.Button {
                height = 26,
                paddingHorizontal = 10,
                backgroundColor = C.blue,
                hoverBackgroundColor = { 38, 100, 230, 255 },
                pressedBackgroundColor = { 28, 80, 200, 255 },
                borderRadius = 13,
                text = "一键已读",
                textColor = C.white,
                fontSize = 10,
                onClick = function(self)
                    for _, d in ipairs(dingData_) do
                        if d.status == "unread" then
                            d.status = "read"
                        end
                    end
                    refreshPage()
                end,
            }
        end

        local header = UI.Panel {
            width = "100%",
            height = 44,
            backgroundColor = C.white,
            flexDirection = "row",
            alignItems = "center",
            paddingHorizontal = 12,
            borderBottomWidth = 1,
            borderBottomColor = C.border,
            gap = 6,
            children = headerChildren,
        }

        pageContainer:AddChild(header)
        pageContainer:AddChild(UI.ScrollView {
            width = "100%",
            flexGrow = 1,
            flexBasis = 0,
            children = {
                UI.Panel {
                    width = "100%",
                    flexDirection = "column",
                    gap = 1,
                    children = dingItems,
                },
            },
        })
    end

    refreshPage()
    return pageContainer
end

-- ============================================================================
-- 聊天详情页面
-- ============================================================================
function M.CreateChatPage(chatName, chatIconBg, onBack)
    -- 根据聊天名称生成不同的模拟对话
    local messages = M.GetChatMessages(chatName)

    local msgWidgets = {}
    for _, msg in ipairs(messages) do
        msgWidgets[#msgWidgets + 1] = CreateChatBubble(msg, chatIconBg)
    end

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
                        onClick = function(self) onBack() end,
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
                    -- 占位，保持标题居中
                    UI.Panel { width = 30, height = 30 },
                },
            },
            -- 消息列表
            UI.ScrollView {
                width = "100%",
                flexGrow = 1,
                flexBasis = 0,
                children = {
                    UI.Panel {
                        width = "100%",
                        flexDirection = "column",
                        paddingVertical = 10,
                        paddingHorizontal = 10,
                        gap = 10,
                        children = msgWidgets,
                    },
                },
            },
            -- 输入框
            UI.Panel {
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
                    UI.Panel {
                        flexGrow = 1, flexBasis = 0,
                        height = 32,
                        backgroundColor = { 245, 245, 245, 255 },
                        borderRadius = 4,
                        justifyContent = "center",
                        paddingHorizontal = 8,
                        children = {
                            UI.Label { text = "输入消息...", fontSize = 11, fontColor = { 180, 180, 180, 255 } },
                        },
                    },
                    UI.Panel {
                        width = 50, height = 30,
                        backgroundColor = C.blue,
                        borderRadius = 4,
                        justifyContent = "center",
                        alignItems = "center",
                        children = {
                            UI.Label { text = "发送", fontSize = 11, fontColor = C.white },
                        },
                    },
                },
            },
        },
    }
end

--- 生成聊天气泡
function CreateChatBubble(msg, chatIconBg)
    local isSelf = msg.sender == "我"
    local bubbleBg = isSelf and { 149, 215, 255, 255 } or C.white
    local alignRow = isSelf and "flex-end" or "flex-start"

    local avatarBg = isSelf and { 100, 160, 220, 255 } or (chatIconBg or { 80, 120, 200, 255 })
    local avatarText = isSelf and "我" or string.sub(msg.sender, 1, 3)  -- utf8 first char(s)

    local avatar = UI.Panel {
        width = 32, height = 32,
        backgroundColor = avatarBg,
        borderRadius = 6,
        justifyContent = "center",
        alignItems = "center",
        children = {
            UI.Label { text = avatarText, fontSize = 9, fontColor = C.white, textAlign = "center" },
        },
    }

    local bubble = UI.Panel {
        maxWidth = "70%",
        backgroundColor = bubbleBg,
        borderRadius = 8,
        paddingHorizontal = 10,
        paddingVertical = 8,
        children = {
            UI.Label {
                text = msg.text,
                fontSize = 11,
                fontColor = C.text,
                whiteSpace = "normal",
            },
        },
    }

    -- 时间标签（偶尔显示）
    local timeWidget = nil
    if msg.showTime then
        timeWidget = UI.Panel {
            width = "100%",
            alignItems = "center",
            marginBottom = 4,
            children = {
                UI.Panel {
                    paddingHorizontal = 8, paddingVertical = 2,
                    backgroundColor = { 200, 200, 200, 100 },
                    borderRadius = 4,
                    children = {
                        UI.Label { text = msg.time or "", fontSize = 9, fontColor = C.textSec },
                    },
                },
            },
        }
    end

    local rowChildren
    if isSelf then
        rowChildren = { bubble, avatar }
    else
        rowChildren = { avatar, bubble }
    end

    local items = {}
    if timeWidget then
        items[#items + 1] = timeWidget
    end
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

--- 根据聊天名称返回模拟对话
function M.GetChatMessages(chatName)
    if chatName:find("通知群") then
        return {
            { sender = "系统", text = "-- 以下是新消息 --", showTime = true, time = "昨天 09:15" },
            { sender = "王丹妮", text = "[@所有人] 各位老师好，学校将于本周五下午2:00在阶梯教室举行教学经验分享会，请大家准时参加。", showTime = false },
            { sender = "李建国", text = "收到，准时参加", showTime = false },
            { sender = "我", text = "好的，收到通知", showTime = true, time = "昨天 10:30" },
            { sender = "王丹妮", text = "[倡议书] 关于节能减排的倡议，请各位老师查看并转发至班级群。", showTime = true, time = "今天 14:46" },
        }
    elseif chatName:find("班主任") then
        return {
            { sender = "邓星妹", text = "通知：学校定于明天上午8:30进行消防演练，请各班主任提前通知学生。", showTime = true, time = "今天 09:24" },
            { sender = "张文华", text = "收到，我通知我们班", showTime = false },
            { sender = "我", text = "好的，马上通知", showTime = false },
            { sender = "邓星妹", text = "另外请各班统计参加演练的学生人数，下午3点前报给我", showTime = false },
        }
    elseif chatName:find("工会") then
        return {
            { sender = "古禹", text = "保利郦城有送一些本周末免费的游泳券，有需要的老师可以找我领取。", showTime = true, time = "3月18日 15:20" },
            { sender = "刘芳", text = "我要两张，谢谢！", showTime = false },
            { sender = "我", text = "还有吗？我也想要", showTime = false },
            { sender = "古禹", text = "还有的，明天来办公室拿就行", showTime = false },
        }
    else
        return {
            { sender = "对方", text = "你好！", showTime = true, time = "今天 10:00" },
            { sender = "我", text = "你好，有什么事吗？", showTime = false },
            { sender = "对方", text = "想问一下关于明天活动的安排", showTime = false },
            { sender = "我", text = "好的，我看一下安排表回复你", showTime = false },
            { sender = "对方", text = "谢谢！不急", showTime = false },
        }
    end
end

-- ============================================================================
-- 通讯录页面
-- ============================================================================

-- 每个分类下的虚构人员数据
local contactsData_ = {
    ["组织架构"] = {
        { name = "杨清", role = "信息技术系-教师", initial = "杨" },
        { name = "王丹妮", role = "教务处-副主任", initial = "王" },
        { name = "李建国", role = "校长", initial = "李" },
        { name = "张美华", role = "财务处-会计", initial = "张" },
        { name = "陈志强", role = "总务处-主任", initial = "陈" },
        { name = "林小红", role = "办公室-秘书", initial = "林" },
    },
    ["教职工-信息技术系"] = {
        { name = "杨清", role = "计算机应用-讲师", initial = "杨" },
        { name = "黄伟明", role = "网络工程-副教授", initial = "黄" },
        { name = "吴丽珍", role = "软件技术-讲师", initial = "吴" },
        { name = "郑晓峰", role = "物联网-实验员", initial = "郑" },
        { name = "周雅琴", role = "数字媒体-讲师", initial = "周" },
    },
    ["职工之家-工会-家长"] = {
        { name = "古禹", role = "工会主席", initial = "古" },
        { name = "邓星妹", role = "工会委员", initial = "邓" },
        { name = "蔡明辉", role = "工会委员", initial = "蔡" },
        { name = "刘秀英", role = "家委会代表", initial = "刘" },
    },
    ["三年级2023级-2...控与维护-老师"] = {
        { name = "赵国栋", role = "班主任", initial = "赵" },
        { name = "孙丽华", role = "专业课教师", initial = "孙" },
        { name = "钱伟", role = "实训指导", initial = "钱" },
    },
    ["二年级2024级-...技术应用)-老师"] = {
        { name = "杨清", role = "班主任", initial = "杨" },
        { name = "许志豪", role = "专业课教师", initial = "许" },
        { name = "何婷婷", role = "辅导员", initial = "何" },
        { name = "陈大伟", role = "实训指导", initial = "陈" },
    },
    ["管理员助理"] = {
        { name = "系统助理", role = "智能管理工具", initial = "管" },
    },
    ["AI助理"] = {
        { name = "AI 助理", role = "智能问答服务", initial = "AI" },
    },
    ["集团上下级"] = {
        { name = "泉州教育集团", role = "上级单位", initial = "泉" },
        { name = "石狮职教中心", role = "平级单位", initial = "石" },
        { name = "晋江工贸学校", role = "平级单位", initial = "晋" },
    },
    ["产业上下游"] = {
        { name = "福建信息产业协会", role = "行业合作", initial = "信" },
        { name = "泉州软件园", role = "实习基地", initial = "泉" },
        { name = "石狮服装城", role = "校企合作", initial = "石" },
        { name = "鹏山科技有限公司", role = "合作企业", initial = "鹏" },
    },
}

--- 创建通讯录子页面：人员列表（深色主题）
function M.CreateContactDetailPage(title, onBack)
    local people = contactsData_[title] or {}

    -- 构建人员列表
    local personItems = {}
    for i, person in ipairs(people) do
        -- 随机但确定的头像颜色（基于名字）
        local colorSeed = string.byte(person.initial, 1) or 65
        local avatarColors = {
            { 80, 130, 220, 255 },
            { 200, 90, 90, 255 },
            { 60, 170, 100, 255 },
            { 180, 120, 60, 255 },
            { 140, 80, 200, 255 },
            { 60, 170, 180, 255 },
            { 200, 80, 160, 255 },
        }
        local avatarBg = avatarColors[(colorSeed % #avatarColors) + 1]

        personItems[#personItems + 1] = UI.Panel {
            width = "100%",
            paddingVertical = 12,
            paddingHorizontal = 16,
            flexDirection = "row",
            alignItems = "center",
            gap = 12,
            borderBottomWidth = (i < #people) and 1 or 0,
            borderBottomColor = { 50, 50, 60, 255 },
            children = {
                -- 头像
                UI.Panel {
                    width = 40, height = 40,
                    backgroundColor = avatarBg,
                    borderRadius = 20,
                    justifyContent = "center",
                    alignItems = "center",
                    children = {
                        UI.Label { text = person.initial, fontSize = 15, fontColor = { 255, 255, 255, 255 } },
                    },
                },
                -- 名字 + 角色
                UI.Panel {
                    flexGrow = 1, flexShrink = 1,
                    flexDirection = "column",
                    gap = 3,
                    children = {
                        UI.Label { text = person.name, fontSize = 14, fontColor = { 235, 235, 240, 255 } },
                        UI.Label { text = person.role, fontSize = 11, fontColor = { 120, 120, 135, 255 }, maxLines = 1 },
                    },
                },
            },
        }
    end

    -- 空列表提示
    if #personItems == 0 then
        personItems[1] = UI.Panel {
            width = "100%",
            paddingVertical = 40,
            justifyContent = "center",
            alignItems = "center",
            children = {
                UI.Label { text = "暂无成员", fontSize = 13, fontColor = { 100, 100, 110, 255 } },
            },
        }
    end

    return UI.Panel {
        width = "100%",
        height = "100%",
        backgroundColor = { 22, 22, 30, 255 },
        flexDirection = "column",
        children = {
            -- 顶栏
            UI.Panel {
                width = "100%",
                height = 48,
                backgroundColor = { 30, 30, 40, 255 },
                flexDirection = "row",
                alignItems = "center",
                paddingHorizontal = 6,
                borderBottomWidth = 1,
                borderBottomColor = { 50, 50, 60, 255 },
                children = {
                    UI.Button {
                        width = 36, height = 36,
                        backgroundColor = { 0, 0, 0, 0 },
                        hoverBackgroundColor = { 255, 255, 255, 15 },
                        pressedBackgroundColor = { 255, 255, 255, 30 },
                        borderRadius = 4,
                        text = "<",
                        textColor = { 100, 150, 255, 255 },
                        fontSize = 16,
                        onClick = function(self) onBack() end,
                    },
                    UI.Label {
                        text = title,
                        fontSize = 14,
                        fontColor = { 235, 235, 240, 255 },
                        flexGrow = 1,
                        textAlign = "center",
                        marginRight = 36,
                        maxLines = 1,
                    },
                },
            },
            -- 成员数量统计
            UI.Panel {
                width = "100%",
                paddingHorizontal = 16,
                paddingVertical = 10,
                children = {
                    UI.Label {
                        text = "共 " .. #people .. " 人",
                        fontSize = 12,
                        fontColor = { 120, 120, 135, 255 },
                    },
                },
            },
            -- 人员列表
            UI.ScrollView {
                width = "100%",
                flexGrow = 1, flexBasis = 0,
                children = {
                    UI.Panel {
                        width = "100%",
                        flexDirection = "column",
                        paddingBottom = 20,
                        children = personItems,
                    },
                },
            },
        },
    }
end

--- 创建通讯录主页面（底部 Tab 切换，非子页面）
---@param onNavigate fun(title: string) 点击子项时的导航回调
function M.CreateContactsPage(onNavigate)
    -- 组织架构子项
    local orgItems = {
        "组织架构",
        "教职工-信息技术系",
        "职工之家-工会-家长",
        "三年级2023级-2...控与维护-老师",
        "二年级2024级-...技术应用)-老师",
    }

    -- 构建组织架构列表（可点击）
    local orgChildren = {}
    for i, name in ipairs(orgItems) do
        orgChildren[#orgChildren + 1] = UI.Button {
            width = "100%",
            height = 50,
            backgroundColor = { 0, 0, 0, 0 },
            hoverBackgroundColor = { 255, 255, 255, 8 },
            pressedBackgroundColor = { 255, 255, 255, 15 },
            borderRadius = 0,
            flexDirection = "row",
            alignItems = "center",
            paddingLeft = 32,
            paddingRight = 12,
            borderBottomWidth = (i < #orgItems) and 1 or 0,
            borderBottomColor = { 60, 60, 70, 255 },
            onClick = function(self) onNavigate(name) end,
            children = {
                UI.Label {
                    text = "└",
                    fontSize = 14,
                    fontColor = { 100, 100, 110, 255 },
                    marginRight = 12,
                    pointerEvents = "none",
                },
                UI.Label {
                    text = name,
                    fontSize = 13,
                    fontColor = { 230, 230, 235, 255 },
                    flexShrink = 1,
                    maxLines = 1,
                    flexGrow = 1,
                    pointerEvents = "none",
                },
                UI.Label {
                    text = ">",
                    fontSize = 13,
                    fontColor = { 80, 80, 90, 255 },
                    pointerEvents = "none",
                },
            },
        }
    end

    -- 功能入口项（管理员助理、AI助理）— 可点击
    local function CreateFeatureItem(iconText, iconBg, label)
        return UI.Button {
            width = "100%",
            height = 56,
            backgroundColor = { 0, 0, 0, 0 },
            hoverBackgroundColor = { 255, 255, 255, 8 },
            pressedBackgroundColor = { 255, 255, 255, 15 },
            borderRadius = 0,
            flexDirection = "row",
            alignItems = "center",
            paddingHorizontal = 16,
            gap = 12,
            onClick = function(self) onNavigate(label) end,
            children = {
                UI.Panel {
                    width = 40, height = 40,
                    backgroundColor = iconBg,
                    borderRadius = 10,
                    justifyContent = "center",
                    alignItems = "center",
                    pointerEvents = "none",
                    children = {
                        UI.Label { text = iconText, fontSize = 14, fontColor = { 255, 255, 255, 255 } },
                    },
                },
                UI.Label {
                    text = label,
                    fontSize = 14,
                    fontColor = { 230, 230, 235, 255 },
                    flexGrow = 1,
                    pointerEvents = "none",
                },
                UI.Label {
                    text = ">",
                    fontSize = 13,
                    fontColor = { 80, 80, 90, 255 },
                    pointerEvents = "none",
                },
            },
        }
    end

    -- 外部组织项（集团上下级、产业上下游）— 可点击
    local function CreateExternalOrgItem(iconText, iconBg, label, subtitle)
        local innerChildren = {
            UI.Label {
                text = label,
                fontSize = 14,
                fontColor = { 230, 230, 235, 255 },
                flexGrow = 1,
                pointerEvents = "none",
            },
        }
        if subtitle then
            innerChildren[#innerChildren + 1] = UI.Label {
                text = subtitle,
                fontSize = 11,
                fontColor = { 120, 120, 130, 255 },
                marginRight = 4,
                pointerEvents = "none",
            }
        end
        innerChildren[#innerChildren + 1] = UI.Label {
            text = ">",
            fontSize = 14,
            fontColor = { 100, 100, 110, 255 },
            pointerEvents = "none",
        }

        return UI.Button {
            width = "100%",
            height = 56,
            backgroundColor = { 0, 0, 0, 0 },
            hoverBackgroundColor = { 255, 255, 255, 8 },
            pressedBackgroundColor = { 255, 255, 255, 15 },
            borderRadius = 0,
            flexDirection = "row",
            alignItems = "center",
            paddingHorizontal = 16,
            gap = 12,
            onClick = function(self) onNavigate(label) end,
            children = {
                UI.Panel {
                    width = 40, height = 40,
                    backgroundColor = iconBg,
                    borderRadius = 10,
                    justifyContent = "center",
                    alignItems = "center",
                    pointerEvents = "none",
                    children = {
                        UI.Label { text = iconText, fontSize = 16, fontColor = { 255, 255, 255, 255 } },
                    },
                },
                UI.Panel {
                    flexGrow = 1,
                    flexDirection = "row",
                    alignItems = "center",
                    justifyContent = "space-between",
                    pointerEvents = "none",
                    children = innerChildren,
                },
            },
        }
    end

    -- 整体页面（深色主题）
    return UI.Panel {
        width = "100%",
        height = "100%",
        backgroundColor = { 22, 22, 30, 255 },
        flexDirection = "column",
        children = {
            -- 顶部区域：用户信息 + 添加按钮
            UI.Panel {
                width = "100%",
                paddingHorizontal = 12,
                paddingTop = 10,
                paddingBottom = 10,
                flexDirection = "row",
                alignItems = "center",
                gap = 10,
                children = {
                    -- 头像
                    UI.Panel {
                        width = 44, height = 44,
                        backgroundColor = { 60, 60, 80, 255 },
                        borderRadius = 8,
                        justifyContent = "center",
                        alignItems = "center",
                        children = {
                            UI.Label { text = "杨", fontSize = 16, fontColor = { 200, 200, 220, 255 } },
                        },
                    },
                    -- 名称 + 单位
                    UI.Panel {
                        flexDirection = "column",
                        gap = 2,
                        flexGrow = 1,
                        flexShrink = 1,
                        children = {
                            UI.Label { text = "杨清", fontSize = 15, fontColor = { 240, 240, 245, 255 }, fontWeight = "bold" },
                            UI.Label { text = "福建省石狮鹏山工贸学校", fontSize = 10, fontColor = { 140, 140, 150, 255 }, maxLines = 1 },
                        },
                    },
                    -- 添加联系人
                    UI.Panel {
                        width = 28, height = 28,
                        justifyContent = "center",
                        alignItems = "center",
                        children = {
                            UI.Label { text = "+", fontSize = 20, fontColor = { 180, 180, 190, 255 } },
                        },
                    },
                },
            },

            -- 可滚动内容区
            UI.ScrollView {
                width = "100%",
                flexGrow = 1, flexBasis = 0,
                children = {
                    UI.Panel {
                        width = "100%",
                        flexDirection = "column",
                        paddingBottom = 20,
                        children = {
                            -- 学校组织卡片
                            UI.Panel {
                                width = "100%",
                                marginTop = 8,
                                marginHorizontal = 0,
                                backgroundColor = { 35, 35, 45, 255 },
                                borderRadius = 12,
                                marginBottom = 8,
                                paddingBottom = 4,
                                overflow = "hidden",
                                flexDirection = "column",
                                children = {
                                    -- 卡片头部：学校名 + 管理按钮
                                    UI.Panel {
                                        width = "100%",
                                        paddingHorizontal = 16,
                                        paddingVertical = 14,
                                        flexDirection = "row",
                                        alignItems = "center",
                                        gap = 10,
                                        children = {
                                            -- 学校 logo 占位
                                            UI.Panel {
                                                width = 44, height = 44,
                                                backgroundColor = { 50, 50, 65, 255 },
                                                borderRadius = 22,
                                                borderWidth = 1,
                                                borderColor = { 80, 80, 100, 255 },
                                                justifyContent = "center",
                                                alignItems = "center",
                                                children = {
                                                    UI.Label { text = "工贸", fontSize = 12, fontColor = { 150, 150, 170, 255 } },
                                                },
                                            },
                                            -- 名称 + 标签
                                            UI.Panel {
                                                flexGrow = 1, flexShrink = 1,
                                                flexDirection = "column",
                                                gap = 4,
                                                children = {
                                                    UI.Label {
                                                        text = "福建省石狮鹏山工贸学校",
                                                        fontSize = 14,
                                                        fontColor = { 240, 240, 245, 255 },
                                                        fontWeight = "bold",
                                                        maxLines = 1,
                                                    },
                                                    -- 标签行
                                                    UI.Panel {
                                                        flexDirection = "row",
                                                        gap = 6,
                                                        children = {
                                                            UI.Panel {
                                                                paddingHorizontal = 6, paddingVertical = 2,
                                                                backgroundColor = { 30, 80, 50, 255 },
                                                                borderRadius = 3,
                                                                flexDirection = "row",
                                                                alignItems = "center",
                                                                gap = 3,
                                                                children = {
                                                                    UI.Label { text = "V", fontSize = 8, fontColor = { 80, 200, 120, 255 } },
                                                                    UI.Label { text = "年检认证", fontSize = 9, fontColor = { 80, 200, 120, 255 } },
                                                                },
                                                            },
                                                            UI.Panel {
                                                                paddingHorizontal = 6, paddingVertical = 2,
                                                                backgroundColor = { 40, 40, 60, 255 },
                                                                borderRadius = 3,
                                                                flexDirection = "row",
                                                                alignItems = "center",
                                                                gap = 3,
                                                                children = {
                                                                    UI.Label { text = "P", fontSize = 8, fontColor = { 100, 140, 255, 255 } },
                                                                    UI.Label { text = "专业版", fontSize = 9, fontColor = { 140, 140, 160, 255 } },
                                                                },
                                                            },
                                                        },
                                                    },
                                                },
                                            },
                                            -- 管理按钮
                                            UI.Panel {
                                                paddingHorizontal = 14,
                                                paddingVertical = 6,
                                                backgroundColor = { 50, 50, 65, 255 },
                                                borderRadius = 14,
                                                borderWidth = 1,
                                                borderColor = { 80, 80, 100, 255 },
                                                children = {
                                                    UI.Label { text = "管理", fontSize = 11, fontColor = { 100, 150, 255, 255 } },
                                                },
                                            },
                                        },
                                    },
                                    -- 组织架构列表
                                    UI.Panel {
                                        width = "100%",
                                        flexDirection = "column",
                                        children = orgChildren,
                                    },
                                    -- 管理员助理 & AI 助理
                                    CreateFeatureItem("管", { 120, 80, 200, 255 }, "管理员助理"),
                                    CreateFeatureItem("AI", { 50, 120, 220, 255 }, "AI助理"),
                                },
                            },

                            -- 外部组织卡片
                            UI.Panel {
                                width = "100%",
                                backgroundColor = { 35, 35, 45, 255 },
                                borderRadius = 12,
                                paddingVertical = 4,
                                flexDirection = "column",
                                overflow = "hidden",
                                children = {
                                    CreateExternalOrgItem("OO", { 230, 120, 30, 255 }, "集团上下级", "组织多单位管理"),
                                    UI.Panel { width = "100%", height = 1, backgroundColor = { 50, 50, 60, 255 }, marginHorizontal = 16 },
                                    CreateExternalOrgItem("G", { 50, 160, 120, 255 }, "产业上下游", nil),
                                },
                            },
                        },
                    },
                },
            },
        },
    }
end

-- ============================================================================
-- 全局搜索接口
-- ============================================================================

--- 搜索所有数据，返回分类结果
---@param keyword string 搜索关键词
---@param chatList table 主页聊天列表（由 main.lua 传入）
---@return table { contacts, chats, todos, dings, calendar }
function M.SearchAll(keyword, chatList)
    if not keyword or keyword == "" then return nil end
    local kw = string.lower(keyword)

    local function match(text)
        if not text then return false end
        return string.find(string.lower(text), kw, 1, true) ~= nil
    end

    local results = { contacts = {}, chats = {}, todos = {}, dings = {}, calendar = {} }
    local seenContact = {}  -- 去重

    -- 1. 联系人
    for group, people in pairs(contactsData_) do
        for _, p in ipairs(people) do
            if match(p.name) or match(p.role) or match(group) then
                local key = p.name .. "|" .. (p.role or "")
                if not seenContact[key] then
                    seenContact[key] = true
                    results.contacts[#results.contacts + 1] = {
                        name = p.name, role = p.role, initial = p.initial, group = group,
                    }
                end
            end
        end
    end

    -- 2. 群聊 / 会话
    for _, chat in ipairs(chatList or {}) do
        if match(chat.name) or match(chat.msg) or match(chat.tag) then
            results.chats[#results.chats + 1] = chat
        end
    end

    -- 3. 待办
    for _, todo in ipairs(todoData_) do
        if match(todo.text) or match(todo.due) then
            results.todos[#results.todos + 1] = todo
        end
    end

    -- 4. DING
    for _, d in ipairs(dingData_) do
        if match(d.sender) or match(d.content) then
            results.dings[#results.dings + 1] = d
        end
    end

    -- 5. 日历日程
    local calEvents = {
        { title = "班主任例会", time = "09:00", desc = "今日日程" },
        { title = "教研组活动", time = "14:00", desc = "明日日程" },
        { title = "月度总结会", time = "10:00", desc = "3日后" },
    }
    for _, ev in ipairs(calEvents) do
        if match(ev.title) then
            results.calendar[#results.calendar + 1] = ev
        end
    end

    return results
end

-- ============================================================================
-- 搜索页面
-- ============================================================================

--- 创建搜索页面（浅色主题，带实时搜索）
---@param onBack fun() 返回回调
---@param chatList table 主页聊天列表数据
function M.CreateSearchPage(onBack, chatList, onNavigate)
    local resultContainer = UI.Panel {
        width = "100%",
        flexDirection = "column",
        paddingBottom = 20,
    }

    -- 搜索状态文字
    local hintPanel = UI.Panel {
        width = "100%",
        paddingVertical = 60,
        alignItems = "center",
        justifyContent = "center",
        children = {
            UI.Label { text = "输入关键词搜索", fontSize = 12, fontColor = C.textSec },
        },
    }
    resultContainer:AddChild(hintPanel)

    local function doSearch(keyword)
        resultContainer:ClearChildren()
        if not keyword or keyword == "" then
            resultContainer:AddChild(UI.Panel {
                width = "100%", paddingVertical = 60, alignItems = "center",
                children = {
                    UI.Label { text = "输入关键词搜索", fontSize = 12, fontColor = C.textSec },
                },
            })
            return
        end

        local r = M.SearchAll(keyword, chatList)
        if not r then return end

        local totalCount = #r.contacts + #r.chats + #r.todos + #r.dings + #r.calendar
        if totalCount == 0 then
            resultContainer:AddChild(UI.Panel {
                width = "100%", paddingVertical = 60, alignItems = "center",
                children = {
                    UI.Label { text = "未找到\"" .. keyword .. "\"相关结果", fontSize = 12, fontColor = C.textSec },
                },
            })
            return
        end

        -- 分类标题
        local function SectionTitle(title, count)
            return UI.Panel {
                width = "100%",
                paddingHorizontal = 14,
                paddingTop = 14,
                paddingBottom = 6,
                backgroundColor = C.bg,
                children = {
                    UI.Label {
                        text = title .. " (" .. count .. ")",
                        fontSize = 12,
                        fontColor = C.blue,
                        fontWeight = "bold",
                    },
                },
            }
        end

        -- 结果行（可点击）
        local function ResultRow(icon, iconBg, line1, line2, onClick)
            return UI.Button {
                width = "100%",
                height = 56,
                paddingHorizontal = 14,
                flexDirection = "row",
                alignItems = "center",
                gap = 10,
                backgroundColor = C.white,
                hoverBackgroundColor = { 245, 245, 250, 255 },
                pressedBackgroundColor = { 235, 235, 240, 255 },
                borderRadius = 0,
                borderBottomWidth = 1,
                borderBottomColor = { 245, 245, 245, 255 },
                onClick = function(self)
                    if onClick and onNavigate then onClick() end
                end,
                children = {
                    UI.Panel {
                        width = 36, height = 36,
                        backgroundColor = iconBg,
                        borderRadius = 18,
                        justifyContent = "center",
                        alignItems = "center",
                        pointerEvents = "none",
                        children = {
                            UI.Label { text = icon, fontSize = 12, fontColor = { 255, 255, 255, 255 } },
                        },
                    },
                    UI.Panel {
                        flexGrow = 1, flexShrink = 1,
                        flexDirection = "column",
                        gap = 2,
                        pointerEvents = "none",
                        children = {
                            UI.Label { text = line1, fontSize = 13, fontColor = C.text, maxLines = 1 },
                            UI.Label { text = line2, fontSize = 10, fontColor = C.textSec, maxLines = 1 },
                        },
                    },
                    -- 右箭头
                    UI.Label { text = ">", fontSize = 12, fontColor = C.textSec, pointerEvents = "none" },
                },
            }
        end

        -- 联系人 → 点击打开联系人详情（跳转到该联系人所在分组）
        if #r.contacts > 0 then
            resultContainer:AddChild(SectionTitle("联系人", #r.contacts))
            for _, c in ipairs(r.contacts) do
                local contactGroup = c.group
                resultContainer:AddChild(ResultRow(c.initial, { 80, 130, 220, 255 }, c.name, c.role .. " · " .. c.group,
                    function() onNavigate("contact", { group = contactGroup }) end))
            end
        end

        -- 群聊 → 点击打开聊天详情
        if #r.chats > 0 then
            resultContainer:AddChild(SectionTitle("群聊 / 会话", #r.chats))
            for _, ch in ipairs(r.chats) do
                local chatData = ch
                resultContainer:AddChild(ResultRow(ch.iconText or "群", ch.iconBg or C.blue, ch.name, ch.msg or "",
                    function() onNavigate("chat", chatData) end))
            end
        end

        -- 待办 → 点击打开待办页面
        if #r.todos > 0 then
            resultContainer:AddChild(SectionTitle("待办事项", #r.todos))
            for _, td in ipairs(r.todos) do
                local status = td.done and "已完成" or "待处理"
                local pLabel = ({ high = "紧急", medium = "普通", low = "较低" })[td.priority] or ""
                resultContainer:AddChild(ResultRow(td.done and "V" or "O",
                    td.done and C.green or C.orange,
                    td.text,
                    status .. " · " .. pLabel .. " · " .. (td.due or ""),
                    function() onNavigate("todo") end))
            end
        end

        -- DING → 点击打开DING页面
        if #r.dings > 0 then
            resultContainer:AddChild(SectionTitle("DING 消息", #r.dings))
            for _, d in ipairs(r.dings) do
                local ic = d.urgent and "!" or "D"
                local bg = d.urgent and C.red or C.blue
                resultContainer:AddChild(ResultRow(ic, bg, d.sender .. " · " .. d.time, d.content,
                    function() onNavigate("ding") end))
            end
        end

        -- 日历日程 → 点击打开日历页面
        if #r.calendar > 0 then
            resultContainer:AddChild(SectionTitle("日程", #r.calendar))
            for _, ev in ipairs(r.calendar) do
                resultContainer:AddChild(ResultRow("日", { 60, 160, 120, 255 }, ev.title, ev.time .. " · " .. ev.desc,
                    function() onNavigate("calendar") end))
            end
        end
    end

    return UI.Panel {
        width = "100%",
        height = "100%",
        backgroundColor = C.bg,
        flexDirection = "column",
        children = {
            -- 搜索顶栏
            UI.Panel {
                width = "100%",
                height = 48,
                backgroundColor = C.white,
                flexDirection = "row",
                alignItems = "center",
                paddingHorizontal = 8,
                gap = 6,
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
                    UI.Panel {
                        flexGrow = 1, flexBasis = 0,
                        height = 32,
                        backgroundColor = { 242, 242, 242, 255 },
                        borderRadius = 16,
                        flexDirection = "row",
                        alignItems = "center",
                        paddingHorizontal = 4,
                        children = {
                            UI.TextField {
                                placeholder = "搜索联系人、群聊、待办...",
                                flexGrow = 1,
                                onChange = function(self, v)
                                    doSearch(v)
                                end,
                            },
                        },
                    },
                },
            },
            -- 结果区
            UI.ScrollView {
                width = "100%",
                flexGrow = 1, flexBasis = 0,
                children = { resultContainer },
            },
        },
    }
end

-- ============================================================================
-- "更多"页面 & 关于
-- ============================================================================

function M.CreateMorePage()
    -- 菜单项构建器
    local function MenuItem(iconText, iconBg, label, onClick)
        return UI.Button {
            width = "100%",
            height = 52,
            backgroundColor = C.white,
            hoverBackgroundColor = { 248, 248, 248, 255 },
            pressedBackgroundColor = { 240, 240, 240, 255 },
            borderRadius = 0,
            flexDirection = "row",
            alignItems = "center",
            paddingHorizontal = 14,
            gap = 12,
            borderBottomWidth = 1,
            borderBottomColor = { 245, 245, 245, 255 },
            onClick = function(self)
                if onClick then onClick() end
            end,
            children = {
                UI.Panel {
                    width = 34, height = 34,
                    backgroundColor = iconBg,
                    borderRadius = 8,
                    justifyContent = "center",
                    alignItems = "center",
                    pointerEvents = "none",
                    children = {
                        UI.Label { text = iconText, fontSize = 13, fontColor = { 255, 255, 255, 255 } },
                    },
                },
                UI.Label {
                    text = label,
                    fontSize = 13,
                    fontColor = C.text,
                    flexGrow = 1,
                    pointerEvents = "none",
                },
                UI.Label {
                    text = ">",
                    fontSize = 13,
                    fontColor = C.textSec,
                    pointerEvents = "none",
                },
            },
        }
    end

    -- 内容容器（用于切换到关于子页面）
    local moreContainer = UI.Panel {
        width = "100%",
        height = "100%",
        flexDirection = "column",
    }

    local function showAbout()
        moreContainer:ClearChildren()
        moreContainer:AddChild(M.CreateAboutPage(function()
            moreContainer:ClearChildren()
            moreContainer:AddChild(buildMainMenu())
        end))
    end

    function buildMainMenu()
        return UI.Panel {
            width = "100%",
            height = "100%",
            backgroundColor = C.bg,
            flexDirection = "column",
            children = {
                -- 顶栏
                UI.Panel {
                    width = "100%",
                    height = 44,
                    backgroundColor = C.white,
                    justifyContent = "center",
                    alignItems = "center",
                    borderBottomWidth = 1,
                    borderBottomColor = C.border,
                    children = {
                        UI.Label { text = "更多", fontSize = 15, fontColor = C.text },
                    },
                },
                -- 菜单列表
                UI.ScrollView {
                    width = "100%",
                    flexGrow = 1, flexBasis = 0,
                    children = {
                        UI.Panel {
                            width = "100%",
                            flexDirection = "column",
                            paddingTop = 10,
                            gap = 10,
                            children = {
                                -- 第一组
                                UI.Panel {
                                    width = "100%",
                                    flexDirection = "column",
                                    backgroundColor = C.white,
                                    borderRadius = 0,
                                    children = {
                                        MenuItem("钱", { 255, 140, 0, 255 }, "钱包"),
                                        MenuItem("扫", C.blue, "扫一扫"),
                                        MenuItem("卡", { 60, 180, 100, 255 }, "名片"),
                                    },
                                },
                                -- 第二组
                                UI.Panel {
                                    width = "100%",
                                    flexDirection = "column",
                                    backgroundColor = C.white,
                                    children = {
                                        MenuItem("设", { 100, 100, 120, 255 }, "设置"),
                                        MenuItem("帮", { 80, 150, 220, 255 }, "帮助与反馈"),
                                    },
                                },
                                -- 第三组
                                UI.Panel {
                                    width = "100%",
                                    flexDirection = "column",
                                    backgroundColor = C.white,
                                    children = {
                                        MenuItem("i", { 48, 118, 255, 255 }, "关于", showAbout),
                                    },
                                },
                            },
                        },
                    },
                },
            },
        }
    end

    moreContainer:AddChild(buildMainMenu())
    return moreContainer
end

--- 关于页面
function M.CreateAboutPage(onBack)
    local function InfoRow(label, value)
        return UI.Panel {
            width = "100%",
            paddingVertical = 10,
            paddingHorizontal = 20,
            flexDirection = "row",
            justifyContent = "space-between",
            alignItems = "center",
            borderBottomWidth = 1,
            borderBottomColor = { 245, 245, 245, 255 },
            children = {
                UI.Label { text = label, fontSize = 12, fontColor = C.textSec },
                UI.Label { text = value, fontSize = 12, fontColor = C.text },
            },
        }
    end

    return UI.Panel {
        width = "100%",
        height = "100%",
        backgroundColor = C.bg,
        flexDirection = "column",
        children = {
            -- 顶栏
            UI.Panel {
                width = "100%",
                height = 44,
                backgroundColor = C.white,
                flexDirection = "row",
                alignItems = "center",
                paddingHorizontal = 8,
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
                        text = "关于",
                        fontSize = 15,
                        fontColor = C.text,
                        flexGrow = 1,
                        textAlign = "center",
                        marginRight = 30,
                    },
                },
            },

            -- 内容
            UI.ScrollView {
                width = "100%",
                flexGrow = 1, flexBasis = 0,
                children = {
                    UI.Panel {
                        width = "100%",
                        flexDirection = "column",
                        alignItems = "center",
                        paddingBottom = 40,
                        children = {
                            -- Logo 区域
                            UI.Panel {
                                width = "100%",
                                paddingVertical = 30,
                                alignItems = "center",
                                gap = 10,
                                children = {
                                    UI.Panel {
                                        width = 72, height = 72,
                                        backgroundColor = C.blue,
                                        borderRadius = 18,
                                        justifyContent = "center",
                                        alignItems = "center",
                                        children = {
                                            UI.Label { text = "钉", fontSize = 28, fontColor = C.white },
                                        },
                                    },
                                    UI.Label { text = "钉钉", fontSize = 18, fontColor = C.text, fontWeight = "bold" },
                                    UI.Label { text = "让工作学习更简单", fontSize = 11, fontColor = C.textSec },
                                },
                            },

                            -- 信息卡片
                            UI.Panel {
                                width = "100%",
                                backgroundColor = C.white,
                                flexDirection = "column",
                                children = {
                                    InfoRow("版本号", "v7.6.20 (像素版)"),
                                    InfoRow("构建日期", "2025-03-24"),
                                    InfoRow("引擎", "UrhoX Engine"),
                                    InfoRow("开发者", "杨清 · 信息技术系"),
                                    InfoRow("学校", "福建省石狮鹏山工贸学校"),
                                },
                            },

                            -- 分隔
                            UI.Panel { width = "100%", height = 10 },

                            -- 更新日志卡片
                            UI.Panel {
                                width = "100%",
                                backgroundColor = C.white,
                                flexDirection = "column",
                                paddingVertical = 14,
                                paddingHorizontal = 20,
                                gap = 8,
                                children = {
                                    UI.Label { text = "更新日志", fontSize = 13, fontColor = C.text, fontWeight = "bold" },
                                    UI.Label {
                                        text = "· 新增通讯录页面，支持查看组织架构\n· 新增全局搜索功能\n· 待办支持自定义添加、完成切换\n· DING 支持一键已读\n· 新增\"关于\"页面",
                                        fontSize = 11,
                                        fontColor = C.textSec,
                                        lineHeight = 1.6,
                                    },
                                },
                            },

                            -- 分隔
                            UI.Panel { width = "100%", height = 10 },

                            -- 致谢
                            UI.Panel {
                                width = "100%",
                                backgroundColor = C.white,
                                flexDirection = "column",
                                paddingVertical = 14,
                                paddingHorizontal = 20,
                                gap = 8,
                                children = {
                                    UI.Label { text = "致谢", fontSize = 13, fontColor = C.text, fontWeight = "bold" },
                                    UI.Label {
                                        text = "感谢 UrhoX 引擎团队提供的强大开发框架。\n本应用为像素风格教学演示项目，\n界面仅供学习参考，非官方钉钉产品。",
                                        fontSize = 11,
                                        fontColor = C.textSec,
                                        lineHeight = 1.6,
                                    },
                                },
                            },

                            -- 底部版权
                            UI.Panel {
                                width = "100%",
                                paddingVertical = 20,
                                alignItems = "center",
                                children = {
                                    UI.Label {
                                        text = "Made with UrhoX  2025",
                                        fontSize = 10,
                                        fontColor = { 180, 180, 185, 255 },
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
