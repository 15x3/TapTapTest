-- ============================================================================
-- 钉钉页面公共模块 (DingTalk Pages Common)
-- 共享颜色常量和辅助组件
-- ============================================================================

local UI = require("urhox-libs/UI")

local M = {}

-- 通用颜色
M.C = {
    blue       = { 48, 118, 255, 255 },
    bg         = { 245, 245, 245, 255 },
    white      = { 255, 255, 255, 255 },
    text       = { 25, 25, 25, 255 },
    textSec    = { 153, 153, 153, 255 },
    border     = { 235, 235, 235, 255 },
    red        = { 250, 80, 80, 255 },
    green      = { 60, 180, 90, 255 },
    orange     = { 255, 160, 50, 255 },
    lightBlue  = { 230, 240, 255, 255 },
}

--- 通用子页面顶栏
---@param title string 页面标题
---@param onBack function 返回回调
---@return table UI.Panel
function M.CreateSubHeader(title, onBack)
    local C = M.C
    return UI.Panel {
        width = "100%",
        height = 44,
        backgroundColor = C.white,
        flexDirection = "row",
        alignItems = "center",
        paddingHorizontal = 12,
        borderBottomWidth = 1,
        borderBottomColor = C.border,
        gap = 8,
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
                text = title,
                fontSize = 14,
                fontColor = C.text,
                flexGrow = 1,
                flexBasis = 0,
            },
        },
    }
end

return M
