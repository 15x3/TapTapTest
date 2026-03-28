-- ============================================================================
-- 通讯录子页面：人员列表（深色主题）
-- ============================================================================

local UI = require("urhox-libs/UI")
local DingtalkData = require("DingtalkData")
local Common = require("DingtalkPagesCommon")
local Colors = require("Utils.Colors")

local TextUtils = require("Utils.TextUtils")
local truncate = TextUtils.truncate
local C = Common.C

local M = {}

--- 创建通讯录子页面：人员列表（深色主题）
function M.Create(title, onBack)
    local contactsData = DingtalkData.GetContacts()
    local people = contactsData[title] or {}

    local personItems = {}
    for i, person in ipairs(people) do
        local avatarBg = Colors.GetAvatarColor(person.initial)

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
                UI.Panel {
                    flexGrow = 1, flexShrink = 1,
                    flexDirection = "column",
                    gap = 3,
                    overflow = "hidden",
                    children = {
                        UI.Label { text = truncate(person.name, 12), fontSize = 14, fontColor = { 235, 235, 240, 255 }, maxLines = 1 },
                        UI.Label { text = truncate(person.role, 18), fontSize = 11, fontColor = { 120, 120, 135, 255 }, maxLines = 1 },
                    },
                },
            },
        }
    end

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

return M
