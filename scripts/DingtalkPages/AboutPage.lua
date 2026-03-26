-- ============================================================================
-- 关于页面模块 (About Page)
-- ============================================================================

local UI = require("urhox-libs/UI")
local Common = require("DingtalkPagesCommon")

local C = Common.C

local M = {}

function M.Create(onBack)
    local function InfoRow(label, value)
        return UI.Panel {
            width = "100%",
            paddingVertical = 10,
            paddingHorizontal = 20,
            flexDirection = "row",
            justifyContent = "space-between",
            alignItems = "center",
            borderBottomWidth = 1,
            borderBottomColor = { 245, 245, 245, 255 },
            children = {
                UI.Label { text = label, fontSize = 12, fontColor = C.textSec },
                UI.Label { text = value, fontSize = 12, fontColor = C.text },
            },
        }
    end

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
                flexDirection = "row",
                alignItems = "center",
                paddingHorizontal = 8,
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
                    UI.Label {
                        text = "关于",
                        fontSize = 15,
                        fontColor = C.text,
                        flexGrow = 1,
                        textAlign = "center",
                        marginRight = 30,
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
                        alignItems = "center",
                        paddingBottom = 40,
                        children = {
                            -- Logo 区域
                            UI.Panel {
                                width = "100%",
                                paddingVertical = 30,
                                alignItems = "center",
                                gap = 10,
                                children = {
                                    UI.Panel {
                                        width = 72, height = 72,
                                        backgroundColor = C.blue,
                                        borderRadius = 18,
                                        justifyContent = "center",
                                        alignItems = "center",
                                        children = {
                                            UI.Label { text = "钉", fontSize = 28, fontColor = C.white },
                                        },
                                    },
                                    UI.Label { text = "叮叮", fontSize = 18, fontColor = C.text, fontWeight = "bold" },
                                    UI.Label { text = "让工作学习更简单", fontSize = 11, fontColor = C.textSec },
                                },
                            },

                            UI.Panel {
                                width = "100%",
                                backgroundColor = C.white,
                                flexDirection = "column",
                                children = {
                                    InfoRow("版本号", "v7.6.20 (像素版)"),
                                    InfoRow("构建日期", "2025-03-24"),
                                    InfoRow("引擎", "UrhoX Engine"),
                                    InfoRow("开发者", "陈星河 · 信息技术系"),
                                    InfoRow("学校", "星火市明德职业技术学校"),
                                },
                            },

                            UI.Panel { width = "100%", height = 10 },

                            UI.Panel {
                                width = "100%",
                                backgroundColor = C.white,
                                flexDirection = "column",
                                paddingVertical = 14,
                                paddingHorizontal = 20,
                                gap = 8,
                                children = {
                                    UI.Label { text = "更新日志", fontSize = 13, fontColor = C.text, fontWeight = "bold" },
                                    UI.Label {
                                        text = "· 新增通讯录页面，支持查看组织架构\n· 新增全局搜索功能\n· 待办支持自定义添加、完成切换\n· DING 支持一键已读\n· 新增\"关于\"页面\n· 数据模块化，支持 CSV 调表",
                                        fontSize = 11,
                                        fontColor = C.textSec,
                                        lineHeight = 1.6,
                                    },
                                },
                            },

                            UI.Panel { width = "100%", height = 10 },

                            UI.Panel {
                                width = "100%",
                                backgroundColor = C.white,
                                flexDirection = "column",
                                paddingVertical = 14,
                                paddingHorizontal = 20,
                                gap = 8,
                                children = {
                                    UI.Label { text = "致谢", fontSize = 13, fontColor = C.text, fontWeight = "bold" },
                                    UI.Label {
                                        text = "感谢 UrhoX 引擎团队提供的强大开发框架。\n本应用为像素风格教学演示项目，\n界面仅供学习参考，非官方叮叮产品。",
                                        fontSize = 11,
                                        fontColor = C.textSec,
                                        lineHeight = 1.6,
                                    },
                                },
                            },

                            UI.Panel {
                                width = "100%",
                                paddingVertical = 20,
                                alignItems = "center",
                                children = {
                                    UI.Label {
                                        text = "Made with UrhoX  2025",
                                        fontSize = 10,
                                        fontColor = { 180, 180, 185, 255 },
                                    },
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
