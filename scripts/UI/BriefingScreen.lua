-- ============================================================================
-- BriefingScreen - 关卡简报画面
-- 功能: 显示关卡名称、背景故事、目标提示，点击"开始"进入关卡
-- 位置: 覆盖在 screenContainer_ 内部（替换手机屏幕内容）
-- ============================================================================

local UI = require("urhox-libs/UI")

local BriefingScreen = {}

--- 像素风颜色
local COLORS = {
    BG          = { 18, 18, 30, 255 },
    CARD_BG     = { 30, 30, 50, 240 },
    ACCENT      = { 100, 220, 160, 255 },
    TEXT_TITLE   = { 255, 255, 255, 255 },
    TEXT_BODY    = { 200, 200, 220, 255 },
    TEXT_DIM     = { 130, 130, 160, 255 },
    BTN_PRIMARY  = { 80, 180, 130, 255 },
    BTN_HOVER    = { 100, 200, 150, 255 },
    BTN_PRESSED  = { 60, 150, 110, 255 },
    DIVIDER      = { 60, 60, 90, 255 },
}

--- 创建简报画面
---@param levelData table 关卡数据（来自 LevelConfig.Load）
---@param onStart function 点击"开始"按钮的回调
---@return table UI.Panel
function BriefingScreen.Create(levelData, onStart)
    local config = levelData.config

    -- 格式化时长
    local durationMin = math.floor(config.duration / 60)
    local durationStr = durationMin .. " 分钟"

    -- 格式化起始时间
    local startTimeStr = string.format("%02d:%02d", config.startHour, config.startMin)

    local panel = UI.Panel {
        width = "100%",
        height = "100%",
        backgroundColor = COLORS.BG,
        flexDirection = "column",
        justifyContent = "center",
        alignItems = "center",
        paddingHorizontal = 24,
        children = {
            -- 顶部装饰线
            UI.Panel {
                width = 40,
                height = 3,
                backgroundColor = COLORS.ACCENT,
                marginBottom = 16,
            },

            -- 关卡名称
            UI.Label {
                text = config.name or "未命名关卡",
                fontSize = 22,
                fontColor = COLORS.TEXT_TITLE,
                textAlign = "center",
                marginBottom = 8,
            },

            -- 时间信息行
            UI.Panel {
                flexDirection = "row",
                gap = 16,
                marginBottom = 20,
                children = {
                    -- 起始时间
                    UI.Panel {
                        flexDirection = "row",
                        gap = 4,
                        alignItems = "center",
                        children = {
                            UI.Label {
                                text = "⏰",
                                fontSize = 11,
                                fontColor = COLORS.TEXT_DIM,
                            },
                            UI.Label {
                                text = startTimeStr,
                                fontSize = 11,
                                fontColor = COLORS.TEXT_DIM,
                            },
                        },
                    },
                    -- 时长
                    UI.Panel {
                        flexDirection = "row",
                        gap = 4,
                        alignItems = "center",
                        children = {
                            UI.Label {
                                text = "⏱",
                                fontSize = 11,
                                fontColor = COLORS.TEXT_DIM,
                            },
                            UI.Label {
                                text = durationStr,
                                fontSize = 11,
                                fontColor = COLORS.TEXT_DIM,
                            },
                        },
                    },
                },
            },

            -- 分隔线
            UI.Panel {
                width = "80%",
                height = 1,
                backgroundColor = COLORS.DIVIDER,
                marginBottom = 16,
            },

            -- 背景故事卡片
            UI.Panel {
                width = "100%",
                backgroundColor = COLORS.CARD_BG,
                borderRadius = 8,
                borderWidth = 1,
                borderColor = COLORS.DIVIDER,
                padding = 16,
                marginBottom = 16,
                children = {
                    UI.Label {
                        text = "任务简报",
                        fontSize = 12,
                        fontColor = COLORS.ACCENT,
                        marginBottom = 8,
                    },
                    UI.Label {
                        text = config.briefingText or "准备好了吗？",
                        fontSize = 12,
                        fontColor = COLORS.TEXT_BODY,
                        lineHeight = 1.6,
                    },
                },
            },

            -- 目标提示卡片
            UI.Panel {
                width = "100%",
                backgroundColor = COLORS.CARD_BG,
                borderRadius = 8,
                borderWidth = 1,
                borderColor = COLORS.DIVIDER,
                padding = 16,
                marginBottom = 28,
                children = {
                    UI.Label {
                        text = "关卡目标",
                        fontSize = 12,
                        fontColor = COLORS.ACCENT,
                        marginBottom = 8,
                    },
                    UI.Label {
                        text = config.objectiveText or "完成所有任务",
                        fontSize = 12,
                        fontColor = COLORS.TEXT_BODY,
                        lineHeight = 1.6,
                    },
                },
            },

            -- 开始按钮
            UI.Button {
                width = "70%",
                height = 44,
                backgroundColor = COLORS.BTN_PRIMARY,
                hoverBackgroundColor = COLORS.BTN_HOVER,
                pressedBackgroundColor = COLORS.BTN_PRESSED,
                borderRadius = 8,
                justifyContent = "center",
                alignItems = "center",
                onClick = function(self)
                    if onStart then
                        onStart()
                    end
                end,
                children = {
                    UI.Label {
                        text = "开始任务",
                        fontSize = 14,
                        fontColor = { 255, 255, 255, 255 },
                        pointerEvents = "none",
                    },
                },
            },

            -- 底部装饰
            UI.Panel {
                marginTop = 20,
                children = {
                    UI.Label {
                        text = "[ READY ]",
                        fontSize = 9,
                        fontColor = { 60, 60, 80, 120 },
                    },
                },
            },
        },
    }

    return panel
end

return BriefingScreen
