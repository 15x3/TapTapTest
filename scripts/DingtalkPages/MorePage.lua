-- ============================================================================
-- 更多页面模块 (More Page)
-- ============================================================================

local UI = require("urhox-libs/UI")
local Toast = require("urhox-libs/UI/Widgets/Toast")
local Common = require("DingtalkPagesCommon")
local AboutPage = require("DingtalkPages.AboutPage")

local C = Common.C

local M = {}

local function showNotAvailable()
    Toast.Show("功能暂未开放", { type = "info", duration = 2 })
end

function M.Create()
    local function MenuItem(iconText, iconBg, label, onClick)
        return UI.Button {
            width = "100%",
            height = 52,
            backgroundColor = C.white,
            hoverBackgroundColor = { 248, 248, 248, 255 },
            pressedBackgroundColor = { 240, 240, 240, 255 },
            borderRadius = 0,
            flexDirection = "row",
            alignItems = "center",
            paddingHorizontal = 14,
            gap = 12,
            borderBottomWidth = 1,
            borderBottomColor = { 245, 245, 245, 255 },
            onClick = function(self)
                if onClick then onClick() end
            end,
            children = {
                UI.Panel {
                    width = 34, height = 34,
                    backgroundColor = iconBg,
                    borderRadius = 8,
                    justifyContent = "center",
                    alignItems = "center",
                    pointerEvents = "none",
                    children = {
                        UI.Label { text = iconText, fontSize = 13, fontColor = { 255, 255, 255, 255 } },
                    },
                },
                UI.Label {
                    text = label,
                    fontSize = 13,
                    fontColor = C.text,
                    flexGrow = 1,
                    pointerEvents = "none",
                },
                UI.Label {
                    text = ">",
                    fontSize = 13,
                    fontColor = C.textSec,
                    pointerEvents = "none",
                },
            },
        }
    end

    local moreContainer = UI.Panel {
        width = "100%",
        height = "100%",
        flexDirection = "column",
    }

    local buildMainMenu -- 前向声明

    local function showAbout()
        moreContainer:ClearChildren()
        moreContainer:AddChild(AboutPage.Create(function()
            moreContainer:ClearChildren()
            moreContainer:AddChild(buildMainMenu())
        end))
    end

    buildMainMenu = function()
        return UI.Panel {
            width = "100%",
            height = "100%",
            backgroundColor = C.bg,
            flexDirection = "column",
            children = {
                UI.Panel {
                    width = "100%",
                    height = 44,
                    backgroundColor = C.white,
                    justifyContent = "center",
                    alignItems = "center",
                    borderBottomWidth = 1,
                    borderBottomColor = C.border,
                    children = {
                        UI.Label { text = "更多", fontSize = 15, fontColor = C.text },
                    },
                },
                UI.ScrollView {
                    width = "100%",
                    flexGrow = 1, flexBasis = 0,
                    children = {
                        UI.Panel {
                            width = "100%",
                            flexDirection = "column",
                            paddingTop = 10,
                            gap = 10,
                            children = {
                                UI.Panel {
                                    width = "100%",
                                    flexDirection = "column",
                                    backgroundColor = C.white,
                                    borderRadius = 0,
                                    children = {
                                        MenuItem("钱", { 255, 140, 0, 255 }, "钱包", showNotAvailable),
                                        MenuItem("扫", C.blue, "扫一扫", showNotAvailable),
                                        MenuItem("卡", { 60, 180, 100, 255 }, "名片", showNotAvailable),
                                    },
                                },
                                UI.Panel {
                                    width = "100%",
                                    flexDirection = "column",
                                    backgroundColor = C.white,
                                    children = {
                                        MenuItem("设", { 100, 100, 120, 255 }, "设置", showNotAvailable),
                                        MenuItem("帮", { 80, 150, 220, 255 }, "帮助与反馈", showNotAvailable),
                                    },
                                },
                                UI.Panel {
                                    width = "100%",
                                    flexDirection = "column",
                                    backgroundColor = C.white,
                                    children = {
                                        MenuItem("i", { 48, 118, 255, 255 }, "关于", showAbout),
                                    },
                                },
                            },
                        },
                    },
                },
            },
        }
    end

    moreContainer:AddChild(buildMainMenu())
    return moreContainer
end

return M
