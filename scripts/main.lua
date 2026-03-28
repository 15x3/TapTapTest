-- ============================================================================
-- 手机界面模拟器 - 像素风格 (Phone Interface Simulator - Pixel Art Style)
-- 功能: 像素风手机 UI 界面，居中显示，背景自适应延展
-- UI 系统: urhox-libs/UI (Yoga Flexbox + NanoVG)
-- 字体: zpix 像素字体
-- 支持: 叮叮、微言应用打开与浏览
-- ============================================================================

local UI = require("urhox-libs/UI")
local DingtalkApp = require("DingtalkApp")
local WechatApp = require("WechatApp")
local ScheduleApp = require("ScheduleApp")
local GameTime = require("Utils.GameTime")
local DeskWidget = require("Utils.DeskWidget")
local EventScheduler = require("Utils.EventScheduler")
local CSVParser = require("Utils.CSVParser")
local WechatData = require("WechatData")
local DingtalkData = require("DingtalkData")

-- 关卡系统模块
local LevelTimer = require("Level.LevelTimer")
local LevelConfig = require("Level.LevelConfig")
local LevelMessageScheduler = require("Level.LevelMessageScheduler")
local LevelManager = require("Level.LevelManager")
local ForwardManager = require("Level.ForwardManager")
local AnnouncementManager = require("Level.AnnouncementManager")
local ReplyManager = require("Level.ReplyManager")
local FeedbackManager = require("Level.FeedbackManager")
local SettlementReport = require("Level.SettlementReport")
local ContextMenu = require("UI.ContextMenu")
local GuideOverlay = require("UI.GuideOverlay")
local SoundManager = require("Utils.SoundManager")
local ChatBubble = require("Utils.ChatBubble")

-- ============================================================================
-- 全局变量
-- ============================================================================
local uiRoot_ = nil
---@type string|nil
local currentApp_ = nil  -- nil = 主屏幕, "dingtalk"/"wechat" = 应用内
local phoneFrame_ = nil
local screenContainer_ = nil  -- 屏幕内容容器（用于切换主屏/应用）
local homePanel_ = nil         -- 主屏幕面板（用于切换壁纸）
local currentWpSlot_ = ""      -- 当前壁纸时段标识

-- 壁纸时段配置（按时间从晚到早排列，匹配第一个满足条件的）
local WALLPAPERS = {
    { hour = 16, min = 30, slot = "evening",   image = "image/wp_evening_20260326120215.png" },
    { hour = 14, min = 30, slot = "afternoon", image = "image/wp_afternoon_20260326120211.png" },
    { hour = 10, min = 30, slot = "noon",      image = "image/wp_noon_20260326120218.png" },
    { hour =  8, min = 40, slot = "morning",   image = "image/wp_morning_20260326120213.png" },
    { hour =  0, min =  0, slot = "dawn",      image = "image/wp_dawn_20260326120217.png" },
}
local timeLabel_ = nil  -- 状态栏时间标签（直接引用，避免 FindById 丢失）
local lastMinute_ = -1  -- 上次更新的分钟值（用于跳过无变化帧）

-- 桌面电子时钟
local deskClockLabel_ = nil    -- 电子时钟时间 Label（用于每帧更新）
local deskClockSecLabel_ = nil -- 电子时钟秒数 Label
local lastClockSec_ = -1      -- 上次更新的秒值

-- 通知系统
local notifBanner_ = nil       -- 通知横幅 UI 元素
local notifTimer_ = 0          -- 通知剩余显示时间
local notifQueue_ = {}         -- 待处理的触发事件队列
local NOTIF_DURATION = 4.0     -- 通知显示时长（秒）

-- CSV 热重载
local CSV_CHECK_INTERVAL = 2.0 -- 每 2 秒检查一次 CSV 变更
local csvCheckTimer_ = 0       -- 检查计时器

-- 关卡模式
local levelMode_ = true        -- true=关卡模式, false=旧叙事模式


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
    APP_DINGTALK = { 48, 118, 255, 255 },   -- 叮叮蓝
    APP_WECHAT   = { 7, 193, 96, 255 },     -- 微言绿
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
    { name = "叮叮",     color = COLORS.APP_DINGTALK, icon = "image/icon_dingtalk_20260326112041.png",  appId = "dingtalk" },
    { name = "微言",     color = COLORS.APP_WECHAT,   icon = "image/icon_wechat_20260326112044.png",    appId = "wechat" },
    { name = "我的课表", color = COLORS.APP_YELLOW,    icon = "image/icon_schedule_20260326112054.png",  appId = "schedule" },
}

-- ============================================================================
-- 生命周期
-- ============================================================================

function Start()
    graphics.windowTitle = "Pixel Phone Simulator"

    -- 强制清除所有数据缓存（确保重新构建后读取最新 CSV）
    WechatData.Invalidate()
    DingtalkData.Invalidate()
    ScheduleApp.Invalidate()
    EventScheduler.Clear()
    CSVParser.ResetTracking()
    GuideOverlay.Reset()

    GameTime.Init()
    SoundManager.Init()
    InitUI()
    CreateUI()
    SubscribeToEvents()

    -- 关卡模式：初始化 LevelManager 并启动第一关
    if levelMode_ then
        InitLevelManager()
        LevelManager.StartLevel("level1")
    end

    -- 播放主 BGM
    SoundManager.PlayBGM(SoundManager.BGM.GAMEPLAY, 0.4)

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
            } },
            { family = "digital", weights = {
                normal = "Fonts/DSEG7Classic-Bold.ttf",
            } },
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

--- 强制刷新状态栏时间（在应用切换等关键时刻调用，避免漏更新）
local function syncStatusBarTime()
    if timeLabel_ then
        timeLabel_:SetText(GetCurrentTime())
    end
end

--- 打开应用
---@param appId string 应用 ID
---@param chatName string|nil 可选，自动打开指定聊天
function OpenApp(appId, chatName)
    if not screenContainer_ then return end
    SoundManager.PlaySFX(SoundManager.SFX.APP_OPEN, 0.45)
    currentApp_ = appId
    screenContainer_:ClearChildren()

    local appNames = {
        dingtalk = "叮叮",
        wechat   = "微言",
        schedule = "我的课表",
    }

    if appId == "dingtalk" then
        screenContainer_:AddChild(DingtalkApp.Create(GoHome, chatName))
    elseif appId == "wechat" then
        screenContainer_:AddChild(WechatApp.Create(GoHome, chatName))
    elseif appId == "schedule" then
        screenContainer_:AddChild(ScheduleApp.Create(GoHome))
    end

    -- 更新状态栏标题
    local titleLabel = uiRoot_:FindById("statusTitle")
    if titleLabel then
        titleLabel:SetText(appNames[appId] or appId)
    end

    -- 同步状态栏时间（消费可能在 App.Create → Process 中产生的 dirty 标记）
    GameTime.ConsumeDirty()
    syncStatusBarTime()
    lastMinute_ = GameTime.Now().min

    print(">>> 打开应用: " .. appId)
end

--- 返回主屏幕
function GoHome()
    if not screenContainer_ then return end
    SoundManager.PlaySFX(SoundManager.SFX.BACK_CLOSE, 0.5)
    currentApp_ = nil
    screenContainer_:ClearChildren()
    screenContainer_:AddChild(CreateHomeContent())

    local titleLabel = uiRoot_:FindById("statusTitle")
    if titleLabel then
        titleLabel:SetText("主页")
    end

    -- 同步状态栏时间（确保从应用返回时显示最新时间）
    GameTime.ConsumeDirty()
    syncStatusBarTime()
    lastMinute_ = GameTime.Now().min

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
        backgroundImage = "image/teacher_desk_bg_v3_20260326111655.png",
        backgroundFit = "cover",
        children = {
            CreatePixelBgDecor(),
            CreatePhoneFrame(),
        },
    }

    UI.SetRoot(uiRoot_)

    -- 计算屏幕逻辑尺寸，用于定位桌面控件
    local dpr = graphics:GetDPR()
    local logW = graphics:GetWidth() / dpr
    local logH = graphics:GetHeight() / dpr
    -- 手机居中，手机壳总宽约 400，备忘录放左侧，时钟放右侧
    local phoneCaseW = PHONE.WIDTH + 20  -- CASE.PAD_SIDE*2
    local leftArea  = (logW - phoneCaseW) / 2  -- 手机左侧可用空间
    local rightStart = logW - leftArea         -- 右侧区域起始 x

    -- 桌面便签控件（手机左侧）
    local stickyNoteW = 130
    local stickyNoteX = math.max(8, leftArea - stickyNoteW - 16)
    local stickyNoteY = logH * 0.18

    local stickyNote = DeskWidget.Create({
        x = stickyNoteX,
        y = stickyNoteY,
        width = stickyNoteW,
        height = 105,
        backgroundColor = { 255, 240, 130, 230 },
        borderRadius = 4,
        borderWidth = 1,
        borderColor = { 200, 180, 80, 180 },
        boxShadow = {
            { x = 2, y = 3, blur = 8, spread = 1, color = { 0, 0, 0, 100 } },
        },
        justifyContent = "flex-start",
        alignItems = "flex-start",
        zIndex = 200,
        children = {
            UI.Label {
                text = "备忘录",
                fontSize = 13,
                fontColor = { 120, 100, 40, 255 },
                marginTop = 8,
                marginLeft = 10,
                pointerEvents = "none",
            },
            UI.Label {
                text = "群聊回复自动档\n班级公告手动输\n单击气泡可复制\n重要消息别漏回",
                fontSize = 11,
                fontColor = { 80, 70, 30, 255 },
                marginTop = 5,
                marginLeft = 10,
                pointerEvents = "none",
            },
        },
    })
    uiRoot_:AddChild(stickyNote:GetElement())

    -- 桌面电子时钟
    uiRoot_:AddChild(CreateDeskClock())
end

--- 创建桌面电子时钟控件
function CreateDeskClock()
    local t = GameTime.Now()
    local timeStr = string.format("%02d:%02d", t.hour, t.min)
    local secStr = string.format(":%02d", t.sec)
    lastClockSec_ = t.sec

    -- 控件尺寸（2x 放大）
    local CW = 300
    local CH = 140

    -- LCD 亮色（绿色荧光）
    local LCD_COLOR = { 50, 220, 120, 255 }
    -- 秒数颜色（稍暗）
    local SEC_COLOR = { 50, 200, 110, 180 }

    -- 主时间 Label（DSEG7 字形偏大，fontSize 要比视觉预期小）
    deskClockLabel_ = UI.Label {
        text = timeStr,
        fontSize = 46,
        fontFamily = "digital",
        fontColor = LCD_COLOR,
        textAlign = "center",
        pointerEvents = "none",
    }

    -- 秒数 Label
    deskClockSecLabel_ = UI.Label {
        text = secStr,
        fontSize = 24,
        fontFamily = "digital",
        fontColor = SEC_COLOR,
        pointerEvents = "none",
    }

    -- 日期行（像素字体）
    local weekdays = { "SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT" }
    local dateStr = string.format("%02d-%02d  %s", t.month, t.day, weekdays[t.wday])

    -- 时钟放在手机右侧（独立计算屏幕尺寸）
    local clkDpr = graphics:GetDPR()
    local clkLogW = graphics:GetWidth() / clkDpr
    local clkLogH = graphics:GetHeight() / clkDpr
    local clkPhoneCaseW = PHONE.WIDTH + 20
    local clkRightStart = clkLogW - (clkLogW - clkPhoneCaseW) / 2
    local clockX = math.min(clkRightStart + 16, clkLogW - CW - 8)
    local clockY = clkLogH * 0.15

    local deskClock = DeskWidget.Create({
        x = clockX,
        y = clockY,
        width = CW,
        height = CH,
        -- 外壳：白色像素风圆角矩形（模拟实物闹钟外壳）
        backgroundColor = { 235, 235, 230, 245 },
        borderRadius = 14,
        borderWidth = 3,
        borderColor = { 210, 210, 205, 255 },
        boxShadow = {
            { x = 0, y = 6, blur = 24, spread = 3, color = { 0, 0, 0, 150 } },
            { x = 0, y = 2, blur = 0, spread = 0, color = { 170, 170, 165, 255 } },
        },
        justifyContent = "center",
        alignItems = "center",
        zIndex = 190,
        children = {
            -- LCD 屏幕区域（深色内嵌屏）
            UI.Panel {
                width = CW - 30,
                height = CH - 30,
                backgroundColor = { 15, 35, 25, 240 },
                borderRadius = 8,
                borderWidth = 2,
                borderColor = { 60, 80, 70, 200 },
                flexDirection = "column",
                justifyContent = "center",
                alignItems = "center",
                pointerEvents = "none",
                children = {
                    -- 时:分 + 秒 行
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "flex-end",
                        pointerEvents = "none",
                        children = {
                            deskClockLabel_,
                            deskClockSecLabel_,
                        },
                    },
                    -- 日期行
                    UI.Label {
                        id = "deskClockDate",
                        text = dateStr,
                        fontSize = 14,
                        fontColor = { 50, 180, 100, 140 },
                        textAlign = "center",
                        pointerEvents = "none",
                        marginTop = 2,
                    },
                },
            },
        },
    })

    return deskClock:GetElement()
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

--- 手机壳配置
local CASE = {
    PAD_SIDE = 10,     -- 壳左右厚度
    PAD_TOP = 14,      -- 壳顶部厚度
    PAD_BOTTOM = 16,   -- 壳底部厚度
    RADIUS = 22,       -- 壳圆角
    COLOR = { 75, 60, 130, 255 },         -- 像素风深紫色外壳
    HIGHLIGHT = { 110, 90, 180, 255 },    -- 高光边
    SHADOW = { 40, 30, 70, 255 },         -- 阴影边
}

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

    -- 手机屏幕本体
    phoneFrame_ = UI.Panel {
        id = "phoneFrame",
        width = "100%",
        height = "100%",
        backgroundColor = COLORS.PHONE_BG,
        borderRadius = PHONE.BORDER_RADIUS,
        overflow = "hidden",
        flexDirection = "column",
        children = {
            CreateEarpieceBar(),
            CreateStatusBar(),
            screenContainer_,
            CreateDockBar(),
        },
    }

    -- 像素风手机壳外包裹
    local phoneCase = UI.Panel {
        id = "phoneCase",
        height = "90%",
        maxHeight = PHONE.HEIGHT + CASE.PAD_TOP + CASE.PAD_BOTTOM,
        aspectRatio = (PHONE.WIDTH + CASE.PAD_SIDE * 2) / (PHONE.HEIGHT + CASE.PAD_TOP + CASE.PAD_BOTTOM),
        backgroundColor = CASE.COLOR,
        borderRadius = CASE.RADIUS,
        borderWidth = 3,
        borderColor = CASE.HIGHLIGHT,
        overflow = "hidden",
        flexDirection = "column",
        paddingLeft = CASE.PAD_SIDE,
        paddingRight = CASE.PAD_SIDE,
        paddingTop = CASE.PAD_TOP,
        paddingBottom = CASE.PAD_BOTTOM,
        boxShadow = {
            { x = 0, y = 8, blur = 30, spread = 4, color = { 0, 0, 0, 180 } },
            { x = 0, y = 2, blur = 0, spread = 0, color = CASE.SHADOW },
        },
        children = {
            -- 壳顶部装饰：摄像头
            CreateCaseTopDecor(),
            phoneFrame_,
            -- 壳底部装饰
            CreateCaseBottomDecor(),
        },
    }

    return phoneCase
end

--- 手机壳顶部装饰（摄像头等）
function CreateCaseTopDecor()
    return UI.Panel {
        width = "100%",
        height = 0,
        position = "absolute",
        top = 3,
        left = 0,
        right = 0,
        flexDirection = "row",
        justifyContent = "center",
        alignItems = "center",
        gap = 6,
        pointerEvents = "none",
        children = {
            -- 摄像头圆点
            UI.Panel {
                width = 8,
                height = 8,
                borderRadius = 4,
                backgroundColor = { 30, 25, 50, 255 },
                borderWidth = 1,
                borderColor = { 90, 75, 150, 255 },
            },
            -- 闪光灯小方块
            UI.Panel {
                width = 5,
                height = 5,
                borderRadius = 0,
                backgroundColor = { 200, 190, 140, 200 },
            },
        },
    }
end

--- 手机壳底部装饰
function CreateCaseBottomDecor()
    return UI.Panel {
        width = "100%",
        height = 0,
        position = "absolute",
        bottom = 4,
        left = 0,
        right = 0,
        flexDirection = "row",
        justifyContent = "center",
        alignItems = "center",
        pointerEvents = "none",
        children = {
            -- 充电口像素块
            UI.Panel {
                width = 20,
                height = 4,
                borderRadius = 0,
                backgroundColor = { 45, 35, 65, 255 },
                borderWidth = 1,
                borderColor = { 60, 50, 90, 255 },
            },
        },
    }
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
                text = "主页",
                fontSize = 12,
                fontColor = COLORS.TEXT_WHITE,
            },
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                gap = 8,
                children = {
                    
                    (function()
                        timeLabel_ = UI.Label {
                            id = "timeLabel",
                            text = GetCurrentTime(),
                            fontSize = 12,
                            fontColor = COLORS.TEXT_WHITE,
                        }
                        return timeLabel_
                    end)(),
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

--- 根据虚拟时间选择壁纸
function GetWallpaperForTime()
    local t = GameTime.Now()
    local hm = t.hour * 60 + t.min
    for _, wp in ipairs(WALLPAPERS) do
        if hm >= wp.hour * 60 + wp.min then
            return wp.slot, wp.image
        end
    end
    return WALLPAPERS[#WALLPAPERS].slot, WALLPAPERS[#WALLPAPERS].image
end

function CreateHomeContent()
    local slot, wpImage = GetWallpaperForTime()
    currentWpSlot_ = slot

    homePanel_ = UI.Panel {
        id = "homePanel",
        width = "100%",
        height = "100%",
        backgroundColor = COLORS.SCREEN_BG,
        backgroundImage = wpImage,
        backgroundFit = "cover",
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
    return homePanel_
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
    local icons = {}
    for _, app in ipairs(APPS) do
        icons[#icons + 1] = CreatePixelAppIcon(app)
    end

    return UI.Panel {
        flexDirection = "column",
        alignItems = "center",
        gap = 16,
        marginTop = 8,
        children = {
            UI.Panel { flexDirection = "row", gap = 24, children = icons },
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
                backgroundImage = app.icon,
                backgroundFit = "contain",
                borderRadius = 4,
                borderWidth = 2,
                borderColor = { 255, 255, 255, 40 },
                justifyContent = "center",
                alignItems = "center",
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
    local t = GameTime.Now()
    return string.format("%02d:%02d", t.hour, t.min)
end

function GetCurrentDate()
    local t = GameTime.Now()
    local weekdays = { "周日", "周一", "周二", "周三", "周四", "周五", "周六" }
    return string.format("%d月%d日 %s", t.month, t.day, weekdays[t.wday])
end

-- ============================================================================
-- 关卡系统
-- ============================================================================

--- 初始化关卡管理器（配置回调）
function InitLevelManager()
    LevelManager.Init({
        --- 显示简报画面：替换 screenContainer 内容
        onShowBriefing = function(panel)
            if not screenContainer_ then return end
            currentApp_ = nil
            screenContainer_:ClearChildren()
            screenContainer_:AddChild(panel)

            print("[main] 显示简报画面")
        end,

        --- 简报结束，恢复手机主界面
        onStartPlaying = function()
            if not screenContainer_ then return end
            SoundManager.PlaySFX(SoundManager.SFX.SCHOOL_BELL, 0.6)
            screenContainer_:ClearChildren()
            screenContainer_:AddChild(CreateHomeContent())

            -- 同步状态栏时间
            GameTime.ConsumeDirty()
            if timeLabel_ then
                timeLabel_:SetText(GetCurrentTime())
            end
            lastMinute_ = GameTime.Now().min

            -- 初始化转发管理器
            local ld = LevelManager.GetLevelData()
            if ld then
                ForwardManager.Init(ld, {
                    onDeliverMessage = function(app, chatName, sender, text)
                        if app == "dingtalk" then
                            DingtalkData.AddMessage(chatName, sender, text)
                        elseif app == "wechat" then
                            WechatData.AddMessage(chatName, sender, text)
                        end
                    end,
                    onForwardSuccess = function(msg, targetChat)
                        SoundManager.PlaySFX(SoundManager.SFX.FORWARD_OK, 0.6)
                        local elapsed = LevelTimer.GetElapsed()
                        FeedbackManager.OnCorrectForward(msg.chat, msg.chainId, elapsed)
                        print(string.format("[main] 转发成功: %s (chain:%s) → %s", msg.chat, msg.chainId or "?", targetChat.name))
                    end,
                    onForwardWrongTarget = function(msg, targetChat)
                        local elapsed = LevelTimer.GetElapsed()
                        FeedbackManager.OnWrongTargetForward(msg.chat, msg.chainId, elapsed)
                        print(string.format("[main] 转发错误目标: %s (chain:%s) → %s", msg.chat, msg.chainId or "?", targetChat.name))
                    end,
                })

                -- 初始化公告管理器
                AnnouncementManager.Init(ld.announcements, {
                    onCheckResult = function(result)
                        print(string.format("[main] 公告检查: %s | 匹配 %d/%d",
                            result.passed and "通过" or "未通过",
                            result.matchedCount, result.totalCount))
                    end,
                })

                -- 初始化回复管理器
                ReplyManager.Init({
                    onReplyResult = function(entry)
                        if entry.result == "matched" then
                            local elapsed = LevelTimer.GetElapsed()
                            FeedbackManager.OnCorrectReply(entry.chat, elapsed)
                        end
                        print(string.format("[main] 回复结果: %s/%s → %s",
                            entry.app, entry.chat, entry.result))
                    end,
                    onReplyTimeout = function(entry)
                        print(string.format("[main] 回复超时: %s/%s", entry.app, entry.chat))
                    end,
                })

                -- 初始化反馈管理器
                FeedbackManager.Init(ld.feedbacks, {
                    onDeliverFeedback = function(app, chat, sender, content)
                        if app == "dingtalk" then
                            DingtalkData.AddMessage(chat, sender, content)
                        elseif app == "wechat" then
                            WechatData.AddMessage(chat, sender, content)
                        end
                        print(string.format("[main] 反馈消息: %s/%s - %s: %s",
                            app, chat, sender, string.sub(content, 1, 40)))
                    end,
                })

                -- 设置 DingtalkApp 公告发布回调
                DingtalkApp.onPublishAnnouncement = function(text)
                    SoundManager.PlaySFX(SoundManager.SFX.ANNOUNCE_OK, 0.6)
                    local elapsed = LevelTimer.GetElapsed()
                    AnnouncementManager.Publish(text, elapsed)
                    -- 将公告内容投递到所有家长群（作为班主任发的消息）
                    for _, chat in ipairs(ld.chats) do
                        if chat.isTarget then
                            if chat.app == "dingtalk" then
                                DingtalkData.AddMessage(chat.name, "班主任", "[公告] " .. text)
                            elseif chat.app == "wechat" then
                                WechatData.AddMessage(chat.name, "班主任", "[公告] " .. text)
                            end
                        end
                    end
                    -- 触发公告成功反馈（家长回复"收到"）
                    FeedbackManager.OnCorrectAnnouncement(elapsed)

                    print(string.format("[main] 公告已发布: %s", string.sub(text, 1, 40)))
                end
            end

            -- [已禁用] 转发功能已移除，上下文菜单不再注册
            -- ContextMenu.SetMountParent(phoneFrame_)
            -- ChatBubble.SetOnContextMenu(...)

            print("[main] 进入游戏状态，手机界面已恢复")
        end,

        --- 注入关卡聊天到 Data 层
        onInjectChats = function(chats)
            for _, chat in ipairs(chats) do
                if chat.app == "dingtalk" then
                    DingtalkData.EnsureChat(chat.name, chat.iconBg, chat.iconText)
                elseif chat.app == "wechat" then
                    WechatData.EnsureChat(chat.name, chat.iconBg, chat.iconText)
                end
            end
        end,

        --- 投放消息到对应 app/chat
        onDeliverMessage = function(msg)
            -- 关卡元数据（附加到 Data 层消息，供转发等操作使用）
            local extra = {
                chat          = msg.chat,
                app           = msg.app,
                forwardTarget = msg.forwardTarget,
                chainId       = msg.chainId,
                chainName     = msg.chainName,
                priority      = msg.priority,
                msgType       = msg.type,
            }
            -- 系统消息：投递到聊天内以居中灰色提示样式显示，不触发后续转发/回复逻辑
            if msg.type == "system" then
                if msg.app == "dingtalk" then
                    DingtalkData.AddMessage(msg.chat, msg.sender or "", msg.content, extra)
                elseif msg.app == "wechat" then
                    WechatData.AddMessage(msg.chat, msg.sender or "", msg.content, extra)
                end
                print(string.format("[关卡系统] 系统提示: %s/%s - %s", msg.app, msg.chat, msg.content))
                return
            end
            if msg.app == "dingtalk" then
                DingtalkData.AddMessage(msg.chat, msg.sender, msg.content, extra)
            elseif msg.app == "wechat" then
                WechatData.AddMessage(msg.chat, msg.sender, msg.content, extra)
            end
            -- 注册 wait_reply 消息到 ReplyManager
            local elapsed = LevelTimer.GetElapsed()
            if msg.type == "wait_reply" then
                ReplyManager.OnWaitReplyDelivered(msg, elapsed)
            end
            -- 注册反馈超时监控
            FeedbackManager.OnMessageDelivered(msg, elapsed)

            print(string.format("[关卡系统] 投放消息: %s/%s - %s: %s",
                msg.app, msg.chat, msg.sender, string.sub(msg.content, 1, 40)))
        end,

        --- 触发通知横幅
        onNotification = function(msg)
            notifQueue_[#notifQueue_ + 1] = {
                app = msg.app,
                chatName = msg.chat,
            }
        end,

        --- 显示结算画面
        onShowSettlement = function(panel)
            if not screenContainer_ then return end
            currentApp_ = nil
            screenContainer_:ClearChildren()
            screenContainer_:AddChild(panel)

            -- [已禁用] 转发功能已移除
            -- ContextMenu.Close()
            -- ChatBubble.SetOnContextMenu(nil)

            -- 清理公告、回复、反馈管理器
            DingtalkApp.onPublishAnnouncement = nil
            AnnouncementManager.Reset()
            ReplyManager.Reset()
            FeedbackManager.Reset()

            -- 切换到结算 BGM
            SoundManager.PlayBGM(SoundManager.BGM.SETTLEMENT, 0.4)

            print("[main] 显示结算画面")
        end,

        --- 关卡结束，回到待机
        onLevelEnd = function()
            if not screenContainer_ then return end
            screenContainer_:ClearChildren()
            screenContainer_:AddChild(CreateHomeContent())

            -- [已禁用] 转发功能已移除
            -- ForwardManager.Reset()
            -- ChatBubble.SetOnContextMenu(nil)

            -- 清理公告、回复、反馈管理器
            DingtalkApp.onPublishAnnouncement = nil
            AnnouncementManager.Reset()
            ReplyManager.Reset()
            FeedbackManager.Reset()

            print("[main] 关卡结束，回到主屏幕")
        end,
    })
end

-- ============================================================================
-- 转发目标选择
-- ============================================================================

--- 转发 Modal 引用
---@type table|nil
local forwardModal_ = nil

--- 转发确认 Modal 引用
---@type table|nil
local forwardConfirmModal_ = nil

--- 显示转发确认弹窗
---@param msg table 要转发的消息
---@param target table { name=string, app=string }
function ShowForwardConfirm(msg, target)
    local appName = target.app == "dingtalk" and "叮叮" or "微言"
    local preview = msg.content or msg.text or ""
    if #preview > 40 then
        preview = preview:sub(1, 40) .. "..."
    end

    forwardConfirmModal_ = UI.Modal {
        title = "确认转发",
        size = "sm",
        closeOnOverlay = true,
        closeOnEscape = true,
        showCloseButton = true,
        onClose = function(self)
            forwardConfirmModal_ = nil
        end,
    }

    forwardConfirmModal_:AddContent(UI.Panel {
        width = "100%",
        flexDirection = "column",
        gap = 12,
        padding = 16,
        alignItems = "center",
        children = {
            UI.Label {
                text = string.format("确认转发到「%s」（%s）？", target.name, appName),
                fontSize = 13,
                fontColor = { 220, 220, 240, 255 },
                textAlign = "center",
            },
            -- 消息预览
            UI.Panel {
                width = "100%",
                backgroundColor = { 30, 30, 48, 255 },
                borderRadius = 6,
                padding = 10,
                children = {
                    UI.Label {
                        text = preview,
                        fontSize = 11,
                        fontColor = { 160, 160, 180, 255 },
                    },
                },
            },
            -- 按钮行
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                justifyContent = "center",
                gap = 12,
                marginTop = 4,
                children = {
                    UI.Button {
                        width = 80, height = 34,
                        text = "取消",
                        fontSize = 12,
                        backgroundColor = { 60, 60, 80, 255 },
                        hoverBackgroundColor = { 75, 75, 100, 255 },
                        borderRadius = 6,
                        textColor = { 180, 180, 200, 255 },
                        onClick = function(self)
                            if forwardConfirmModal_ then
                                forwardConfirmModal_:Close()
                                forwardConfirmModal_ = nil
                            end
                        end,
                    },
                    UI.Button {
                        width = 80, height = 34,
                        text = "转发",
                        fontSize = 12,
                        backgroundColor = { 48, 118, 255, 255 },
                        hoverBackgroundColor = { 68, 138, 255, 255 },
                        borderRadius = 6,
                        textColor = { 255, 255, 255, 255 },
                        onClick = function(self)
                            if forwardConfirmModal_ then
                                forwardConfirmModal_:Close()
                                forwardConfirmModal_ = nil
                            end
                            ForwardManager.ExecuteForward(msg, target)
                        end,
                    },
                },
            },
        },
    })

    forwardConfirmModal_:Show()
end

--- 显示转发目标选择 Modal
---@param msg table 要转发的消息
function ShowForwardTargetSelector(msg)
    local targets = ForwardManager.GetTargets()
    if #targets == 0 then
        print("[main] 没有可转发目标")
        return
    end

    -- 构建目标按钮列表
    local targetButtons = {}
    for _, target in ipairs(targets) do
        local appColor = target.app == "dingtalk"
            and { 48, 118, 255, 255 }
            or { 7, 193, 96, 255 }
        local appName = target.app == "dingtalk" and "叮叮" or "微言"

        targetButtons[#targetButtons + 1] = UI.Button {
            width = "100%",
            height = 44,
            backgroundColor = { 40, 40, 60, 255 },
            hoverBackgroundColor = { 55, 55, 80, 255 },
            pressedBackgroundColor = { 70, 70, 100, 255 },
            borderRadius = 8,
            borderWidth = 1,
            borderColor = { 70, 70, 100, 255 },
            flexDirection = "row",
            alignItems = "center",
            paddingHorizontal = 12,
            gap = 10,
            onClick = function(self)
                -- 关闭目标选择 Modal，弹出确认弹窗
                if forwardModal_ then
                    forwardModal_:Close()
                    forwardModal_ = nil
                end
                ShowForwardConfirm(msg, target)
            end,
            children = {
                -- 应用颜色标识
                UI.Panel {
                    width = 8, height = 8,
                    borderRadius = 4,
                    backgroundColor = appColor,
                    pointerEvents = "none",
                },
                -- 聊天名
                UI.Label {
                    text = target.name,
                    fontSize = 12,
                    fontColor = { 220, 220, 240, 255 },
                    pointerEvents = "none",
                },
                -- 应用名
                UI.Label {
                    text = appName,
                    fontSize = 9,
                    fontColor = { 130, 130, 160, 255 },
                    pointerEvents = "none",
                    marginLeft = "auto",
                },
            },
        }
    end

    -- 创建 Modal
    forwardModal_ = UI.Modal {
        title = "转发到",
        size = "sm",
        closeOnOverlay = true,
        closeOnEscape = true,
        showCloseButton = true,
        onClose = function(self)
            forwardModal_ = nil
        end,
    }

    forwardModal_:AddContent(UI.Panel {
        width = "100%",
        flexDirection = "column",
        gap = 8,
        padding = 12,
        children = {
            -- 消息预览
            UI.Panel {
                width = "100%",
                backgroundColor = { 30, 30, 48, 255 },
                borderRadius = 6,
                padding = 10,
                marginBottom = 4,
                children = {
                    UI.Label {
                        text = string.sub(msg.text or msg.content or "", 1, 60),
                        fontSize = 10,
                        fontColor = { 160, 160, 180, 255 },
                        maxLines = 2,
                    },
                },
            },
            -- 目标列表
            table.unpack(targetButtons),
        },
    })

    forwardModal_:Open()
end

-- ============================================================================
-- 通知系统
-- ============================================================================

--- 应用图标颜色映射
local APP_NOTIF_COLORS = {
    dingtalk = { 48, 118, 255, 255 },
    wechat   = { 7, 193, 96, 255 },
}

--- 应用名称映射
local APP_NOTIF_NAMES = {
    dingtalk = "叮叮",
    wechat   = "微言",
}

--- 显示通知横幅
---@param ev ScheduledEvent 触发的事件
local function showNotifBanner(ev)
    -- 先移除旧横幅
    if notifBanner_ and phoneFrame_ then
        phoneFrame_:RemoveChild(notifBanner_)
        notifBanner_ = nil
    end

    if not phoneFrame_ then return end

    local appColor = APP_NOTIF_COLORS[ev.app] or { 100, 100, 100, 255 }
    local appName = APP_NOTIF_NAMES[ev.app] or ev.app
    local desc = ev.chatName .. " 发来新消息"

    notifBanner_ = UI.Button {
        position = "absolute",
        top = 60,           -- 状态栏下方
        left = 8,
        right = 8,
        height = 56,
        backgroundColor = { 40, 40, 55, 240 },
        hoverBackgroundColor = { 55, 55, 75, 240 },
        pressedBackgroundColor = { 70, 70, 90, 240 },
        borderRadius = 12,
        borderWidth = 1,
        borderColor = { 80, 80, 110, 180 },
        flexDirection = "row",
        alignItems = "center",
        paddingHorizontal = 10,
        gap = 10,
        zIndex = 999,
        boxShadow = {
            { x = 0, y = 4, blur = 12, spread = 2, color = { 0, 0, 0, 120 } },
        },
        onClick = function(self)
            -- 点击通知横幅：打开对应应用并导航到聊天
            notifTimer_ = 0  -- 立即隐藏
            if notifBanner_ and phoneFrame_ then
                phoneFrame_:RemoveChild(notifBanner_)
                notifBanner_ = nil
            end
            OpenApp(ev.app, ev.chatName)
        end,
        children = {
            -- 应用图标
            UI.Panel {
                width = 36, height = 36,
                backgroundColor = appColor,
                borderRadius = 8,
                justifyContent = "center",
                alignItems = "center",
                pointerEvents = "none",
                children = {
                    UI.Label {
                        text = string.sub(appName, 1, 3),  -- UTF8 首字
                        fontSize = 10,
                        fontColor = { 255, 255, 255, 255 },
                    },
                },
            },
            -- 文字内容
            UI.Panel {
                flexGrow = 1, flexShrink = 1,
                flexDirection = "column",
                gap = 2,
                pointerEvents = "none",
                children = {
                    UI.Label {
                        text = appName,
                        fontSize = 11,
                        fontColor = { 220, 220, 240, 255 },
                    },
                    UI.Label {
                        text = desc,
                        fontSize = 10,
                        fontColor = { 160, 160, 180, 255 },
                        maxLines = 1,
                    },
                },
            },
            -- 时间
            UI.Label {
                text = "现在",
                fontSize = 9,
                fontColor = { 120, 120, 150, 255 },
                pointerEvents = "none",
            },
        },
    }

    phoneFrame_:AddChild(notifBanner_)
    SoundManager.PlaySFX(SoundManager.SFX.MSG_RECEIVED, 0.6)
    notifTimer_ = NOTIF_DURATION
    print(string.format("[通知] 显示横幅: %s - %s", appName, ev.chatName))
end

--- 处理触发事件队列（每次只显示一个横幅，前一个消失后显示下一个）
local function processNotifQueue()
    if #notifQueue_ == 0 then return end
    if notifBanner_ then return end  -- 当前有横幅，等它消失

    local ev = table.remove(notifQueue_, 1)
    showNotifBanner(ev)
end

-- ============================================================================
-- 更新
-- ============================================================================

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()

    -- 统一调度子模块 Update（避免多个 SubscribeToEvent("Update") 互相覆盖）
    if HandleDingtalkChatPageUpdate then
        HandleDingtalkChatPageUpdate(eventType, eventData)
    end
    if HandleWechatPagesUpdate then
        HandleWechatPagesUpdate(eventType, eventData)
    end

    -- 聊天列表实时刷新（数据变更时自动重建列表 UI）
    DingtalkApp.RefreshChatListIfDirty()
    WechatApp.RefreshChatListIfDirty()

    local forceDirty = GameTime.ConsumeDirty()
    local t = GameTime.Now()
    if t.min ~= lastMinute_ or forceDirty then
        lastMinute_ = t.min
        local timeStr = GetCurrentTime()
        local dateStr = GetCurrentDate()

        if timeLabel_ then timeLabel_:SetText(timeStr) end

        -- 仅在主屏幕时更新时钟
        if not currentApp_ then
            local clockLabel = uiRoot_:FindById("clockLabel")
            if clockLabel then clockLabel:SetText(timeStr) end

            local dateLabel = uiRoot_:FindById("dateLabel")
            if dateLabel then dateLabel:SetText(dateStr) end
        end

        -- 检测壁纸时段是否变化
        local newSlot, newImage = GetWallpaperForTime()
        if newSlot ~= currentWpSlot_ then
            currentWpSlot_ = newSlot
            if homePanel_ then
                homePanel_:SetStyle({ backgroundImage = newImage })
            end
        end

        -- 定时事件检查（仅旧叙事模式，每分钟变化时检查一次即可）
        if not levelMode_ then
            local triggered = EventScheduler.CheckTriggers()
            for _, ev in ipairs(triggered) do
                notifQueue_[#notifQueue_ + 1] = ev
            end
        end
    end

    -- 关卡模式：LevelManager 驱动（消息调度 + 到期检测）
    if levelMode_ then
        LevelManager.Update(dt)

        -- 驱动公告检查与回复超时（仅 playing 状态）
        if LevelManager.IsPlaying() then
            local elapsed = LevelTimer.GetElapsed()
            AnnouncementManager.CheckAtTime(elapsed)
            ReplyManager.Update(elapsed)
            FeedbackManager.Update(elapsed)
        end


    end

    -- 桌面电子时钟秒级更新（独立于分钟检测）
    if deskClockLabel_ and t.sec ~= lastClockSec_ then
        lastClockSec_ = t.sec
        deskClockLabel_:SetText(string.format("%02d:%02d", t.hour, t.min))
        deskClockSecLabel_:SetText(string.format(":%02d", t.sec))

        -- 每分钟更新日期行
        if t.sec == 0 then
            local weekdays = { "SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT" }
            local dateLabel = uiRoot_:FindById("deskClockDate")
            if dateLabel then
                dateLabel:SetText(string.format("%02d-%02d  %s", t.month, t.day, weekdays[t.wday]))
            end
        end
    end

    -- 通知横幅计时与队列处理
    if notifBanner_ then
        notifTimer_ = notifTimer_ - dt
        if notifTimer_ <= 0 then
            if phoneFrame_ then
                phoneFrame_:RemoveChild(notifBanner_)
            end
            notifBanner_ = nil
        end
    end
    processNotifQueue()

    -- CSV 热重载已禁用
    -- 原因：Invalidate() 会清空 runtimeMessages_ 和 messageListeners_，
    -- 导致关卡中已收发的消息丢失、聊天页监听断开。
    -- 构建后 Preview 会自动重新加载整个页面，无需额外热重载。
end

-- ============================================================================
-- CSV 热重载
-- ============================================================================

--- 强制让 ResourceCache 重新从磁盘读取指定的 CSV 文件
---@param paths string[] 资源路径数组
local function forceReloadResources(paths)
    for _, path in ipairs(paths) do
        -- ReloadResourceWithDependencies 让 ResourceCache 丢弃内部缓存，下次 GetFile 从磁盘读取
        cache:ReloadResourceWithDependencies(path)
    end
end

--- 检查 CSV 文件是否有变化，有则清除缓存并刷新 UI
function CheckCSVReload()
    -- 基于文件系统修改时间检测变化（绕过 ResourceCache）
    local wxChanged = CSVParser.AnyChanged(WechatData.CSV_PATHS)
    local dtChanged = CSVParser.AnyChanged(DingtalkData.CSV_PATHS)
    local schChanged = CSVParser.AnyChanged(ScheduleApp.CSV_PATHS)

    if not wxChanged and not dtChanged and not schChanged then
        return  -- 无变化
    end

    print("[HotReload] 检测到 CSV 变更，开始重载...")

    -- 清除定时事件（ensureScenarios 会重新注册）
    EventScheduler.Clear()

    -- 按模块：强制刷新 ResourceCache + 清除 Lua 层缓存
    if wxChanged then
        forceReloadResources(WechatData.CSV_PATHS)
        WechatData.Invalidate()
        print("[HotReload]   微信数据已重载")
    end
    if dtChanged then
        forceReloadResources(DingtalkData.CSV_PATHS)
        DingtalkData.Invalidate()
        print("[HotReload]   钉钉数据已重载")
    end
    if schChanged then
        forceReloadResources(ScheduleApp.CSV_PATHS)
        ScheduleApp.Invalidate()
        print("[HotReload]   课表数据已重载")
    end

    -- 软刷新：仅标记聊天列表脏，由 Update 中的 RefreshChatListIfDirty 自然重建列表
    -- 不调用 OpenApp/GoHome，避免破坏当前页面导航状态（如正在聊天页就不会被踢回列表）
    if dtChanged then
        DingtalkData.SetChatListDirty()
    end
    if wxChanged then
        WechatData.SetChatListDirty()
    end

    print("[HotReload] CSV 重载完成（软刷新，保留当前页面）")
end
