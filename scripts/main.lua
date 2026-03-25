-- ============================================================================
-- 手机界面模拟器 - 像素风格 (Phone Interface Simulator - Pixel Art Style)
-- 功能: 像素风手机 UI 界面，居中显示，背景自适应延展
-- UI 系统: urhox-libs/UI (Yoga Flexbox + NanoVG)
-- 字体: zpix 像素字体
-- 支持: 钉钉、微信应用打开与浏览
-- ============================================================================

local UI = require("urhox-libs/UI")
local DingtalkApp = require("DingtalkApp")
local WechatApp = require("WechatApp")

-- ============================================================================
-- 全局变量
-- ============================================================================
local uiRoot_ = nil
---@type string|nil
local currentApp_ = nil  -- nil = 主屏幕, "dingtalk"/"wechat" = 应用内
local phoneFrame_ = nil
local screenContainer_ = nil  -- 屏幕内容容器（用于切换主屏/应用）

-- 手机配置
local PHONE = {
    WIDTH = 380,
    HEIGHT = 800,
    BORDER_RADIUS = 16,
    BORDER_WIDTH = 3,
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

    -- 应用图标颜色
    APP_DINGTALK = { 48, 118, 255, 255 },   -- 钉钉蓝
    APP_WECHAT   = { 7, 193, 96, 255 },     -- 微信绿
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

    -- 浅色主题（应用内使用）
    WHITE = { 255, 255, 255, 255 },
    LIGHT_BG = { 237, 237, 237, 255 },
    LIGHT_TEXT = { 25, 25, 25, 255 },
    LIGHT_TEXT_SEC = { 128, 128, 128, 255 },
    LIGHT_BORDER = { 225, 225, 225, 255 },
}

-- 应用数据
local APPS = {
    { name = "钉钉",     color = COLORS.APP_DINGTALK, symbol = "DD",  appId = "dingtalk" },
    { name = "微信",     color = COLORS.APP_WECHAT,   symbol = "WX",  appId = "wechat" },
    { name = "我的课表", color = COLORS.APP_YELLOW,    symbol = "KB",  appId = "schedule" },
    { name = "商店",     color = COLORS.APP_PURPLE,    symbol = "SHP", appId = nil },
    { name = "地图",     color = COLORS.APP_CYAN,      symbol = "MAP", appId = "map" },
    { name = "设置",     color = COLORS.APP_RED,       symbol = "SET", appId = "settings" },
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
-- 导航系统
-- ============================================================================

--- 打开应用
function OpenApp(appId)
    if not screenContainer_ then return end
    currentApp_ = appId
    screenContainer_:ClearChildren()

    local appNames = {
        dingtalk = "钉钉",
        wechat   = "微信",
        settings = "设置",
        schedule = "我的课表",
        map      = "地图",
    }

    if appId == "dingtalk" then
        screenContainer_:AddChild(DingtalkApp.Create(GoHome))
    elseif appId == "wechat" then
        screenContainer_:AddChild(WechatApp.Create(GoHome))
    elseif appId == "settings" then
        screenContainer_:AddChild(CreateSettingsApp())
    elseif appId == "schedule" then
        screenContainer_:AddChild(CreateScheduleApp())
    elseif appId == "map" then
        screenContainer_:AddChild(CreateMapApp())
    end

    -- 更新状态栏标题
    local titleLabel = uiRoot_:FindById("statusTitle")
    if titleLabel then
        titleLabel:SetText(appNames[appId] or appId)
    end

    print(">>> 打开应用: " .. appId)
end

--- 返回主屏幕
function GoHome()
    if not screenContainer_ then return end
    currentApp_ = nil
    screenContainer_:ClearChildren()
    screenContainer_:AddChild(CreateHomeContent())

    local titleLabel = uiRoot_:FindById("statusTitle")
    if titleLabel then
        titleLabel:SetText("手机界面")
    end

    print(">>> 返回主屏幕")
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
            CreatePixelBgDecor(),
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
            UI.Label {
                text = "[ PIXEL OS ]",
                fontSize = 10,
                fontColor = { 60, 60, 80, 120 },
                position = "absolute",
                top = 12, left = 16,
            },
            UI.Label {
                text = "v2.0",
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
    screenContainer_ = UI.Panel {
        id = "screenContainer",
        width = "100%",
        flexGrow = 1,
        flexBasis = 0,
        flexDirection = "column",
        overflow = "hidden",
        children = {
            CreateHomeContent(),
        },
    }

    phoneFrame_ = UI.Panel {
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
            CreateEarpieceBar(),
            CreateStatusBar(),
            screenContainer_,
            CreateDockBar(),
        },
    }

    return phoneFrame_
end

--- 听筒区域
function CreateEarpieceBar()
    return UI.Panel {
        width = "100%",
        height = 24,
        backgroundColor = COLORS.SCREEN_BG,
        justifyContent = "center",
        alignItems = "center",
        children = {
            UI.Panel {
                width = 50,
                height = 4,
                backgroundColor = { 50, 50, 65, 255 },
                borderRadius = 0,
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
            UI.Label {
                id = "statusTitle",
                text = "手机界面",
                fontSize = 12,
                fontColor = COLORS.TEXT_WHITE,
            },
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

--- 底部 Dock 栏（点击返回主屏）
function CreateDockBar()
    return UI.Panel {
        width = "100%",
        height = 50,
        backgroundColor = COLORS.DOCK_BG,
        justifyContent = "center",
        alignItems = "center",
        children = {
            UI.Button {
                width = 80,
                height = 30,
                backgroundColor = { 0, 0, 0, 0 },
                hoverBackgroundColor = { 255, 255, 255, 20 },
                pressedBackgroundColor = { 255, 255, 255, 40 },
                borderRadius = 4,
                justifyContent = "center",
                alignItems = "center",
                onClick = function(self)
                    if currentApp_ then
                        GoHome()
                    end
                end,
                children = {
                    UI.Panel {
                        width = 36,
                        height = 6,
                        backgroundColor = COLORS.TEXT_LIGHT,
                        borderRadius = 0,
                        pointerEvents = "none",
                    },
                },
            },
        },
    }
end

-- ============================================================================
-- 主屏幕内容
-- ============================================================================

function CreateHomeContent()
    return UI.Panel {
        width = "100%",
        height = "100%",
        backgroundColor = COLORS.SCREEN_BG,
        flexDirection = "column",
        justifyContent = "flex-start",
        alignItems = "center",
        paddingTop = 30,
        paddingHorizontal = 16,
        gap = 20,
        children = {
            CreatePixelClock(),
            CreatePixelDivider(),
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
            UI.Button {
                width = 56,
                height = 56,
                backgroundColor = app.color,
                borderRadius = 4,
                borderWidth = 2,
                borderColor = { 255, 255, 255, 40 },
                justifyContent = "center",
                alignItems = "center",
                textColor = COLORS.TEXT_WHITE,
                text = app.symbol,
                fontSize = 12,
                onClick = function(self)
                    if app.appId then
                        OpenApp(app.appId)
                    else
                        print(">>> " .. app.name .. " (未实现)")
                    end
                end,
            },
            UI.Label {
                text = app.name,
                fontSize = 10,
                fontColor = COLORS.TEXT_LIGHT,
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
-- 设置应用
-- ============================================================================

--- Toast 提示（简易实现，显示一个覆盖层，2秒后自动消失）
local toastTimer_ = 0
local toastPanel_ = nil
local toastActive_ = false

function ShowToast(message)
    if toastPanel_ then
        local label = toastPanel_:FindById("toastText")
        if label then label:SetText(message) end
        toastPanel_:SetVisible(true)
        toastActive_ = true
        toastTimer_ = 2.0
    end
end

function CreateSettingsApp()
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

    --- 菜单项
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
                        onClick = function(self) GoHome() end,
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

                            -- 存档
                            SettingsItem("S", { 60, 160, 230, 255 }, "存档", function()
                                ShowToast("存档成功")
                                print(">>> 设置: 存档成功")
                            end),

                            -- 读档
                            SettingsItem("L", { 100, 180, 80, 255 }, "读档", function()
                                ShowToast("读档成功")
                                print(">>> 设置: 读档成功")
                            end),

                            UI.Panel { width = "100%", height = 12, backgroundColor = bg },

                            -- 关于
                            SettingsItem("i", { 150, 150, 170, 255 }, "关于", function()
                                ShowToast("Pixel Phone v2.0")
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
                                            print(">>> 退出游戏")
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

-- ============================================================================
-- 我的课表应用
-- ============================================================================

-- 课表数据（内存存储，可编辑）
local scheduleData_ = nil

local function initScheduleData()
    if scheduleData_ then return end
    -- 默认课表数据：周一到周五，每天8节课
    -- 空字符串表示没有课
    local DAYS = { "周一", "周二", "周三", "周四", "周五" }
    local PERIODS = 8
    scheduleData_ = {
        days = DAYS,
        periods = PERIODS,
        -- data[period][day] = 课程名
        data = {},
        periodTimes = {
            "08:00", "09:00", "10:10", "11:10",
            "14:00", "15:00", "16:10", "17:10",
        },
    }
    for p = 1, PERIODS do
        scheduleData_.data[p] = {}
        for d = 1, #DAYS do
            scheduleData_.data[p][d] = ""
        end
    end
    -- 预填一些默认课程
    scheduleData_.data[1][1] = "高数"
    scheduleData_.data[2][1] = "高数"
    scheduleData_.data[1][2] = "英语"
    scheduleData_.data[3][2] = "物理"
    scheduleData_.data[1][3] = "编程"
    scheduleData_.data[2][3] = "编程"
    scheduleData_.data[4][3] = "体育"
    scheduleData_.data[1][4] = "英语"
    scheduleData_.data[3][4] = "物理"
    scheduleData_.data[5][4] = "数据结构"
    scheduleData_.data[1][5] = "线代"
    scheduleData_.data[2][5] = "线代"
    scheduleData_.data[5][1] = "大学物理"
    scheduleData_.data[6][2] = "思政"
    scheduleData_.data[5][5] = "选修课"
end

--- 课程颜色映射（根据课程名哈希分配颜色）
local COURSE_COLORS = {
    { 76, 140, 230, 200 },
    { 100, 190, 100, 200 },
    { 230, 140, 60, 200 },
    { 190, 90, 190, 200 },
    { 60, 180, 180, 200 },
    { 220, 90, 90, 200 },
    { 160, 140, 60, 200 },
    { 90, 120, 200, 200 },
}

local function getCourseColor(name)
    if not name or name == "" then return nil end
    local hash = 0
    for i = 1, #name do
        hash = hash + string.byte(name, i)
    end
    return COURSE_COLORS[(hash % #COURSE_COLORS) + 1]
end

-- 编辑模式的状态
local scheduleEditCell_ = nil  -- {period, day} 当前正在编辑的单元格
local scheduleContainer_ = nil  -- 课表内容容器，用于刷新

function CreateScheduleApp()
    initScheduleData()
    scheduleEditCell_ = nil

    local headerBg = { 237, 237, 237, 255 }
    local white = { 255, 255, 255, 255 }
    local textColor = { 25, 25, 25, 255 }
    local textSec = { 153, 153, 153, 255 }
    local bg = { 237, 237, 237, 255 }

    scheduleContainer_ = UI.Panel {
        id = "scheduleContent",
        width = "100%",
        flexGrow = 1,
        flexBasis = 0,
        flexDirection = "column",
        overflow = "hidden",
    }

    RefreshScheduleGrid()

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
                        onClick = function(self) GoHome() end,
                    },
                    UI.Label { text = "我的课表", fontSize = 14, fontColor = textColor },
                    UI.Panel { width = 30, height = 30 },
                },
            },
            -- 课表内容
            scheduleContainer_,
        },
    }
end

function RefreshScheduleGrid()
    if not scheduleContainer_ then return end
    scheduleContainer_:ClearChildren()

    local sd = scheduleData_
    local white = { 255, 255, 255, 255 }
    local textColor = { 25, 25, 25, 255 }
    local textSec = { 120, 120, 140, 255 }
    local bg = { 237, 237, 237, 255 }

    local CELL_H = 48
    local TIME_W = 38
    local dayCount = #sd.days

    -- 星期标题行
    local headerCells = {
        UI.Panel {
            width = TIME_W,
            height = 28,
            justifyContent = "center",
            alignItems = "center",
            backgroundColor = { 230, 230, 240, 255 },
            children = {
                UI.Label { text = "节", fontSize = 9, fontColor = textSec },
            },
        },
    }
    for d = 1, dayCount do
        headerCells[#headerCells + 1] = UI.Panel {
            flexGrow = 1,
            flexBasis = 0,
            height = 28,
            justifyContent = "center",
            alignItems = "center",
            backgroundColor = { 230, 230, 240, 255 },
            borderLeftWidth = 1,
            borderLeftColor = { 210, 210, 220, 255 },
            children = {
                UI.Label { text = sd.days[d], fontSize = 9, fontColor = textColor },
            },
        }
    end

    local headerRow = UI.Panel {
        width = "100%",
        flexDirection = "row",
        borderBottomWidth = 1,
        borderBottomColor = { 200, 200, 210, 255 },
        children = headerCells,
    }

    -- 课程网格
    local gridRows = {}
    for p = 1, sd.periods do
        local rowCells = {
            -- 节次+时间列
            UI.Panel {
                width = TIME_W,
                height = CELL_H,
                justifyContent = "center",
                alignItems = "center",
                backgroundColor = { 245, 245, 250, 255 },
                flexDirection = "column",
                gap = 1,
                children = {
                    UI.Label { text = tostring(p), fontSize = 10, fontColor = textColor },
                    UI.Label { text = sd.periodTimes[p] or "", fontSize = 7, fontColor = textSec },
                },
            },
        }
        for d = 1, dayCount do
            local courseName = sd.data[p][d] or ""
            local cellBg = white
            local cellChildren = {}

            if scheduleEditCell_ and scheduleEditCell_[1] == p and scheduleEditCell_[2] == d then
                -- 编辑模式：显示输入框
                local periodRef, dayRef = p, d
                cellChildren[#cellChildren + 1] = UI.TextField {
                    width = "100%",
                    height = "100%",
                    fontSize = 9,
                    value = courseName,
                    placeholder = "课程",
                    backgroundColor = { 255, 255, 230, 255 },
                    borderRadius = 0,
                    paddingHorizontal = 2,
                    onSubmit = function(self, value)
                        scheduleData_.data[periodRef][dayRef] = value
                        scheduleEditCell_ = nil
                        RefreshScheduleGrid()
                    end,
                }
            elseif courseName ~= "" then
                -- 有课程：显示课程名
                local cc = getCourseColor(courseName)
                cellBg = cc or { 200, 220, 255, 200 }
                cellChildren[#cellChildren + 1] = UI.Label {
                    text = courseName,
                    fontSize = 9,
                    fontColor = { 255, 255, 255, 255 },
                    textAlign = "center",
                    maxLines = 2,
                    pointerEvents = "none",
                }
            end

            local periodRef, dayRef = p, d
            rowCells[#rowCells + 1] = UI.Button {
                flexGrow = 1,
                flexBasis = 0,
                height = CELL_H,
                backgroundColor = cellBg,
                hoverBackgroundColor = { 240, 240, 250, 255 },
                pressedBackgroundColor = { 230, 230, 245, 255 },
                borderRadius = 0,
                borderLeftWidth = 1,
                borderLeftColor = { 230, 230, 240, 255 },
                justifyContent = "center",
                alignItems = "center",
                onClick = function(self)
                    scheduleEditCell_ = { periodRef, dayRef }
                    RefreshScheduleGrid()
                end,
                children = cellChildren,
            }
        end

        gridRows[#gridRows + 1] = UI.Panel {
            width = "100%",
            flexDirection = "row",
            borderBottomWidth = 1,
            borderBottomColor = { 235, 235, 240, 255 },
            children = rowCells,
        }
    end

    local scrollContent = UI.ScrollView {
        width = "100%",
        flexGrow = 1,
        flexBasis = 0,
        children = {
            UI.Panel {
                width = "100%",
                flexDirection = "column",
                children = gridRows,
            },
        },
    }

    scheduleContainer_:AddChild(headerRow)
    scheduleContainer_:AddChild(scrollContent)
end

-- ============================================================================
-- 地图应用
-- ============================================================================

function CreateMapApp()
    local headerBg = { 237, 237, 237, 255 }
    local white = { 255, 255, 255, 255 }
    local textColor = { 25, 25, 25, 255 }
    local textSec = { 153, 153, 153, 255 }
    local bg = { 237, 237, 237, 255 }

    -- 地图上的标记点
    local markers = {
        { name = "教学楼A", x = 0.35, y = 0.30, color = { 220, 70, 70, 255 } },
        { name = "图书馆",   x = 0.55, y = 0.25, color = { 60, 140, 220, 255 } },
        { name = "食堂",     x = 0.40, y = 0.55, color = { 240, 160, 40, 255 } },
        { name = "体育馆",   x = 0.70, y = 0.50, color = { 80, 190, 80, 255 } },
        { name = "宿舍楼",   x = 0.25, y = 0.70, color = { 160, 100, 200, 255 } },
        { name = "校门",     x = 0.50, y = 0.88, color = { 100, 100, 120, 255 } },
        { name = "实验楼",   x = 0.72, y = 0.30, color = { 200, 100, 60, 255 } },
        { name = "操场",     x = 0.65, y = 0.68, color = { 60, 180, 120, 255 } },
    }

    -- 道路数据（用 Panel 模拟）
    local roads = {
        -- 横向主路
        { x = "8%", y = "45%", w = "84%", h = 4, color = { 200, 200, 200, 255 } },
        -- 纵向主路
        { x = "48%", y = "10%", w = 4, h = "80%", color = { 200, 200, 200, 255 } },
        -- 次要道路
        { x = "20%", y = "25%", w = "30%", h = 3, color = { 215, 215, 215, 255 } },
        { x = "55%", y = "65%", w = "25%", h = 3, color = { 215, 215, 215, 255 } },
        { x = "30%", y = "30%", w = 3, h = "40%", color = { 215, 215, 215, 255 } },
    }

    -- 绿地区域
    local greenAreas = {
        { x = "12%", y = "38%", w = "15%", h = "12%", color = { 180, 220, 160, 120 } },
        { x = "58%", y = "55%", w = "22%", h = "22%", color = { 180, 220, 160, 120 } },
    }

    -- 构建地图内容
    local mapChildren = {}

    -- 绿地
    for _, g in ipairs(greenAreas) do
        mapChildren[#mapChildren + 1] = UI.Panel {
            position = "absolute",
            left = g.x, top = g.y,
            width = g.w, height = g.h,
            backgroundColor = g.color,
            borderRadius = 4,
            pointerEvents = "none",
        }
    end

    -- 道路
    for _, r in ipairs(roads) do
        mapChildren[#mapChildren + 1] = UI.Panel {
            position = "absolute",
            left = r.x, top = r.y,
            width = r.w, height = r.h,
            backgroundColor = r.color,
            borderRadius = 1,
            pointerEvents = "none",
        }
    end

    -- 标记点
    for _, m in ipairs(markers) do
        local leftPct = string.format("%.0f%%", m.x * 100 - 4)
        local topPct  = string.format("%.0f%%", m.y * 100 - 4)
        mapChildren[#mapChildren + 1] = UI.Panel {
            position = "absolute",
            left = leftPct,
            top = topPct,
            alignItems = "center",
            gap = 2,
            pointerEvents = "none",
            children = {
                -- 标记圆点
                UI.Panel {
                    width = 18, height = 18,
                    backgroundColor = m.color,
                    borderRadius = 9,
                    borderWidth = 2,
                    borderColor = { 255, 255, 255, 255 },
                    justifyContent = "center",
                    alignItems = "center",
                    boxShadow = {
                        { x = 0, y = 1, blur = 3, spread = 0, color = { 0, 0, 0, 60 } },
                    },
                },
                -- 标签名称
                UI.Panel {
                    paddingHorizontal = 4, paddingVertical = 2,
                    backgroundColor = { 255, 255, 255, 220 },
                    borderRadius = 3,
                    boxShadow = {
                        { x = 0, y = 1, blur = 2, spread = 0, color = { 0, 0, 0, 40 } },
                    },
                    children = {
                        UI.Label { text = m.name, fontSize = 8, fontColor = textColor },
                    },
                },
            },
        }
    end

    -- 指南针
    mapChildren[#mapChildren + 1] = UI.Panel {
        position = "absolute",
        top = 8, right = 8,
        width = 28, height = 28,
        backgroundColor = { 255, 255, 255, 220 },
        borderRadius = 14,
        borderWidth = 1,
        borderColor = { 200, 200, 200, 255 },
        justifyContent = "center",
        alignItems = "center",
        pointerEvents = "none",
        children = {
            UI.Label { text = "N", fontSize = 10, fontColor = { 220, 60, 60, 255 } },
        },
    }

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
                        onClick = function(self) GoHome() end,
                    },
                    UI.Label { text = "校园地图", fontSize = 14, fontColor = textColor },
                    UI.Panel { width = 30, height = 30 },
                },
            },
            -- 搜索栏
            UI.Panel {
                width = "100%",
                height = 36,
                backgroundColor = headerBg,
                paddingHorizontal = 10,
                paddingBottom = 6,
                children = {
                    UI.Panel {
                        width = "100%",
                        height = "100%",
                        backgroundColor = white,
                        borderRadius = 4,
                        justifyContent = "center",
                        alignItems = "center",
                        children = {
                            UI.Label { text = "搜索地点...", fontSize = 11, fontColor = { 180, 180, 180, 255 } },
                        },
                    },
                },
            },
            -- 地图区域
            UI.Panel {
                width = "100%",
                flexGrow = 1,
                flexBasis = 0,
                backgroundColor = { 235, 245, 230, 255 },  -- 浅绿色底图
                overflow = "hidden",
                children = mapChildren,
            },
            -- 底部信息栏
            UI.Panel {
                width = "100%",
                height = 36,
                backgroundColor = white,
                flexDirection = "row",
                justifyContent = "center",
                alignItems = "center",
                borderTopWidth = 1,
                borderTopColor = { 220, 220, 220, 255 },
                gap = 16,
                children = {
                    UI.Label { text = "共 " .. #markers .. " 个地点", fontSize = 10, fontColor = textSec },
                    UI.Panel { width = 1, height = 14, backgroundColor = { 200, 200, 200, 255 } },
                    UI.Label { text = "校园导览", fontSize = 10, fontColor = textSec },
                },
            },
        },
    }
end

-- ============================================================================
-- 更新
-- ============================================================================

local lastMinute_ = -1

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()

    -- Toast 自动消失
    if toastActive_ then
        toastTimer_ = toastTimer_ - dt
        if toastTimer_ <= 0 then
            toastActive_ = false
            if toastPanel_ then
                toastPanel_:SetVisible(false)
            end
        end
    end

    local t = os.date("*t")
    if t.min ~= lastMinute_ then
        lastMinute_ = t.min
        local timeStr = GetCurrentTime()
        local dateStr = GetCurrentDate()

        local timeLabel = uiRoot_:FindById("timeLabel")
        if timeLabel then timeLabel:SetText(timeStr) end

        -- 仅在主屏幕时更新时钟
        if not currentApp_ then
            local clockLabel = uiRoot_:FindById("clockLabel")
            if clockLabel then clockLabel:SetText(timeStr) end

            local dateLabel = uiRoot_:FindById("dateLabel")
            if dateLabel then dateLabel:SetText(dateStr) end
        end
    end
end
