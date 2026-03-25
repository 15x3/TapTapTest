-- ============================================================================
-- 课表应用模块 (Schedule App)
-- ============================================================================

local UI = require("urhox-libs/UI")

local M = {}

-- ============================================================================
-- 课表数据
-- ============================================================================

local scheduleData_ = nil
local scheduleEditCell_ = nil
local scheduleContainer_ = nil

local COURSE_COLORS = {
    { 76, 140, 230, 200 },
    { 100, 190, 100, 200 },
    { 230, 140, 60, 200 },
    { 190, 90, 190, 200 },
    { 60, 180, 180, 200 },
    { 220, 90, 90, 200 },
    { 160, 140, 60, 200 },
    { 90, 120, 200, 200 },
}

local function initScheduleData()
    if scheduleData_ then return end
    local DAYS = { "周一", "周二", "周三", "周四", "周五" }
    local PERIODS = 8
    scheduleData_ = {
        days = DAYS,
        periods = PERIODS,
        data = {},
        periodTimes = {
            "08:00", "09:00", "10:10", "11:10",
            "14:00", "15:00", "16:10", "17:10",
        },
    }
    for p = 1, PERIODS do
        scheduleData_.data[p] = {}
        for d = 1, #DAYS do
            scheduleData_.data[p][d] = ""
        end
    end
    -- 预填默认课程
    scheduleData_.data[1][1] = "高数"
    scheduleData_.data[2][1] = "高数"
    scheduleData_.data[1][2] = "英语"
    scheduleData_.data[3][2] = "物理"
    scheduleData_.data[1][3] = "编程"
    scheduleData_.data[2][3] = "编程"
    scheduleData_.data[4][3] = "体育"
    scheduleData_.data[1][4] = "英语"
    scheduleData_.data[3][4] = "物理"
    scheduleData_.data[5][4] = "数据结构"
    scheduleData_.data[1][5] = "线代"
    scheduleData_.data[2][5] = "线代"
    scheduleData_.data[5][1] = "大学物理"
    scheduleData_.data[6][2] = "思政"
    scheduleData_.data[5][5] = "选修课"
end

local function getCourseColor(name)
    if not name or name == "" then return nil end
    local hash = 0
    for i = 1, #name do
        hash = hash + string.byte(name, i)
    end
    return COURSE_COLORS[(hash % #COURSE_COLORS) + 1]
end

-- ============================================================================
-- 课表网格刷新
-- ============================================================================

local function refreshScheduleGrid()
    if not scheduleContainer_ then return end
    scheduleContainer_:ClearChildren()

    local sd = scheduleData_
    local white = { 255, 255, 255, 255 }
    local textColor = { 25, 25, 25, 255 }
    local textSec = { 120, 120, 140, 255 }

    local CELL_H = 48
    local TIME_W = 38
    local dayCount = #sd.days

    -- 星期标题行
    local headerCells = {
        UI.Panel {
            width = TIME_W,
            height = 28,
            justifyContent = "center",
            alignItems = "center",
            backgroundColor = { 230, 230, 240, 255 },
            children = {
                UI.Label { text = "节", fontSize = 9, fontColor = textSec },
            },
        },
    }
    for d = 1, dayCount do
        headerCells[#headerCells + 1] = UI.Panel {
            flexGrow = 1,
            flexBasis = 0,
            height = 28,
            justifyContent = "center",
            alignItems = "center",
            backgroundColor = { 230, 230, 240, 255 },
            borderLeftWidth = 1,
            borderLeftColor = { 210, 210, 220, 255 },
            children = {
                UI.Label { text = sd.days[d], fontSize = 9, fontColor = textColor },
            },
        }
    end

    local headerRow = UI.Panel {
        width = "100%",
        flexDirection = "row",
        borderBottomWidth = 1,
        borderBottomColor = { 200, 200, 210, 255 },
        children = headerCells,
    }

    -- 课程网格
    local gridRows = {}
    for p = 1, sd.periods do
        local rowCells = {
            UI.Panel {
                width = TIME_W,
                height = CELL_H,
                justifyContent = "center",
                alignItems = "center",
                backgroundColor = { 245, 245, 250, 255 },
                flexDirection = "column",
                gap = 1,
                children = {
                    UI.Label { text = tostring(p), fontSize = 10, fontColor = textColor },
                    UI.Label { text = sd.periodTimes[p] or "", fontSize = 7, fontColor = textSec },
                },
            },
        }
        for d = 1, dayCount do
            local courseName = sd.data[p][d] or ""
            local cellBg = white
            local cellChildren = {}

            if scheduleEditCell_ and scheduleEditCell_[1] == p and scheduleEditCell_[2] == d then
                local periodRef, dayRef = p, d
                cellChildren[#cellChildren + 1] = UI.TextField {
                    width = "100%",
                    height = "100%",
                    fontSize = 9,
                    value = courseName,
                    placeholder = "课程",
                    backgroundColor = { 255, 255, 230, 255 },
                    borderRadius = 0,
                    paddingHorizontal = 2,
                    onSubmit = function(self, value)
                        scheduleData_.data[periodRef][dayRef] = value
                        scheduleEditCell_ = nil
                        refreshScheduleGrid()
                    end,
                }
            elseif courseName ~= "" then
                local cc = getCourseColor(courseName)
                cellBg = cc or { 200, 220, 255, 200 }
                cellChildren[#cellChildren + 1] = UI.Label {
                    text = courseName,
                    fontSize = 9,
                    fontColor = { 255, 255, 255, 255 },
                    textAlign = "center",
                    maxLines = 2,
                    pointerEvents = "none",
                }
            end

            local periodRef, dayRef = p, d
            rowCells[#rowCells + 1] = UI.Button {
                flexGrow = 1,
                flexBasis = 0,
                height = CELL_H,
                backgroundColor = cellBg,
                hoverBackgroundColor = { 240, 240, 250, 255 },
                pressedBackgroundColor = { 230, 230, 245, 255 },
                borderRadius = 0,
                borderLeftWidth = 1,
                borderLeftColor = { 230, 230, 240, 255 },
                justifyContent = "center",
                alignItems = "center",
                onClick = function(self)
                    scheduleEditCell_ = { periodRef, dayRef }
                    refreshScheduleGrid()
                end,
                children = cellChildren,
            }
        end

        gridRows[#gridRows + 1] = UI.Panel {
            width = "100%",
            flexDirection = "row",
            borderBottomWidth = 1,
            borderBottomColor = { 235, 235, 240, 255 },
            children = rowCells,
        }
    end

    local scrollContent = UI.ScrollView {
        width = "100%",
        flexGrow = 1,
        flexBasis = 0,
        children = {
            UI.Panel {
                width = "100%",
                flexDirection = "column",
                children = gridRows,
            },
        },
    }

    scheduleContainer_:AddChild(headerRow)
    scheduleContainer_:AddChild(scrollContent)
end

-- ============================================================================
-- 公开接口
-- ============================================================================

--- 创建课表应用 UI
---@param onBack function 返回主屏回调
---@return table UI.Panel
function M.Create(onBack)
    initScheduleData()
    scheduleEditCell_ = nil

    local headerBg = { 237, 237, 237, 255 }
    local textColor = { 25, 25, 25, 255 }
    local bg = { 237, 237, 237, 255 }

    scheduleContainer_ = UI.Panel {
        id = "scheduleContent",
        width = "100%",
        flexGrow = 1,
        flexBasis = 0,
        flexDirection = "column",
        overflow = "hidden",
    }

    refreshScheduleGrid()

    return UI.Panel {
        width = "100%",
        height = "100%",
        backgroundColor = bg,
        flexDirection = "column",
        children = {
            -- 顶栏
            UI.Panel {
                width = "100%",
                height = 44,
                backgroundColor = headerBg,
                flexDirection = "row",
                alignItems = "center",
                justifyContent = "space-between",
                paddingHorizontal = 12,
                borderBottomWidth = 1,
                borderBottomColor = { 210, 210, 210, 255 },
                children = {
                    UI.Button {
                        width = 30, height = 30,
                        backgroundColor = { 0, 0, 0, 0 },
                        hoverBackgroundColor = { 0, 0, 0, 10 },
                        pressedBackgroundColor = { 0, 0, 0, 20 },
                        borderRadius = 4,
                        text = "<",
                        textColor = textColor,
                        fontSize = 14,
                        onClick = function(self) onBack() end,
                    },
                    UI.Label { text = "我的课表", fontSize = 14, fontColor = textColor },
                    UI.Panel { width = 30, height = 30 },
                },
            },
            scheduleContainer_,
        },
    }
end

return M
