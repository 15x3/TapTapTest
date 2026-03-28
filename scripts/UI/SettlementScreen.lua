-- ============================================================================
-- SettlementScreen - 关卡结算画面
-- 功能: 显示关卡结算结果（按信息链分组，纯事实陈述，无评分）
-- 位置: 覆盖在 screenContainer_ 内部
-- ============================================================================

local UI = require("urhox-libs/UI")

local SettlementScreen = {}

--- 像素风颜色
local COLORS = {
    BG           = { 18, 18, 30, 255 },
    CARD_BG      = { 30, 30, 50, 240 },
    ACCENT       = { 100, 220, 160, 255 },
    TEXT_TITLE    = { 255, 255, 255, 255 },
    TEXT_BODY     = { 200, 200, 220, 255 },
    TEXT_DIM      = { 130, 130, 160, 255 },
    SUCCESS      = { 80, 200, 120, 255 },
    WARNING      = { 230, 190, 50, 255 },
    ERROR        = { 220, 80, 80, 255 },
    BTN_PRIMARY  = { 80, 180, 130, 255 },
    BTN_HOVER    = { 100, 200, 150, 255 },
    BTN_PRESSED  = { 60, 150, 110, 255 },
    DIVIDER      = { 60, 60, 90, 255 },
}

--- 结果 → 颜色/图标映射
local RESULT_STYLE = {
    correct = { color = COLORS.SUCCESS, icon = "+" },
    wrong   = { color = COLORS.ERROR,   icon = "x" },
    missed  = { color = COLORS.ERROR,   icon = "-" },
    timeout = { color = COLORS.WARNING, icon = "!" },
}

--- 创建结算画面
---@param levelData table 关卡数据
---@param reportData table|nil 结算报告数据
---@param onContinue function 点击"返回"按钮的回调
---@return table UI.Panel
function SettlementScreen.Create(levelData, reportData, onContinue)
    local config = levelData.config

    -- 构建内容列表
    local contentItems = {}

    if reportData then
        -- 信息链结果
        for _, chain in ipairs(reportData.chains) do
            -- 链名标题
            contentItems[#contentItems + 1] = UI.Label {
                text = "[ " .. chain.name .. " ]",
                fontSize = 12,
                fontColor = COLORS.ACCENT,
                marginTop = 8,
                marginBottom = 4,
            }

            -- 链中各事件
            for _, event in ipairs(chain.events) do
                local style = RESULT_STYLE[event.result] or RESULT_STYLE.missed
                contentItems[#contentItems + 1] = UI.Panel {
                    width = "100%",
                    flexDirection = "row",
                    alignItems = "flex-start",
                    marginVertical = 2,
                    paddingLeft = 8,
                    children = {
                        UI.Label {
                            text = style.icon,
                            fontSize = 11,
                            fontColor = style.color,
                            width = 14,
                            flexShrink = 0,
                        },
                        UI.Label {
                            text = event.description,
                            fontSize = 11,
                            fontColor = style.color,
                            flexShrink = 1,
                        },
                    },
                }
            end
        end

        -- 公告结果
        if #reportData.announcements > 0 then
            contentItems[#contentItems + 1] = UI.Label {
                text = "[ 公告发布 ]",
                fontSize = 12,
                fontColor = COLORS.ACCENT,
                marginTop = 10,
                marginBottom = 4,
            }
            for _, ann in ipairs(reportData.announcements) do
                local style = ann.passed and RESULT_STYLE.correct or RESULT_STYLE.missed
                contentItems[#contentItems + 1] = UI.Panel {
                    width = "100%",
                    flexDirection = "row",
                    alignItems = "flex-start",
                    marginVertical = 2,
                    paddingLeft = 8,
                    children = {
                        UI.Label {
                            text = style.icon,
                            fontSize = 11,
                            fontColor = style.color,
                            width = 14,
                            flexShrink = 0,
                        },
                        UI.Label {
                            text = ann.description,
                            fontSize = 11,
                            fontColor = style.color,
                            flexShrink = 1,
                        },
                    },
                }
            end
        end

        -- 汇总行
        local s = reportData.summary
        if s.total > 0 then
            contentItems[#contentItems + 1] = UI.Panel {
                width = "100%",
                height = 1,
                backgroundColor = COLORS.DIVIDER,
                marginTop = 10,
                marginBottom = 6,
            }
            contentItems[#contentItems + 1] = UI.Label {
                text = string.format("共 %d 项任务  |  完成 %d  |  遗漏 %d  |  错误 %d",
                    s.total, s.handled, s.missed, s.wrong),
                fontSize = 10,
                fontColor = COLORS.TEXT_DIM,
                textAlign = "center",
            }
        end
    else
        -- 没有报告数据时的占位
        contentItems[#contentItems + 1] = UI.Label {
            text = "关卡结束",
            fontSize = 12,
            fontColor = COLORS.TEXT_DIM,
            textAlign = "center",
            marginVertical = 8,
        }
    end

    -- 构建报告卡片 children（避免 table.unpack 在非末位的陷阱）
    local cardChildren = {
        UI.Label {
            text = "任务报告",
            fontSize = 12,
            fontColor = COLORS.ACCENT,
            marginBottom = 8,
        },
    }
    for _, item in ipairs(contentItems) do
        cardChildren[#cardChildren + 1] = item
    end

    local panel = UI.Panel {
        width = "100%",
        height = "100%",
        backgroundColor = COLORS.BG,
        flexDirection = "column",
        alignItems = "center",
        children = {
            -- 可滚动内容区
            UI.ScrollView {
                width = "100%",
                flexGrow = 1,
                flexShrink = 1,
                children = {
                    UI.Panel {
                        width = "100%",
                        flexDirection = "column",
                        alignItems = "center",
                        paddingHorizontal = 24,
                        paddingTop = 32,
                        paddingBottom = 16,
                        children = {
                            -- 顶部装饰线
                            UI.Panel {
                                width = 40,
                                height = 3,
                                backgroundColor = COLORS.WARNING,
                                marginBottom = 16,
                            },

                            -- 标题
                            UI.Label {
                                text = "任务结束",
                                fontSize = 22,
                                fontColor = COLORS.TEXT_TITLE,
                                textAlign = "center",
                                marginBottom = 4,
                            },

                            -- 关卡名
                            UI.Label {
                                text = config.name or "",
                                fontSize = 12,
                                fontColor = COLORS.TEXT_DIM,
                                textAlign = "center",
                                marginBottom = 20,
                            },

                            -- 分隔线
                            UI.Panel {
                                width = "80%",
                                height = 1,
                                backgroundColor = COLORS.DIVIDER,
                                marginBottom = 16,
                            },

                            -- 结算内容卡片
                            UI.Panel {
                                width = "100%",
                                backgroundColor = COLORS.CARD_BG,
                                borderRadius = 8,
                                borderWidth = 1,
                                borderColor = COLORS.DIVIDER,
                                padding = 16,
                                flexDirection = "column",
                                gap = 2,
                                children = cardChildren,
                            },
                        },
                    },
                },
            },

            -- 底部固定按钮区
            UI.Panel {
                width = "100%",
                flexShrink = 0,
                paddingHorizontal = 24,
                paddingVertical = 16,
                alignItems = "center",
                children = {
                    -- 继续按钮
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
                            if onContinue then
                                onContinue()
                            end
                        end,
                        children = {
                            UI.Label {
                                text = "返回",
                                fontSize = 14,
                                fontColor = { 255, 255, 255, 255 },
                                pointerEvents = "none",
                            },
                        },
                    },

                    -- 底部装饰
                    UI.Label {
                        text = "[ COMPLETE ]",
                        fontSize = 9,
                        fontColor = { 60, 60, 80, 120 },
                        marginTop = 12,
                    },
                },
            },
        },
    }

    return panel
end

return SettlementScreen
