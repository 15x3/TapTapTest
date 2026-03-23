-- ============================================================================
-- 手机界面模拟器 - 像素风格 (Phone Interface Simulator - Pixel Art Style)
-- 功能: 像素风手机 UI 界面，居中显示，背景自适应延展
-- UI 系统: urhox-libs/UI (Yoga Flexbox + NanoVG)
-- 字体: zpix 像素字体
-- ============================================================================

local UI = require("urhox-libs/UI")

-- ============================================================================
-- 全局变量
-- ============================================================================
local uiRoot_ = nil

-- 手机配置
local PHONE = {
    WIDTH = 380,
    HEIGHT = 800,
    BORDER_RADIUS = 16,          -- 像素风：减小圆角
    BORDER_WIDTH = 3,            -- 像素风：加粗边框
    STATUS_BAR_HEIGHT = 32,
}

-- 像素风颜色 - 低饱和、复古色调
local COLORS = {
    -- 背景：深色棋盘格感
    BG = { 24, 20, 37, 255 },

    -- 手机外壳
    PHONE_BORDER = { 200, 200, 210, 255 },
    PHONE_BG = { 12, 12, 18, 255 },

    -- 屏幕内容
    SCREEN_BG = { 22, 22, 34, 255 },

    -- 应用图标 - 像素风经典配色
    APP_BLUE   = { 80, 120, 220, 255 },
    APP_GREEN  = { 60, 180, 90, 255 },
    APP_RED    = { 220, 70, 70, 255 },
    APP_YELLOW = { 230, 190, 50, 255 },
    APP_PURPLE = { 150, 80, 200, 255 },
    APP_CYAN   = { 60, 200, 210, 255 },

    -- 文字
    TEXT_WHITE = { 240, 240, 240, 255 },
    TEXT_LIGHT = { 180, 180, 200, 255 },
    TEXT_DIM   = { 100, 100, 130, 255 },

    -- Dock 栏
    DOCK_BG = { 16, 16, 28, 220 },

    -- 像素装饰色
    PIXEL_ACCENT = { 100, 220, 160, 255 },
}

-- 应用数据 - 用文字符号代替 emoji，更像素风
local APPS = {
    { name = "相册",  color = COLORS.APP_BLUE,   symbol = "PIC" },
    { name = "消息",  color = COLORS.APP_GREEN,  symbol = "MSG" },
    { name = "设置",  color = COLORS.APP_RED,    symbol = "SET" },
    { name = "音乐",  color = COLORS.APP_YELLOW, symbol = "BGM" },
    { name = "商店",  color = COLORS.APP_PURPLE, symbol = "SHP" },
    { name = "地图",  color = COLORS.APP_CYAN,   symbol = "MAP" },
}

-- ============================================================================
-- 生命周期
-- ============================================================================

function Start()
    graphics.windowTitle = "Pixel Phone Simulator"

    InitUI()
    CreateUI()
    SubscribeToEvents()

    print("=== Pixel Phone Simulator Started ===")
end

function Stop()
    UI.Shutdown()
end

-- ============================================================================
-- 初始化
-- ============================================================================

function InitUI()
    UI.Init({
        fonts = {
            { family = "sans", weights = {
                normal = "Fonts/zpix.ttf",
            } }
        },
        scale = UI.Scale.DEFAULT,
    })
end

function SubscribeToEvents()
    SubscribeToEvent("Update", "HandleUpdate")
end

-- ============================================================================
-- UI 构建
-- ============================================================================

function CreateUI()
    uiRoot_ = UI.Panel {
        id = "root",
        width = "100%",
        height = "100%",
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = COLORS.BG,
        children = {
            -- 背景像素网格装饰
            CreatePixelBgDecor(),
            -- 手机外壳
            CreatePhoneFrame(),
        },
    }

    UI.SetRoot(uiRoot_)
end

--- 背景像素装饰角标
function CreatePixelBgDecor()
    return UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        pointerEvents = "none",
        children = {
            -- 左上角像素装饰
            UI.Label {
                text = "[ PIXEL OS ]",
                fontSize = 10,
                fontColor = { 60, 60, 80, 120 },
                position = "absolute",
                top = 12, left = 16,
            },
            -- 右下角像素装饰
            UI.Label {
                text = "v1.0",
                fontSize = 10,
                fontColor = { 60, 60, 80, 120 },
                position = "absolute",
                bottom = 12, right = 16,
            },
        },
    }
end

--- 创建手机外壳
function CreatePhoneFrame()
    return UI.Panel {
        id = "phoneFrame",
        height = "90%",
        maxHeight = PHONE.HEIGHT,
        aspectRatio = PHONE.WIDTH / PHONE.HEIGHT,
        backgroundColor = COLORS.PHONE_BG,
        borderRadius = PHONE.BORDER_RADIUS,
        borderWidth = PHONE.BORDER_WIDTH,
        borderColor = COLORS.PHONE_BORDER,
        overflow = "hidden",
        flexDirection = "column",
        boxShadow = {
            { x = 0, y = 6, blur = 30, spread = 0, color = { 0, 0, 0, 150 } },
        },
        children = {
            -- 听筒区域（紧贴圆角内部，无突出）
            CreateEarpieceBar(),
            -- 状态栏
            CreateStatusBar(),
            -- 屏幕主内容
            CreateScreenContent(),
            -- 底部 Dock
            CreateDockBar(),
        },
    }
end

--- 听筒区域（取代刘海，紧贴顶部圆角内侧）
function CreateEarpieceBar()
    return UI.Panel {
        width = "100%",
        height = 24,
        backgroundColor = COLORS.SCREEN_BG,
        justifyContent = "center",
        alignItems = "center",
        children = {
            -- 听筒像素块
            UI.Panel {
                width = 50,
                height = 4,
                backgroundColor = { 50, 50, 65, 255 },
                borderRadius = 0,    -- 像素风：无圆角
            },
        },
    }
end

--- 状态栏
function CreateStatusBar()
    return UI.Panel {
        width = "100%",
        height = PHONE.STATUS_BAR_HEIGHT,
        backgroundColor = COLORS.SCREEN_BG,
        flexDirection = "row",
        justifyContent = "space-between",
        alignItems = "center",
        paddingHorizontal = 16,
        children = {
            -- 左侧
            UI.Label {
                text = "手机界面",
                fontSize = 12,
                fontColor = COLORS.TEXT_WHITE,
            },
            -- 右侧：时间 + 电量
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                gap = 8,
                children = {
                    UI.Label {
                        id = "timeLabel",
                        text = GetCurrentTime(),
                        fontSize = 12,
                        fontColor = COLORS.TEXT_WHITE,
                    },
                    -- 像素风电池图标
                    CreatePixelBattery(),
                },
            },
        },
    }
end

--- 像素风电池图标
function CreatePixelBattery()
    return UI.Panel {
        flexDirection = "row",
        alignItems = "center",
        gap = 1,
        children = {
            UI.Panel {
                width = 18, height = 10,
                borderWidth = 1,
                borderColor = COLORS.TEXT_WHITE,
                borderRadius = 0,
                padding = 1,
                flexDirection = "row",
                gap = 1,
                children = {
                    UI.Panel { width = 4, height = "100%", backgroundColor = COLORS.PIXEL_ACCENT, borderRadius = 0 },
                    UI.Panel { width = 4, height = "100%", backgroundColor = COLORS.PIXEL_ACCENT, borderRadius = 0 },
                    UI.Panel { width = 4, height = "100%", backgroundColor = COLORS.PIXEL_ACCENT, borderRadius = 0 },
                },
            },
            UI.Panel { width = 2, height = 5, backgroundColor = COLORS.TEXT_WHITE, borderRadius = 0 },
        },
    }
end

--- 屏幕主内容
function CreateScreenContent()
    return UI.Panel {
        width = "100%",
        flexGrow = 1,
        flexBasis = 0,
        backgroundColor = COLORS.SCREEN_BG,
        flexDirection = "column",
        justifyContent = "flex-start",
        alignItems = "center",
        paddingTop = 30,
        paddingHorizontal = 16,
        gap = 20,
        children = {
            -- 大时钟
            CreatePixelClock(),
            -- 分隔线
            CreatePixelDivider(),
            -- 应用图标网格 (2行3列)
            CreateAppGrid(),
        },
    }
end

--- 像素风大时钟
function CreatePixelClock()
    return UI.Panel {
        alignItems = "center",
        gap = 6,
        children = {
            UI.Label {
                id = "clockLabel",
                text = GetCurrentTime(),
                fontSize = 48,
                fontColor = COLORS.TEXT_WHITE,
            },
            UI.Label {
                id = "dateLabel",
                text = GetCurrentDate(),
                fontSize = 12,
                fontColor = COLORS.TEXT_DIM,
            },
        },
    }
end

--- 像素风分隔线
function CreatePixelDivider()
    return UI.Panel {
        width = "70%",
        height = 2,
        backgroundColor = { 50, 50, 70, 255 },
        borderRadius = 0,
        marginVertical = 4,
    }
end

--- 应用图标网格
function CreateAppGrid()
    local row1 = {}
    local row2 = {}
    for i, app in ipairs(APPS) do
        if i <= 3 then
            row1[#row1 + 1] = CreatePixelAppIcon(app)
        else
            row2[#row2 + 1] = CreatePixelAppIcon(app)
        end
    end

    return UI.Panel {
        flexDirection = "column",
        alignItems = "center",
        gap = 16,
        marginTop = 8,
        children = {
            UI.Panel { flexDirection = "row", gap = 24, children = row1 },
            UI.Panel { flexDirection = "row", gap = 24, children = row2 },
        },
    }
end

--- 像素风应用图标
function CreatePixelAppIcon(app)
    return UI.Panel {
        alignItems = "center",
        gap = 6,
        children = {
            -- 图标方块（像素风：无圆角，粗边框）
            UI.Button {
                width = 56,
                height = 56,
                backgroundColor = app.color,
                borderRadius = 4,          -- 微圆角，保持像素感
                borderWidth = 2,
                borderColor = { 255, 255, 255, 40 },
                justifyContent = "center",
                alignItems = "center",
                textColor = COLORS.TEXT_WHITE,
                text = app.symbol,
                fontSize = 12,
                onClick = function(self)
                    print(">>> " .. app.name)
                end,
            },
            -- 应用名
            UI.Label {
                text = app.name,
                fontSize = 10,
                fontColor = COLORS.TEXT_LIGHT,
            },
        },
    }
end

--- 底部 Dock 栏
function CreateDockBar()
    return UI.Panel {
        width = "100%",
        height = 50,
        backgroundColor = COLORS.DOCK_BG,
        justifyContent = "center",
        alignItems = "center",
        children = {
            -- 像素风主页按钮：方块
            UI.Panel {
                width = 36,
                height = 6,
                backgroundColor = COLORS.TEXT_LIGHT,
                borderRadius = 0,    -- 像素风：方角
            },
        },
    }
end

-- ============================================================================
-- 时间
-- ============================================================================

function GetCurrentTime()
    local t = os.date("*t")
    return string.format("%02d:%02d", t.hour, t.min)
end

function GetCurrentDate()
    local t = os.date("*t")
    local weekdays = { "周日", "周一", "周二", "周三", "周四", "周五", "周六" }
    return string.format("%d月%d日 %s", t.month, t.day, weekdays[t.wday])
end

-- ============================================================================
-- 更新
-- ============================================================================

local lastMinute_ = -1

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local t = os.date("*t")
    if t.min ~= lastMinute_ then
        lastMinute_ = t.min
        local timeStr = GetCurrentTime()
        local dateStr = GetCurrentDate()

        local timeLabel = uiRoot_:FindById("timeLabel")
        if timeLabel then timeLabel:SetText(timeStr) end

        local clockLabel = uiRoot_:FindById("clockLabel")
        if clockLabel then clockLabel:SetText(timeStr) end

        local dateLabel = uiRoot_:FindById("dateLabel")
        if dateLabel then dateLabel:SetText(dateStr) end
    end
end
