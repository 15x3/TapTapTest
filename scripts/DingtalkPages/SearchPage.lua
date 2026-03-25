-- ============================================================================
-- 搜索页面模块 (Search Page)
-- ============================================================================

local UI = require("urhox-libs/UI")
local DingtalkData = require("DingtalkData")
local Common = require("DingtalkPagesCommon")

local C = Common.C

local M = {}

function M.Create(onBack, onNavigate)
    local resultContainer = UI.Panel {
        width = "100%",
        flexDirection = "column",
        paddingBottom = 20,
    }

    local hintPanel = UI.Panel {
        width = "100%",
        paddingVertical = 60,
        alignItems = "center",
        justifyContent = "center",
        children = {
            UI.Label { text = "输入关键词搜索", fontSize = 12, fontColor = C.textSec },
        },
    }
    resultContainer:AddChild(hintPanel)

    local function doSearch(keyword)
        resultContainer:ClearChildren()
        if not keyword or keyword == "" then
            resultContainer:AddChild(UI.Panel {
                width = "100%", paddingVertical = 60, alignItems = "center",
                children = {
                    UI.Label { text = "输入关键词搜索", fontSize = 12, fontColor = C.textSec },
                },
            })
            return
        end

        local r = DingtalkData.SearchAll(keyword)
        if not r then return end

        local totalCount = #r.contacts + #r.chats + #r.todos + #r.dings + #r.calendar
        if totalCount == 0 then
            resultContainer:AddChild(UI.Panel {
                width = "100%", paddingVertical = 60, alignItems = "center",
                children = {
                    UI.Label { text = "未找到\"" .. keyword .. "\"相关结果", fontSize = 12, fontColor = C.textSec },
                },
            })
            return
        end

        local function SectionTitle(title, count)
            return UI.Panel {
                width = "100%",
                paddingHorizontal = 14,
                paddingTop = 14,
                paddingBottom = 6,
                backgroundColor = C.bg,
                children = {
                    UI.Label {
                        text = title .. " (" .. count .. ")",
                        fontSize = 12,
                        fontColor = C.blue,
                        fontWeight = "bold",
                    },
                },
            }
        end

        local function ResultRow(icon, iconBg, line1, line2, onClick)
            return UI.Button {
                width = "100%",
                height = 56,
                paddingHorizontal = 14,
                flexDirection = "row",
                alignItems = "center",
                gap = 10,
                backgroundColor = C.white,
                hoverBackgroundColor = { 245, 245, 250, 255 },
                pressedBackgroundColor = { 235, 235, 240, 255 },
                borderRadius = 0,
                borderBottomWidth = 1,
                borderBottomColor = { 245, 245, 245, 255 },
                onClick = function(self)
                    if onClick and onNavigate then onClick() end
                end,
                children = {
                    UI.Panel {
                        width = 36, height = 36,
                        backgroundColor = iconBg,
                        borderRadius = 18,
                        justifyContent = "center",
                        alignItems = "center",
                        pointerEvents = "none",
                        children = {
                            UI.Label { text = icon, fontSize = 12, fontColor = { 255, 255, 255, 255 } },
                        },
                    },
                    UI.Panel {
                        flexGrow = 1, flexShrink = 1,
                        flexDirection = "column",
                        gap = 2,
                        pointerEvents = "none",
                        children = {
                            UI.Label { text = line1, fontSize = 13, fontColor = C.text, maxLines = 1 },
                            UI.Label { text = line2, fontSize = 10, fontColor = C.textSec, maxLines = 1 },
                        },
                    },
                    UI.Label { text = ">", fontSize = 12, fontColor = C.textSec, pointerEvents = "none" },
                },
            }
        end

        -- 联系人
        if #r.contacts > 0 then
            resultContainer:AddChild(SectionTitle("联系人", #r.contacts))
            for _, c in ipairs(r.contacts) do
                local contactGroup = c.group
                resultContainer:AddChild(ResultRow(c.initial, { 80, 130, 220, 255 }, c.name, c.role .. " · " .. c.group,
                    function() onNavigate("contact", { group = contactGroup }) end))
            end
        end

        -- 群聊
        if #r.chats > 0 then
            resultContainer:AddChild(SectionTitle("群聊 / 会话", #r.chats))
            for _, ch in ipairs(r.chats) do
                local chatData = ch
                resultContainer:AddChild(ResultRow(ch.iconText or "群", ch.iconBg or C.blue, ch.name, ch.msg or "",
                    function() onNavigate("chat", chatData) end))
            end
        end

        -- 待办
        if #r.todos > 0 then
            resultContainer:AddChild(SectionTitle("待办事项", #r.todos))
            for _, td in ipairs(r.todos) do
                local status = td.done and "已完成" or "待处理"
                local pLabel = ({ high = "紧急", medium = "普通", low = "较低" })[td.priority] or ""
                resultContainer:AddChild(ResultRow(td.done and "V" or "O",
                    td.done and C.green or C.orange,
                    td.text,
                    status .. " · " .. pLabel .. " · " .. (td.due or ""),
                    function() onNavigate("todo", nil) end))
            end
        end

        -- DING
        if #r.dings > 0 then
            resultContainer:AddChild(SectionTitle("DING 消息", #r.dings))
            for _, d in ipairs(r.dings) do
                local ic = d.urgent and "!" or "D"
                local bg = d.urgent and C.red or C.blue
                resultContainer:AddChild(ResultRow(ic, bg, d.sender .. " · " .. d.time, d.content,
                    function() onNavigate("ding", nil) end))
            end
        end

        -- 日历日程
        if #r.calendar > 0 then
            resultContainer:AddChild(SectionTitle("日程", #r.calendar))
            for _, ev in ipairs(r.calendar) do
                resultContainer:AddChild(ResultRow("日", { 60, 160, 120, 255 }, ev.title, ev.time .. " · " .. ev.desc,
                    function() onNavigate("calendar", nil) end))
            end
        end
    end

    return UI.Panel {
        width = "100%",
        height = "100%",
        backgroundColor = C.bg,
        flexDirection = "column",
        children = {
            -- 搜索顶栏
            UI.Panel {
                width = "100%",
                height = 48,
                backgroundColor = C.white,
                flexDirection = "row",
                alignItems = "center",
                paddingHorizontal = 8,
                gap = 6,
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
                    UI.Panel {
                        flexGrow = 1, flexBasis = 0,
                        height = 32,
                        backgroundColor = { 242, 242, 242, 255 },
                        borderRadius = 16,
                        flexDirection = "row",
                        alignItems = "center",
                        paddingHorizontal = 4,
                        children = {
                            UI.TextField {
                                placeholder = "搜索联系人、群聊、待办...",
                                flexGrow = 1,
                                onChange = function(self, v)
                                    doSearch(v)
                                end,
                            },
                        },
                    },
                },
            },
            -- 结果区
            UI.ScrollView {
                width = "100%",
                flexGrow = 1, flexBasis = 0,
                children = { resultContainer },
            },
        },
    }
end

return M
