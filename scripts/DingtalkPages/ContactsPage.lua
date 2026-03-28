-- ============================================================================
-- 通讯录主页面（深色主题）
-- ============================================================================

local UI = require("urhox-libs/UI")
local DingtalkData = require("DingtalkData")
local Common = require("DingtalkPagesCommon")

local C = Common.C

local M = {}

--- 创建通讯录主页面
---@param onNavigate fun(title: string) 点击子项时的导航回调
function M.Create(onNavigate)
    -- 从数据模块获取分组顺序，取前5个作为组织架构子项
    local groupOrder = DingtalkData.GetContactGroupOrder()
    local orgItems = {}
    for i = 1, math.min(5, #groupOrder) do
        orgItems[#orgItems + 1] = groupOrder[i]
    end

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
                    overflow = "hidden",
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

    -- 功能入口项
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

    -- 外部组织项
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

    return UI.Panel {
        width = "100%",
        height = "100%",
        backgroundColor = { 22, 22, 30, 255 },
        flexDirection = "column",
        children = {
            -- 顶部区域：用户信息
            UI.Panel {
                width = "100%",
                paddingHorizontal = 12,
                paddingTop = 10,
                paddingBottom = 10,
                flexDirection = "row",
                alignItems = "center",
                gap = 10,
                children = {
                    UI.Panel {
                        width = 44, height = 44,
                        backgroundColor = { 60, 60, 80, 255 },
                        borderRadius = 8,
                        justifyContent = "center",
                        alignItems = "center",
                        children = {
                            UI.Label { text = "陈", fontSize = 16, fontColor = { 200, 200, 220, 255 } },
                        },
                    },
                    UI.Panel {
                        flexDirection = "column",
                        gap = 2,
                        flexGrow = 1,
                        flexShrink = 1,
                        overflow = "hidden",
                        children = {
                            UI.Label { text = "陈老师", fontSize = 15, fontColor = { 240, 240, 245, 255 }, fontWeight = "bold", maxLines = 1 },
                            UI.Label { text = "星火市明德职业技术学校", fontSize = 10, fontColor = { 140, 140, 150, 255 }, maxLines = 1, overflow = "hidden" },
                        },
                    },
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
                                    -- 卡片头部
                                    UI.Panel {
                                        width = "100%",
                                        paddingHorizontal = 16,
                                        paddingVertical = 14,
                                        flexDirection = "row",
                                        alignItems = "center",
                                        gap = 10,
                                        children = {
                                            UI.Panel {
                                                width = 44, height = 44,
                                                backgroundColor = { 50, 50, 65, 255 },
                                                borderRadius = 22,
                                                borderWidth = 1,
                                                borderColor = { 80, 80, 100, 255 },
                                                justifyContent = "center",
                                                alignItems = "center",
                                                children = {
                                                    UI.Label { text = "明德", fontSize = 12, fontColor = { 150, 150, 170, 255 } },
                                                },
                                            },
                                            UI.Panel {
                                                flexGrow = 1, flexShrink = 1,
                                                flexDirection = "column",
                                                gap = 4,
                                                overflow = "hidden",
                                                children = {
                                                    UI.Label {
                                                        text = "星火市明德职业技术学校",
                                                        fontSize = 14,
                                                        fontColor = { 240, 240, 245, 255 },
                                                        fontWeight = "bold",
                                                        maxLines = 1,
                                                        overflow = "hidden",
                                                    },
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

return M
