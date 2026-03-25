-- ============================================================================
-- 校园地图应用模块 (Map App)
-- ============================================================================

local UI = require("urhox-libs/UI")

local M = {}

--- 创建地图应用 UI
---@param onBack function 返回主屏回调
---@return table UI.Panel
function M.Create(onBack)
    local headerBg = { 237, 237, 237, 255 }
    local white = { 255, 255, 255, 255 }
    local textColor = { 25, 25, 25, 255 }
    local textSec = { 153, 153, 153, 255 }
    local bg = { 237, 237, 237, 255 }

    -- 地图标记点
    local markers = {
        { name = "教学楼A", x = 0.35, y = 0.30, color = { 220, 70, 70, 255 } },
        { name = "图书馆",   x = 0.55, y = 0.25, color = { 60, 140, 220, 255 } },
        { name = "食堂",     x = 0.40, y = 0.55, color = { 240, 160, 40, 255 } },
        { name = "体育馆",   x = 0.70, y = 0.50, color = { 80, 190, 80, 255 } },
        { name = "宿舍楼",   x = 0.25, y = 0.70, color = { 160, 100, 200, 255 } },
        { name = "校门",     x = 0.50, y = 0.88, color = { 100, 100, 120, 255 } },
        { name = "实验楼",   x = 0.72, y = 0.30, color = { 200, 100, 60, 255 } },
        { name = "操场",     x = 0.65, y = 0.68, color = { 60, 180, 120, 255 } },
    }

    -- 道路数据
    local roads = {
        { x = "8%", y = "45%", w = "84%", h = 4, color = { 200, 200, 200, 255 } },
        { x = "48%", y = "10%", w = 4, h = "80%", color = { 200, 200, 200, 255 } },
        { x = "20%", y = "25%", w = "30%", h = 3, color = { 215, 215, 215, 255 } },
        { x = "55%", y = "65%", w = "25%", h = 3, color = { 215, 215, 215, 255 } },
        { x = "30%", y = "30%", w = 3, h = "40%", color = { 215, 215, 215, 255 } },
    }

    -- 绿地区域
    local greenAreas = {
        { x = "12%", y = "38%", w = "15%", h = "12%", color = { 180, 220, 160, 120 } },
        { x = "58%", y = "55%", w = "22%", h = "22%", color = { 180, 220, 160, 120 } },
    }

    -- 构建地图内容
    local mapChildren = {}

    -- 绿地
    for _, g in ipairs(greenAreas) do
        mapChildren[#mapChildren + 1] = UI.Panel {
            position = "absolute",
            left = g.x, top = g.y,
            width = g.w, height = g.h,
            backgroundColor = g.color,
            borderRadius = 4,
            pointerEvents = "none",
        }
    end

    -- 道路
    for _, r in ipairs(roads) do
        mapChildren[#mapChildren + 1] = UI.Panel {
            position = "absolute",
            left = r.x, top = r.y,
            width = r.w, height = r.h,
            backgroundColor = r.color,
            borderRadius = 1,
            pointerEvents = "none",
        }
    end

    -- 标记点
    for _, m in ipairs(markers) do
        local leftPct = string.format("%.0f%%", m.x * 100 - 4)
        local topPct  = string.format("%.0f%%", m.y * 100 - 4)
        mapChildren[#mapChildren + 1] = UI.Panel {
            position = "absolute",
            left = leftPct,
            top = topPct,
            alignItems = "center",
            gap = 2,
            pointerEvents = "none",
            children = {
                UI.Panel {
                    width = 18, height = 18,
                    backgroundColor = m.color,
                    borderRadius = 9,
                    borderWidth = 2,
                    borderColor = { 255, 255, 255, 255 },
                    justifyContent = "center",
                    alignItems = "center",
                    boxShadow = {
                        { x = 0, y = 1, blur = 3, spread = 0, color = { 0, 0, 0, 60 } },
                    },
                },
                UI.Panel {
                    paddingHorizontal = 4, paddingVertical = 2,
                    backgroundColor = { 255, 255, 255, 220 },
                    borderRadius = 3,
                    boxShadow = {
                        { x = 0, y = 1, blur = 2, spread = 0, color = { 0, 0, 0, 40 } },
                    },
                    children = {
                        UI.Label { text = m.name, fontSize = 8, fontColor = textColor },
                    },
                },
            },
        }
    end

    -- 指南针
    mapChildren[#mapChildren + 1] = UI.Panel {
        position = "absolute",
        top = 8, right = 8,
        width = 28, height = 28,
        backgroundColor = { 255, 255, 255, 220 },
        borderRadius = 14,
        borderWidth = 1,
        borderColor = { 200, 200, 200, 255 },
        justifyContent = "center",
        alignItems = "center",
        pointerEvents = "none",
        children = {
            UI.Label { text = "N", fontSize = 10, fontColor = { 220, 60, 60, 255 } },
        },
    }

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
                    UI.Label { text = "校园地图", fontSize = 14, fontColor = textColor },
                    UI.Panel { width = 30, height = 30 },
                },
            },
            -- 搜索栏
            UI.Panel {
                width = "100%",
                height = 36,
                backgroundColor = headerBg,
                paddingHorizontal = 10,
                paddingBottom = 6,
                children = {
                    UI.Panel {
                        width = "100%",
                        height = "100%",
                        backgroundColor = white,
                        borderRadius = 4,
                        justifyContent = "center",
                        alignItems = "center",
                        children = {
                            UI.Label { text = "搜索地点...", fontSize = 11, fontColor = { 180, 180, 180, 255 } },
                        },
                    },
                },
            },
            -- 地图区域
            UI.Panel {
                width = "100%",
                flexGrow = 1,
                flexBasis = 0,
                backgroundColor = { 235, 245, 230, 255 },
                overflow = "hidden",
                children = mapChildren,
            },
            -- 底部信息栏
            UI.Panel {
                width = "100%",
                height = 36,
                backgroundColor = white,
                flexDirection = "row",
                justifyContent = "center",
                alignItems = "center",
                borderTopWidth = 1,
                borderTopColor = { 220, 220, 220, 255 },
                gap = 16,
                children = {
                    UI.Label { text = "共 " .. #markers .. " 个地点", fontSize = 10, fontColor = textSec },
                    UI.Panel { width = 1, height = 14, backgroundColor = { 200, 200, 200, 255 } },
                    UI.Label { text = "校园导览", fontSize = 10, fontColor = textSec },
                },
            },
        },
    }
end

return M
