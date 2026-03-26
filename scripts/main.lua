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

-- 通知系统
local notifBanner_ = nil       -- 通知横幅 UI 元素
local notifTimer_ = 0          -- 通知剩余显示时间
local notifQueue_ = {}         -- 待处理的触发事件队列
local NOTIF_DURATION = 4.0     -- 通知显示时长（秒）

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

    GameTime.Init()
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
    currentApp_ = nil
    screenContainer_:ClearChildren()
    screenContainer_:AddChild(CreateHomeContent())

    local titleLabel = uiRoot_:FindById("statusTitle")
    if titleLabel then
        titleLabel:SetText("手机界面")
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

    -- 桌面便签控件示例
    local stickyNote = DeskWidget.Create({
        x = 16,
        y = 60,
        width = 100,
        height = 80,
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
                fontSize = 11,
                fontColor = { 120, 100, 40, 255 },
                marginTop = 6,
                marginLeft = 8,
                pointerEvents = "none",
            },
            UI.Label {
                text = "记得交作业!",
                fontSize = 10,
                fontColor = { 80, 70, 30, 255 },
                marginTop = 4,
                marginLeft = 8,
                pointerEvents = "none",
            },
        },
    })
    uiRoot_:AddChild(stickyNote:GetElement())
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
                text = "手机界面",
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
    local hm = t.hour * 60 + t.min  -- 转为分钟数方便比较
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

        -- 定时事件检查（每分钟变化时检查一次即可）
        local triggered = EventScheduler.CheckTriggers()
        for _, ev in ipairs(triggered) do
            notifQueue_[#notifQueue_ + 1] = ev
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
end
