-- ============================================================================
-- 手机界面模拟器 - 像素风格 (Phone Interface Simulator - Pixel Art Style)
-- 功能: 像素风手机 UI 界面，居中显示，背景自适应延展
-- UI 系统: urhox-libs/UI (Yoga Flexbox + NanoVG)
-- 字体: zpix 像素字体
-- 支持: 钉钉、微信应用打开与浏览
-- ============================================================================

local UI = require("urhox-libs/UI")
local DingtalkApp = require("DingtalkApp")

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
    { name = "钉钉", color = COLORS.APP_DINGTALK, symbol = "DD",  appId = "dingtalk" },
    { name = "微信", color = COLORS.APP_WECHAT,   symbol = "WX",  appId = "wechat" },
    { name = "设置", color = COLORS.APP_RED,       symbol = "SET", appId = nil },
    { name = "音乐", color = COLORS.APP_YELLOW,    symbol = "BGM", appId = nil },
    { name = "商店", color = COLORS.APP_PURPLE,    symbol = "SHP", appId = nil },
    { name = "地图", color = COLORS.APP_CYAN,      symbol = "MAP", appId = nil },
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

    if appId == "dingtalk" then
        screenContainer_:AddChild(DingtalkApp.Create(GoHome))
    elseif appId == "wechat" then
        screenContainer_:AddChild(CreateWechatApp())
    end

    -- 更新状态栏标题
    local titleLabel = uiRoot_:FindById("statusTitle")
    if titleLabel then
        if appId == "dingtalk" then
            titleLabel:SetText("钉钉")
        elseif appId == "wechat" then
            titleLabel:SetText("微信")
        end
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
-- 微信应用界面（浅色主题）
-- ============================================================================

function CreateWechatApp()
    -- 微信颜色
    local wxGreen = { 7, 193, 96, 255 }
    local wxDarkGreen = { 54, 132, 86, 255 }
    local wxHeaderBg = { 237, 237, 237, 255 }
    local wxBg = { 237, 237, 237, 255 }
    local wxWhite = { 255, 255, 255, 255 }
    local wxText = { 25, 25, 25, 255 }
    local wxTextSec = { 153, 153, 153, 255 }
    local wxBorder = { 225, 225, 225, 255 }

    -- 模拟聊天列表数据
    local chatList = {
        { name = "杨哔哔家", time = "周四",
          msg = "老妈: [视频] 路边遇到好看的花花...", badge = 0, iconBg = { 180, 130, 170, 255 }, iconText = "家" },
        { name = "15.5T、陈通、张连其", time = "2025/12/12",
          msg = "https://mp.weixin.qq.com/s/GJn...", badge = 0, iconBg = { 100, 120, 140, 255 }, iconText = "群" },
        { name = "腾讯新闻", time = "下午3:29",
          msg = "[72条] 重庆大学实验室爆炸致1死3伤", badge = 0, iconBg = { 40, 120, 200, 255 }, iconText = "新闻" },
        { name = "坐以待币", time = "下午3:12",
          msg = "侯一秀: 垃圾也不行吗", badge = 1, iconBg = { 80, 80, 100, 255 }, iconText = "$" },
        { name = "亚博-树莓派5/4B/3B...", time = "下午3:11",
          msg = "[17条] 我哩个派", badge = 0, iconBg = { 200, 80, 80, 255 }, iconText = "Pi" },
        { name = "14  王泊松", time = "下午3:10",
          msg = "[动画表情]", badge = 2, iconBg = { 60, 140, 180, 255 }, iconText = "王" },
        { name = "公众号", time = "下午3:02",
          msg = "浙江教师: 湖州市教育局教师招聘公告...", badge = 0, iconBg = { 50, 120, 180, 255 }, iconText = "公" },
        { name = "#1 工贸班主任", time = "下午2:42",
          msg = "风中的发卡: 请25服装设计、25美容美体...", badge = 2, iconBg = { 80, 160, 80, 255 }, iconText = "班" },
        { name = "吴泽钦", time = "下午1:47",
          msg = "好的, 那我和政教处说一下", badge = 0, iconBg = { 120, 120, 140, 255 }, iconText = "吴" },
        { name = "朱政", time = "下午1:39",
          msg = "[语音通话]", badge = 1, iconBg = { 100, 100, 120, 255 }, iconText = "朱" },
    }

    -- 底部导航项
    local tabs = {
        { label = "微信", icon = "WX", active = true, badge = 0, hasRedDot = true },
        { label = "通讯录", icon = "DIR", active = false, badge = 0, hasRedDot = false },
        { label = "发现", icon = "EYE", active = false, badge = 0, hasRedDot = true },
        { label = "我", icon = "ME", active = false, badge = 0, hasRedDot = false },
    }

    -- 创建聊天项
    local chatItems = {}
    for _, chat in ipairs(chatList) do
        chatItems[#chatItems + 1] = CreateWechatChatItem(chat, wxText, wxTextSec, wxBorder)
    end

    -- 创建底部 tab
    local tabItems = {}
    for _, tab in ipairs(tabs) do
        tabItems[#tabItems + 1] = CreateWechatTab(tab, wxDarkGreen, wxTextSec)
    end

    return UI.Panel {
        width = "100%",
        height = "100%",
        backgroundColor = wxBg,
        flexDirection = "column",
        children = {
            -- 顶部标题栏
            UI.Panel {
                width = "100%",
                height = 44,
                backgroundColor = wxHeaderBg,
                flexDirection = "row",
                alignItems = "center",
                justifyContent = "space-between",
                paddingHorizontal = 12,
                borderBottomWidth = 1,
                borderBottomColor = { 210, 210, 210, 255 },
                children = {
                    -- 左侧返回
                    UI.Button {
                        width = 30,
                        height = 30,
                        backgroundColor = { 0, 0, 0, 0 },
                        hoverBackgroundColor = { 0, 0, 0, 15 },
                        pressedBackgroundColor = { 0, 0, 0, 30 },
                        borderRadius = 4,
                        text = "<",
                        textColor = wxText,
                        fontSize = 14,
                        onClick = function(self) GoHome() end,
                    },
                    -- 标题 微信(121)
                    UI.Label {
                        text = "微信(121)",
                        fontSize = 14,
                        fontColor = wxText,
                    },
                    -- 右侧按钮
                    UI.Panel {
                        flexDirection = "row",
                        gap = 12,
                        children = {
                            UI.Panel {
                                width = 22, height = 22,
                                borderRadius = 11,
                                borderWidth = 1,
                                borderColor = { 80, 80, 80, 255 },
                                justifyContent = "center",
                                alignItems = "center",
                                children = {
                                    UI.Label { text = "Q", fontSize = 10, fontColor = wxText },
                                },
                            },
                            UI.Panel {
                                width = 22, height = 22,
                                justifyContent = "center",
                                alignItems = "center",
                                children = {
                                    UI.Label { text = "+", fontSize = 16, fontColor = wxText },
                                },
                            },
                        },
                    },
                },
            },

            -- 聊天列表（可滚动）
            UI.ScrollView {
                width = "100%",
                flexGrow = 1,
                flexBasis = 0,
                backgroundColor = wxWhite,
                children = {
                    UI.Panel {
                        width = "100%",
                        flexDirection = "column",
                        children = chatItems,
                    },
                },
            },

            -- 底部导航栏
            UI.Panel {
                width = "100%",
                height = 50,
                backgroundColor = wxHeaderBg,
                flexDirection = "row",
                alignItems = "center",
                justifyContent = "space-around",
                borderTopWidth = 1,
                borderTopColor = { 210, 210, 210, 255 },
                children = tabItems,
            },
        },
    }
end

--- 微信聊天列表项
function CreateWechatChatItem(chat, wxText, wxTextSec, wxBorder)
    local iconChildren = {
        UI.Label {
            text = chat.iconText,
            fontSize = 10,
            fontColor = { 255, 255, 255, 255 },
            textAlign = "center",
        },
    }

    -- 角标
    if chat.badge and chat.badge > 0 then
        iconChildren[#iconChildren + 1] = UI.Panel {
            position = "absolute",
            top = -3,
            right = -3,
            width = 14,
            height = 14,
            backgroundColor = { 250, 80, 80, 255 },
            borderRadius = 7,
            justifyContent = "center",
            alignItems = "center",
            children = {
                UI.Label {
                    text = tostring(chat.badge),
                    fontSize = 8,
                    fontColor = { 255, 255, 255, 255 },
                },
            },
        }
    end

    return UI.Panel {
        width = "100%",
        height = 64,
        flexDirection = "row",
        alignItems = "center",
        paddingHorizontal = 12,
        gap = 10,
        backgroundColor = { 255, 255, 255, 255 },
        borderBottomWidth = 1,
        borderBottomColor = { 240, 240, 240, 255 },
        children = {
            -- 头像
            UI.Panel {
                width = 44,
                height = 44,
                backgroundColor = chat.iconBg,
                borderRadius = 6,
                justifyContent = "center",
                alignItems = "center",
                children = iconChildren,
            },
            -- 内容
            UI.Panel {
                flexGrow = 1,
                flexBasis = 0,
                flexShrink = 1,
                flexDirection = "column",
                justifyContent = "center",
                gap = 4,
                children = {
                    -- 名称行
                    UI.Panel {
                        flexDirection = "row",
                        justifyContent = "space-between",
                        alignItems = "center",
                        children = {
                            UI.Label {
                                text = chat.name,
                                fontSize = 13,
                                fontColor = wxText,
                                maxLines = 1,
                                flexShrink = 1,
                            },
                            UI.Label {
                                text = chat.time,
                                fontSize = 9,
                                fontColor = wxTextSec,
                            },
                        },
                    },
                    -- 消息预览
                    UI.Label {
                        text = chat.msg,
                        fontSize = 10,
                        fontColor = wxTextSec,
                        maxLines = 1,
                    },
                },
            },
        },
    }
end

--- 微信底部导航 tab
function CreateWechatTab(tab, wxGreen, wxTextSec)
    local tabColor = tab.active and wxGreen or wxTextSec

    local iconChildren = {
        UI.Label {
            text = tab.icon,
            fontSize = 10,
            fontColor = tabColor,
            textAlign = "center",
        },
    }

    -- 小红点
    if tab.hasRedDot then
        iconChildren[#iconChildren + 1] = UI.Panel {
            position = "absolute",
            top = -2,
            right = -4,
            width = 8,
            height = 8,
            backgroundColor = { 250, 80, 80, 255 },
            borderRadius = 4,
        }
    end

    return UI.Panel {
        alignItems = "center",
        gap = 2,
        children = {
            UI.Panel {
                width = 24,
                height = 20,
                justifyContent = "center",
                alignItems = "center",
                children = iconChildren,
            },
            UI.Label {
                text = tab.label,
                fontSize = 9,
                fontColor = tabColor,
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

        -- 仅在主屏幕时更新时钟
        if not currentApp_ then
            local clockLabel = uiRoot_:FindById("clockLabel")
            if clockLabel then clockLabel:SetText(timeStr) end

            local dateLabel = uiRoot_:FindById("dateLabel")
            if dateLabel then dateLabel:SetText(dateStr) end
        end
    end
end
