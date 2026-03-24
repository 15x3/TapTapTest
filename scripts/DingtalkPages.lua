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

return M
