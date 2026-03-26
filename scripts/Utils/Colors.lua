-- ============================================================================
-- 颜色工具公共模块 (Color Utility)
-- 功能: 统一的颜色预设映射和解析，供所有模块复用
-- ============================================================================

local Colors = {}

-- ============================================================================
-- 公共颜色预设（合并叮叮和微言的颜色集）
-- ============================================================================

Colors.PRESETS = {
    -- 通用色
    blue       = { 48, 118, 255, 255 },
    red        = { 220, 60, 60, 255 },
    gray       = { 100, 100, 120, 255 },
    orange     = { 255, 140, 0, 255 },
    green      = { 60, 180, 80, 255 },
    dark_blue  = { 80, 120, 200, 255 },
    light_blue = { 100, 130, 200, 255 },
    purple     = { 200, 80, 200, 255 },
    -- 微言额外色
    pink       = { 180, 130, 170, 255 },
    teal       = { 60, 140, 180, 255 },
    yellow     = { 230, 190, 50, 255 },
    wechat_green = { 7, 193, 96, 255 },
}

--- 将颜色名称转为 RGBA 表
---@param name string|nil 颜色名称（如 "blue"、"red"）
---@return table|nil RGBA 数组 { r, g, b, a }
function Colors.Resolve(name)
    if not name or name == "" then return nil end
    return Colors.PRESETS[name]
end

-- ============================================================================
-- 头像颜色生成（根据字符哈希分配颜色）
-- ============================================================================

Colors.AVATAR_PALETTE = {
    { 80, 130, 220, 255 },
    { 200, 90, 90, 255 },
    { 60, 170, 100, 255 },
    { 180, 120, 60, 255 },
    { 140, 80, 200, 255 },
    { 60, 170, 180, 255 },
    { 200, 80, 160, 255 },
}

--- 根据字符串哈希获取一个头像颜色
---@param text string 用于哈希的文本（通常是名字或首字母）
---@return table RGBA 颜色
function Colors.GetAvatarColor(text)
    if not text or text == "" then return Colors.AVATAR_PALETTE[1] end
    local seed = string.byte(text, 1) or 65
    return Colors.AVATAR_PALETTE[(seed % #Colors.AVATAR_PALETTE) + 1]
end

return Colors
