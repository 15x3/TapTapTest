-- ============================================================================
-- 叮叮日历页面 (Calendar Page)
-- ============================================================================

local UI = require("urhox-libs/UI")
local DingtalkData = require("DingtalkData")
local Common = require("DingtalkPagesCommon")
local GameTime = require("Utils.GameTime")
local C = Common.C
local CreateSubHeader = Common.CreateSubHeader

local M = {}

function M.Create(onBack)
    local t = GameTime.Now()
    local year = t.year
    local month = t.month
    local today = t.day

    -- 计算本月信息
    local firstWeekday = os.date("*t", os.time({ year = year, month = month, day = 1 })).wday
    local daysInMonth = os.date("*t", os.time({ year = year, month = month + 1, day = 0 })).day

    -- 从数据模块加载日程
    local calEvents = DingtalkData.GetCalendarEvents()
    local events = {}
    for _, ev in ipairs(calEvents) do
        local day = today + ev.dayOffset
        if day >= 1 and day <= daysInMonth then
            if not events[day] then events[day] = {} end
            events[day][#events[day] + 1] = { time = ev.time, title = ev.title, color = ev.color }
        end
    end

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
    for i = 1, firstWeekday - 1 do
        dayWidgets[#dayWidgets + 1] = UI.Panel { width = "14.28%", height = 34 }
    end
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

return M
