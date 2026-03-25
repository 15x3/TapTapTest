-- ============================================================================
-- 设置应用模块 (Settings App)
-- ============================================================================

local UI = require("urhox-libs/UI")
local Log = require("Utils.Logger")

local M = {}

-- Toast 状态
local toastTimer_ = 0
local toastPanel_ = nil
local toastActive_ = false

--- 显示 Toast 提示（2秒后自动消失）
---@param message string
function M.ShowToast(message)
    if toastPanel_ then
        local label = toastPanel_:FindById("toastText")
        if label then label:SetText(message) end
        toastPanel_:SetVisible(true)
        toastActive_ = true
        toastTimer_ = 2.0
    end
end

--- Update 中调用：驱动 Toast 自动消失
---@param dt number
function M.UpdateToast(dt)
    if toastActive_ then
        toastTimer_ = toastTimer_ - dt
        if toastTimer_ <= 0 then
            toastActive_ = false
            if toastPanel_ then
                toastPanel_:SetVisible(false)
            end
        end
    end
end

--- 创建设置应用 UI
---@param onBack function 返回主屏回调
---@return table UI.Panel
function M.Create(onBack)
    -- Toast 覆盖层
    toastPanel_ = UI.Panel {
        id = "toastOverlay",
        position = "absolute",
        bottom = 100,
        left = 0, right = 0,
        alignItems = "center",
        pointerEvents = "none",
        visible = false,
        children = {
            UI.Panel {
                paddingHorizontal = 20,
                paddingVertical = 10,
                backgroundColor = { 0, 0, 0, 180 },
                borderRadius = 8,
                children = {
                    UI.Label {
                        id = "toastText",
                        text = "",
                        fontSize = 12,
                        fontColor = { 255, 255, 255, 255 },
                    },
                },
            },
        },
    }

    local headerBg = { 237, 237, 237, 255 }
    local white = { 255, 255, 255, 255 }
    local textColor = { 25, 25, 25, 255 }
    local textSec = { 153, 153, 153, 255 }
    local bg = { 237, 237, 237, 255 }
    local red = { 220, 60, 60, 255 }

    --- 设置菜单项
    local function SettingsItem(iconText, iconBg, label, onClick)
        return UI.Button {
            width = "100%",
            height = 52,
            backgroundColor = white,
            hoverBackgroundColor = { 245, 245, 245, 255 },
            pressedBackgroundColor = { 235, 235, 235, 255 },
            borderRadius = 0,
            flexDirection = "row",
            alignItems = "center",
            paddingHorizontal = 14,
            gap = 12,
            borderBottomWidth = 1,
            borderBottomColor = { 240, 240, 240, 255 },
            onClick = function(self)
                if onClick then onClick() end
            end,
            children = {
                UI.Panel {
                    width = 28, height = 28,
                    backgroundColor = iconBg,
                    borderRadius = 6,
                    justifyContent = "center",
                    alignItems = "center",
                    pointerEvents = "none",
                    children = {
                        UI.Label { text = iconText, fontSize = 11, fontColor = { 255, 255, 255, 255 } },
                    },
                },
                UI.Label {
                    text = label,
                    fontSize = 13,
                    fontColor = textColor,
                    flexGrow = 1,
                    pointerEvents = "none",
                },
                UI.Label {
                    text = ">",
                    fontSize = 13,
                    fontColor = textSec,
                    pointerEvents = "none",
                },
            },
        }
    end

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
                    UI.Label { text = "设置", fontSize = 14, fontColor = textColor },
                    UI.Panel { width = 30, height = 30 },
                },
            },
            -- 设置列表
            UI.ScrollView {
                width = "100%",
                flexGrow = 1,
                flexBasis = 0,
                children = {
                    UI.Panel {
                        width = "100%",
                        flexDirection = "column",
                        children = {
                            UI.Panel { width = "100%", height = 12, backgroundColor = bg },

                            SettingsItem("S", { 60, 160, 230, 255 }, "存档", function()
                                M.ShowToast("存档成功")
                                Log.info("Settings", "存档成功")
                            end),

                            SettingsItem("L", { 100, 180, 80, 255 }, "读档", function()
                                M.ShowToast("读档成功")
                                Log.info("Settings", "读档成功")
                            end),

                            UI.Panel { width = "100%", height = 12, backgroundColor = bg },

                            SettingsItem("i", { 150, 150, 170, 255 }, "关于", function()
                                M.ShowToast("Pixel Phone v2.0")
                            end),

                            UI.Panel { width = "100%", height = 24, backgroundColor = bg },

                            -- 退出游戏
                            UI.Panel {
                                width = "100%",
                                paddingHorizontal = 16,
                                children = {
                                    UI.Button {
                                        width = "100%",
                                        height = 44,
                                        backgroundColor = red,
                                        hoverBackgroundColor = { 200, 50, 50, 255 },
                                        pressedBackgroundColor = { 180, 40, 40, 255 },
                                        borderRadius = 6,
                                        text = "退出游戏",
                                        textColor = white,
                                        fontSize = 14,
                                        onClick = function(self)
                                            Log.info("Settings", "退出游戏")
                                            engine:Exit()
                                        end,
                                    },
                                },
                            },

                            UI.Panel { width = "100%", height = 30, backgroundColor = bg },
                        },
                    },
                },
            },
            -- Toast 层
            toastPanel_,
        },
    }
end

return M
