local UI = require("urhox-libs/UI")
local DingtalkData = require("DingtalkData")
local Common = require("DingtalkPagesCommon")
local TextUtils = require("Utils.TextUtils")
local truncate = TextUtils.truncate
local C = Common.C

local M = {}

function M.Create(onBack)
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

        local dingData = DingtalkData.GetDings()

        -- 统计未读
        local unreadCount = DingtalkData.GetUnreadDingCount()

        -- 创建 DING 列表项
        local dingItems = {}
        for _, ding in ipairs(dingData) do
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
                        overflow = "hidden",
                        children = {
                            UI.Panel {
                                flexDirection = "row",
                                alignItems = "center",
                                gap = 6,
                                flexShrink = 1,
                                overflow = "hidden",
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
                                        text = truncate(ding.sender, 10),
                                        fontSize = 12,
                                        fontColor = C.text,
                                        maxLines = 1,
                                        flexShrink = 1,
                                    },
                                },
                            },
                            UI.Label { text = ding.time, fontSize = 9, fontColor = C.textSec, flexShrink = 0 },
                        },
                    },
                    -- 内容
                    UI.Label {
                        text = truncate(ding.content, 30),
                        fontSize = 11,
                        fontColor = { 60, 60, 60, 255 },
                        maxLines = 2,
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

        -- 顶栏
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
                    DingtalkData.MarkAllDingRead()
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

return M
