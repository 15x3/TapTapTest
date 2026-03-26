-- ============================================================================
-- 课表应用模块 (Schedule App)
-- 数据来源: assets/Data/schedule.csv（策划配置，游戏内不可修改）
-- ============================================================================

local UI = require("urhox-libs/UI")

local M = {}

-- ============================================================================
-- 课表数据
-- ============================================================================

local scheduleData_ = nil
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

--- 解析 CSV 内容为行列数组
local function parseCSV(content)
    local rows = {}
    for line in content:gmatch("[^\r\n]+") do
        local row = {}
        -- 处理逗号分隔，支持连续逗号产生空字段
        local pos = 1
        while pos <= #line do
            local c = line:sub(pos, pos)
            if c == "," then
                row[#row + 1] = ""
                pos = pos + 1
            else
                local nextComma = line:find(",", pos)
                if nextComma then
                    row[#row + 1] = line:sub(pos, nextComma - 1):match("^%s*(.-)%s*$")
                    pos = nextComma + 1
                else
                    row[#row + 1] = line:sub(pos):match("^%s*(.-)%s*$")
                    pos = #line + 1
                end
            end
        end
        -- 如果行以逗号结尾，补一个空字段
        if line:sub(-1) == "," then
            row[#row + 1] = ""
        end
        rows[#rows + 1] = row
    end
    return rows
end

--- 从 CSV 文件加载课表数据
local function initScheduleData()
    if scheduleData_ then return end

    -- 默认空数据（CSV 读取失败时使用）
    local defaultDays = { "周一", "周二", "周三", "周四", "周五" }
    local defaultTimes = {
        "08:00", "09:00", "10:10", "11:10",
        "14:00", "15:00", "16:10", "17:10",
    }

    scheduleData_ = {
        days = defaultDays,
        periods = #defaultTimes,
        data = {},
        periodTimes = defaultTimes,
    }

    -- 从资源目录读取 CSV（assets/ 是资源根目录）
    local file = cache:GetFile("Data/schedule.csv")
    if not file then
        print("[ScheduleApp] CSV not found, using empty schedule")
        for p = 1, scheduleData_.periods do
            scheduleData_.data[p] = {}
            for d = 1, #scheduleData_.days do
                scheduleData_.data[p][d] = ""
            end
        end
        return
    end

    local content = file:ReadString()
    file:Close()

    local rows = parseCSV(content)
    if #rows < 2 then
        print("[ScheduleApp] CSV has no data rows")
        return
    end

    -- 第一行是表头: time,周一,周二,...
    local header = rows[1]
    local days = {}
    for i = 2, #header do
        days[#days + 1] = header[i]
    end
    scheduleData_.days = days

    -- 后续行是课程数据: 08:00,高数,英语,...
    local periods = #rows - 1
    scheduleData_.periods = periods
    scheduleData_.periodTimes = {}
    scheduleData_.data = {}

    for p = 1, periods do
        local row = rows[p + 1]
        scheduleData_.periodTimes[p] = row[1] or ""
        scheduleData_.data[p] = {}
        for d = 1, #days do
            scheduleData_.data[p][d] = row[d + 1] or ""
        end
    end

    print("[ScheduleApp] Loaded " .. periods .. " periods, " .. #days .. " days from CSV")
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
-- 课表网格构建
-- ============================================================================

local function buildScheduleGrid()
    if not scheduleContainer_ then return end
    scheduleContainer_:ClearChildren()

    local sd = scheduleData_
    local white = { 255, 255, 255, 255 }
    local textColor = { 25, 25, 25, 255 }
    local textSec = { 120, 120, 140, 255 }
    local headerBgColor = { 230, 230, 240, 255 }
    local timeBgColor = { 245, 245, 250, 255 }
    local borderColor = { 210, 210, 220, 255 }
    local rowBorderColor = { 235, 235, 240, 255 }

    local CELL_H = 48
    local HEADER_H = 28
    local TIME_W = 38
    local dayCount = #sd.days

    -- 星期标题行
    local headerCells = {
        UI.Panel {
            width = TIME_W,
            flexShrink = 0,
            height = HEADER_H,
            justifyContent = "center",
            alignItems = "center",
            backgroundColor = headerBgColor,
            children = {
                UI.Label { text = "节", fontSize = 9, fontColor = textSec },
            },
        },
    }
    for d = 1, dayCount do
        headerCells[#headerCells + 1] = UI.Panel {
            flexGrow = 1,
            flexShrink = 1,
            flexBasis = 0,
            height = HEADER_H,
            justifyContent = "center",
            alignItems = "center",
            backgroundColor = headerBgColor,
            borderLeftWidth = 1,
            borderLeftColor = borderColor,
            children = {
                UI.Label { text = sd.days[d], fontSize = 9, fontColor = textColor },
            },
        }
    end

    local headerRow = UI.Panel {
        width = "100%",
        flexDirection = "row",
        borderBottomWidth = 1,
        borderBottomColor = borderColor,
        children = headerCells,
    }

    -- 课程网格行
    local gridRows = {}
    for p = 1, sd.periods do
        local rowCells = {
            UI.Panel {
                width = TIME_W,
                flexShrink = 0,
                height = CELL_H,
                justifyContent = "center",
                alignItems = "center",
                backgroundColor = timeBgColor,
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

            if courseName ~= "" then
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

            rowCells[#rowCells + 1] = UI.Panel {
                flexGrow = 1,
                flexShrink = 1,
                flexBasis = 0,
                height = CELL_H,
                backgroundColor = cellBg,
                borderLeftWidth = 1,
                borderLeftColor = rowBorderColor,
                justifyContent = "center",
                alignItems = "center",
                children = cellChildren,
            }
        end

        gridRows[#gridRows + 1] = UI.Panel {
            width = "100%",
            flexDirection = "row",
            borderBottomWidth = 1,
            borderBottomColor = rowBorderColor,
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

    buildScheduleGrid()

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
