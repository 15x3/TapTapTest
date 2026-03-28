-- ============================================================================
-- 微言应用壳模块 (WeChat App Shell)
-- 功能: 微言应用主框架（Tab 栏、导航、三个主页面）
-- Tab: 微言 | 通讯录 | 我
-- 依赖: WechatPages, WechatData
-- ============================================================================

local UI = require("urhox-libs/UI")
local WechatPages = require("WechatPages")
local WechatData = require("WechatData")
local WechatCommon = require("WechatPagesCommon")

local App = {}

-- 微言色彩体系（从共享模块引用）
local WX = WechatCommon.WX

-- 模块级状态
local wxContentContainer_ = nil
local wxActiveTab_ = "chat"
local wxTabBarContainer_ = nil
local goHomeFn_ = nil

-- ============================================================================
-- 导航系统
-- ============================================================================

--- 导航到聊天详情页
local function navigateToChat(chatData)
    if not wxContentContainer_ then return end
    wxContentContainer_:ClearChildren()
    local backToMain = function() App.switchTab("chat") end
    wxContentContainer_:AddChild(WechatPages.CreateChatPage(chatData.name, chatData.iconBg, backToMain))
end

--- 导航到联系人详情页
local function navigateToContactDetail(contact)
    if not wxContentContainer_ then return end
    wxContentContainer_:ClearChildren()
    local backToContacts = function() App.switchTab("contacts") end
    -- "发消息"回调：确保聊天存在 → 跳转到聊天页
    local onSendMessage = function(contactInfo, avatarBg)
        local chatData = WechatData.EnsureChat(contactInfo.name, avatarBg, contactInfo.initial)
        navigateToChat(chatData)
    end
    wxContentContainer_:AddChild(WechatPages.CreateContactDetailPage(contact, backToContacts, onSendMessage))
end

-- ============================================================================
-- Tab 栏
-- ============================================================================

local function refreshTabBar()
    if not wxTabBarContainer_ then return end
    wxTabBarContainer_:ClearChildren()

    local unreadCount = WechatData.GetTotalUnreadCount()

    local tabs = {
        { id = "chat",     label = "微言",   icon = "WX",  badge = unreadCount },
        { id = "contacts", label = "通讯录", icon = "DIR", badge = 0 },
        { id = "me",       label = "我",     icon = "ME",  badge = 0 },
    }

    for _, tab in ipairs(tabs) do
        wxTabBarContainer_:AddChild(App._createTab(tab, tab.id == wxActiveTab_))
    end
end

function App.switchTab(tabId)
    wxActiveTab_ = tabId
    if not wxContentContainer_ then return end
    wxContentContainer_:ClearChildren()

    if tabId == "chat" then
        wxContentContainer_:AddChild(App._createChatListPage())
    elseif tabId == "contacts" then
        wxContentContainer_:AddChild(App._createContactsPage())
    elseif tabId == "me" then
        wxContentContainer_:AddChild(App._createMePage())
    end

    refreshTabBar()
end

-- ============================================================================
-- Tab 1: 微言（聊天列表）
-- ============================================================================

function App._createChatListPage()
    local chatList = WechatData.GetChats()

    local chatItems = {}
    for _, chat in ipairs(chatList) do
        chatItems[#chatItems + 1] = App._createChatItem(chat)
    end

    return UI.Panel {
        width = "100%",
        height = "100%",
        backgroundColor = WX.bg,
        flexDirection = "column",
        children = {
            -- 顶栏
            UI.Panel {
                width = "100%",
                height = 44,
                backgroundColor = WX.headerBg,
                flexDirection = "row",
                alignItems = "center",
                justifyContent = "space-between",
                paddingHorizontal = 12,
                borderBottomWidth = 1,
                borderBottomColor = { 210, 210, 210, 255 },
                children = {
                    -- 返回按钮
                    UI.Button {
                        width = 30, height = 30,
                        backgroundColor = { 0, 0, 0, 0 },
                        hoverBackgroundColor = { 0, 0, 0, 10 },
                        pressedBackgroundColor = { 0, 0, 0, 20 },
                        borderRadius = 4,
                        text = "<",
                        textColor = WX.text,
                        fontSize = 14,
                        onClick = function(self)
                            if goHomeFn_ then goHomeFn_() end
                        end,
                    },
                    -- 标题
                    UI.Label {
                        text = "微言",
                        fontSize = 14,
                        fontColor = WX.text,
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
                                    UI.Label { text = "Q", fontSize = 10, fontColor = WX.text },
                                },
                            },
                            UI.Panel {
                                width = 22, height = 22,
                                justifyContent = "center",
                                alignItems = "center",
                                children = {
                                    UI.Label { text = "+", fontSize = 16, fontColor = WX.text },
                                },
                            },
                        },
                    },
                },
            },
            -- 搜索栏
            UI.Panel {
                width = "100%",
                height = 36,
                backgroundColor = WX.headerBg,
                paddingHorizontal = 10,
                paddingBottom = 6,
                children = {
                    UI.Panel {
                        width = "100%",
                        height = "100%",
                        backgroundColor = WX.white,
                        borderRadius = 4,
                        justifyContent = "center",
                        alignItems = "center",
                        children = {
                            UI.Label { text = "搜索", fontSize = 11, fontColor = { 180, 180, 180, 255 } },
                        },
                    },
                },
            },
            -- 聊天列表
            UI.ScrollView {
                width = "100%",
                flexGrow = 1,
                flexBasis = 0,
                backgroundColor = WX.white,
                children = {
                    UI.Panel {
                        width = "100%",
                        flexDirection = "column",
                        children = chatItems,
                    },
                },
            },
        },
    }
end

--- 聊天列表项
function App._createChatItem(chat)
    local iconChildren = {
        UI.Label {
            text = chat.iconText,
            fontSize = 10,
            fontColor = { 255, 255, 255, 255 },
            textAlign = "center",
            pointerEvents = "none",
        },
    }

    if chat.badge and chat.badge > 0 then
        iconChildren[#iconChildren + 1] = UI.Panel {
            position = "absolute",
            top = -3, right = -3,
            width = 14, height = 14,
            backgroundColor = { 250, 80, 80, 255 },
            borderRadius = 7,
            justifyContent = "center",
            alignItems = "center",
            pointerEvents = "none",
            children = {
                UI.Label {
                    text = tostring(chat.badge),
                    fontSize = 8,
                    fontColor = { 255, 255, 255, 255 },
                },
            },
        }
    end

    return UI.Button {
        width = "100%",
        height = 64,
        backgroundColor = { 255, 255, 255, 255 },
        hoverBackgroundColor = { 245, 245, 245, 255 },
        pressedBackgroundColor = { 235, 235, 235, 255 },
        borderRadius = 0,
        flexDirection = "row",
        alignItems = "center",
        paddingHorizontal = 12,
        gap = 10,
        borderBottomWidth = 1,
        borderBottomColor = { 240, 240, 240, 255 },
        overflow = "hidden",
        onClick = function(self) navigateToChat(chat) end,
        children = {
            -- 头像
            UI.Panel {
                width = 44, height = 44,
                backgroundColor = chat.iconBg,
                borderRadius = 6,
                justifyContent = "center",
                alignItems = "center",
                pointerEvents = "none",
                children = iconChildren,
            },
            -- 内容
            UI.Panel {
                flexGrow = 1, flexBasis = 0, flexShrink = 1,
                flexDirection = "column",
                justifyContent = "center",
                gap = 4,
                overflow = "hidden",
                pointerEvents = "none",
                children = {
                    UI.Panel {
                        flexDirection = "row",
                        justifyContent = "space-between",
                        alignItems = "center",
                        overflow = "hidden",
                        children = {
                            UI.Label {
                                text = chat.name,
                                fontSize = 13,
                                fontColor = WX.text,
                                maxLines = 1,
                                flexShrink = 1,
                            },
                            UI.Label {
                                text = chat.time,
                                fontSize = 9,
                                fontColor = WX.textSec,
                                flexShrink = 0,
                            },
                        },
                    },
                    UI.Label {
                        text = chat.msg,
                        fontSize = 10,
                        fontColor = WX.textSec,
                        maxLines = 1,
                        overflow = "hidden",
                    },
                },
            },
        },
    }
end

-- ============================================================================
-- Tab 2: 通讯录
-- ============================================================================

function App._createContactsPage()
    local contacts = WechatData.GetContacts()
    local groups = WechatData.GetContactGroups()

    -- 功能入口列表
    local featureItems = {
        { icon = "新", iconBg = { 255, 140, 0, 255 }, label = "新的朋友", badge = 2 },
        { icon = "群", iconBg = { 80, 180, 80, 255 },  label = "群聊", badge = 0 },
        { icon = "标", iconBg = { 48, 118, 255, 255 }, label = "标签", badge = 0 },
        { icon = "公", iconBg = { 48, 118, 255, 255 }, label = "公众号", badge = 0 },
    }

    local featureWidgets = {}
    for _, item in ipairs(featureItems) do
        local rightChildren = {}
        if item.badge and item.badge > 0 then
            rightChildren[#rightChildren + 1] = UI.Panel {
                width = 16, height = 16,
                backgroundColor = { 250, 80, 80, 255 },
                borderRadius = 8,
                justifyContent = "center",
                alignItems = "center",
                pointerEvents = "none",
                children = {
                    UI.Label { text = tostring(item.badge), fontSize = 8, fontColor = { 255, 255, 255, 255 } },
                },
            }
        end

        featureWidgets[#featureWidgets + 1] = UI.Panel {
            width = "100%",
            height = 52,
            backgroundColor = WX.white,
            flexDirection = "row",
            alignItems = "center",
            paddingHorizontal = 12,
            gap = 10,
            borderBottomWidth = 1,
            borderBottomColor = { 240, 240, 240, 255 },
            children = {
                UI.Panel {
                    width = 36, height = 36,
                    backgroundColor = item.iconBg,
                    borderRadius = 6,
                    justifyContent = "center",
                    alignItems = "center",
                    children = {
                        UI.Label { text = item.icon, fontSize = 12, fontColor = { 255, 255, 255, 255 } },
                    },
                },
                UI.Label {
                    text = item.label,
                    fontSize = 13,
                    fontColor = WX.text,
                    flexGrow = 1,
                },
                UI.Panel {
                    flexDirection = "row",
                    gap = 4,
                    alignItems = "center",
                    children = rightChildren,
                },
            },
        }
    end

    -- 联系人列表（按首字母分组）
    local contactWidgets = {}
    for _, groupLetter in ipairs(groups) do
        -- 分组标题
        contactWidgets[#contactWidgets + 1] = UI.Panel {
            width = "100%",
            height = 26,
            backgroundColor = WX.bg,
            justifyContent = "center",
            paddingHorizontal = 12,
            children = {
                UI.Label {
                    text = groupLetter,
                    fontSize = 11,
                    fontColor = WX.textSec,
                },
            },
        }

        -- 该分组下的联系人
        for _, c in ipairs(contacts) do
            if c.group == groupLetter then
                local colorSeed = string.byte(c.initial, 1) or 65
                local avatarColors = {
                    { 80, 130, 220, 255 },
                    { 200, 90, 90, 255 },
                    { 60, 170, 100, 255 },
                    { 180, 120, 60, 255 },
                    { 140, 80, 200, 255 },
                    { 60, 170, 180, 255 },
                }
                local avatarBg = avatarColors[(colorSeed % #avatarColors) + 1]
                local displayName = c.name
                if c.remark and c.remark ~= "" then
                    displayName = c.remark
                end

                local contactRef = c
                contactWidgets[#contactWidgets + 1] = UI.Button {
                    width = "100%",
                    height = 52,
                    backgroundColor = WX.white,
                    hoverBackgroundColor = { 245, 245, 245, 255 },
                    pressedBackgroundColor = { 235, 235, 235, 255 },
                    borderRadius = 0,
                    flexDirection = "row",
                    alignItems = "center",
                    paddingHorizontal = 12,
                    gap = 10,
                    borderBottomWidth = 1,
                    borderBottomColor = { 240, 240, 240, 255 },
                    onClick = function(self)
                        navigateToContactDetail(contactRef)
                    end,
                    children = {
                        UI.Panel {
                            width = 36, height = 36,
                            backgroundColor = avatarBg,
                            borderRadius = 6,
                            justifyContent = "center",
                            alignItems = "center",
                            pointerEvents = "none",
                            children = {
                                UI.Label { text = c.initial, fontSize = 14, fontColor = { 255, 255, 255, 255 } },
                            },
                        },
                        UI.Label {
                            text = displayName,
                            fontSize = 13,
                            fontColor = WX.text,
                            flexGrow = 1,
                            maxLines = 1,
                            pointerEvents = "none",
                        },
                    },
                }
            end
        end
    end

    return UI.Panel {
        width = "100%",
        height = "100%",
        backgroundColor = WX.bg,
        flexDirection = "column",
        children = {
            -- 顶栏
            UI.Panel {
                width = "100%",
                height = 44,
                backgroundColor = WX.headerBg,
                flexDirection = "row",
                alignItems = "center",
                justifyContent = "space-between",
                paddingHorizontal = 12,
                borderBottomWidth = 1,
                borderBottomColor = { 210, 210, 210, 255 },
                children = {
                    UI.Panel { width = 30, height = 30 },
                    UI.Label {
                        text = "通讯录",
                        fontSize = 14,
                        fontColor = WX.text,
                    },
                    UI.Panel {
                        width = 22, height = 22,
                        justifyContent = "center",
                        alignItems = "center",
                        children = {
                            UI.Label { text = "+", fontSize = 16, fontColor = WX.text },
                        },
                    },
                },
            },
            -- 搜索栏
            UI.Panel {
                width = "100%",
                height = 36,
                backgroundColor = WX.headerBg,
                paddingHorizontal = 10,
                paddingBottom = 6,
                children = {
                    UI.Panel {
                        width = "100%",
                        height = "100%",
                        backgroundColor = WX.white,
                        borderRadius = 4,
                        justifyContent = "center",
                        alignItems = "center",
                        children = {
                            UI.Label { text = "搜索", fontSize = 11, fontColor = { 180, 180, 180, 255 } },
                        },
                    },
                },
            },
            -- 联系人列表
            UI.ScrollView {
                width = "100%",
                flexGrow = 1,
                flexBasis = 0,
                children = {
                    UI.Panel {
                        width = "100%",
                        flexDirection = "column",
                        children = {
                            -- 功能入口
                            UI.Panel {
                                width = "100%",
                                flexDirection = "column",
                                children = featureWidgets,
                            },
                            -- 联系人分组列表
                            UI.Panel {
                                width = "100%",
                                flexDirection = "column",
                                children = contactWidgets,
                            },
                            -- 底部统计
                            UI.Panel {
                                width = "100%",
                                height = 40,
                                backgroundColor = WX.bg,
                                justifyContent = "center",
                                alignItems = "center",
                                children = {
                                    UI.Label {
                                        text = #contacts .. "位联系人",
                                        fontSize = 11,
                                        fontColor = WX.textSec,
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

-- ============================================================================
-- Tab 3: 我
-- ============================================================================

function App._createMePage()

    local Toast = require("urhox-libs/UI/Widgets/Toast")
    local function showNotAvailable()
        Toast.Show("功能暂未开放", { type = "info", duration = 2 })
    end

    -- 菜单项创建器
    local function MenuItem(iconText, iconBg, label, subtitle, showArrow)
        local rightChildren = {}
        if subtitle and subtitle ~= "" then
            rightChildren[#rightChildren + 1] = UI.Label {
                text = subtitle,
                fontSize = 10,
                fontColor = WX.textSec,
                marginRight = 4,
                pointerEvents = "none",
            }
        end
        if showArrow ~= false then
            rightChildren[#rightChildren + 1] = UI.Label {
                text = ">",
                fontSize = 12,
                fontColor = WX.textSec,
                pointerEvents = "none",
            }
        end

        return UI.Button {
            width = "100%",
            height = 52,
            backgroundColor = WX.white,
            hoverBackgroundColor = { 245, 245, 245, 255 },
            pressedBackgroundColor = { 235, 235, 235, 255 },
            flexDirection = "row",
            alignItems = "center",
            paddingHorizontal = 14,
            gap = 12,
            borderRadius = 0,
            borderBottomWidth = 1,
            borderBottomColor = { 240, 240, 240, 255 },
            onClick = function(self) showNotAvailable() end,
            children = {
                UI.Panel {
                    width = 24, height = 24,
                    backgroundColor = iconBg,
                    borderRadius = 5,
                    justifyContent = "center",
                    alignItems = "center",
                    pointerEvents = "none",
                    children = {
                        UI.Label { text = iconText, fontSize = 10, fontColor = { 255, 255, 255, 255 } },
                    },
                },
                UI.Label {
                    text = label,
                    fontSize = 13,
                    fontColor = WX.text,
                    flexGrow = 1,
                    pointerEvents = "none",
                },
                UI.Panel {
                    flexDirection = "row",
                    alignItems = "center",
                    gap = 4,
                    pointerEvents = "none",
                    children = rightChildren,
                },
            },
        }
    end

    return UI.Panel {
        width = "100%",
        height = "100%",
        backgroundColor = WX.bg,
        flexDirection = "column",
        children = {
            -- 顶栏
            UI.Panel {
                width = "100%",
                height = 44,
                backgroundColor = WX.headerBg,
                justifyContent = "center",
                alignItems = "center",
                borderBottomWidth = 1,
                borderBottomColor = { 210, 210, 210, 255 },
                children = {
                    UI.Label { text = "我", fontSize = 14, fontColor = WX.text },
                },
            },
            -- 滚动内容
            UI.ScrollView {
                width = "100%",
                flexGrow = 1,
                flexBasis = 0,
                children = {
                    UI.Panel {
                        width = "100%",
                        flexDirection = "column",
                        children = {
                            -- 个人信息卡片
                            UI.Button {
                                width = "100%",
                                backgroundColor = WX.white,
                                hoverBackgroundColor = { 245, 245, 245, 255 },
                                pressedBackgroundColor = { 235, 235, 235, 255 },
                                borderRadius = 0,
                                paddingVertical = 20,
                                paddingHorizontal = 16,
                                flexDirection = "row",
                                alignItems = "center",
                                gap = 14,
                                onClick = function(self) showNotAvailable() end,
                                children = {
                                    -- 头像
                                    UI.Panel {
                                        width = 56, height = 56,
                                        backgroundColor = { 100, 160, 220, 255 },
                                        borderRadius = 8,
                                        justifyContent = "center",
                                        alignItems = "center",
                                        pointerEvents = "none",
                                        children = {
                                            UI.Label { text = "陈", fontSize = 22, fontColor = { 255, 255, 255, 255 } },
                                        },
                                    },
                                    -- 信息
                                    UI.Panel {
                                        flexGrow = 1, flexShrink = 1,
                                        flexDirection = "column",
                                        gap = 4,
                                        pointerEvents = "none",
                                        children = {
                                            UI.Label {
                                                text = "陈星河",
                                                fontSize = 17,
                                                fontColor = WX.text,
                                                fontWeight = "bold",
                                            },
                                            UI.Panel {
                                                flexDirection = "row",
                                                alignItems = "center",
                                                gap = 6,
                                                children = {
                                                    UI.Label {
                                                        text = "微言号: chenxinghe_2025",
                                                        fontSize = 11,
                                                        fontColor = WX.textSec,
                                                    },
                                                },
                                            },
                                        },
                                    },
                                    -- 箭头 + 二维码
                                    UI.Panel {
                                        flexDirection = "row",
                                        alignItems = "center",
                                        gap = 6,
                                        pointerEvents = "none",
                                        children = {
                                            UI.Panel {
                                                width = 16, height = 16,
                                                borderWidth = 1,
                                                borderColor = WX.textSec,
                                                borderRadius = 2,
                                                justifyContent = "center",
                                                alignItems = "center",
                                                children = {
                                                    UI.Label { text = "QR", fontSize = 6, fontColor = WX.textSec },
                                                },
                                            },
                                            UI.Label { text = ">", fontSize = 13, fontColor = WX.textSec },
                                        },
                                    },
                                },
                            },

                            UI.Panel { width = "100%", height = 8, backgroundColor = WX.bg },

                            -- 服务
                            MenuItem("SV", { 48, 118, 255, 255 }, "服务"),

                            UI.Panel { width = "100%", height = 8, backgroundColor = WX.bg },

                            -- 收藏
                            MenuItem("SC", { 255, 140, 0, 255 }, "收藏"),
                            -- 朋友圈
                            MenuItem("PY", { 48, 118, 255, 255 }, "朋友圈"),
                            -- 视频号
                            MenuItem("SP", { 255, 100, 50, 255 }, "视频号"),
                            -- 卡包
                            MenuItem("KB", { 48, 118, 255, 255 }, "卡包"),
                            -- 表情
                            MenuItem("BQ", { 255, 180, 50, 255 }, "表情"),

                            UI.Panel { width = "100%", height = 8, backgroundColor = WX.bg },

                            -- 设置
                            MenuItem("SET", { 48, 118, 255, 255 }, "设置"),
                        },
                    },
                },
            },
        },
    }
end

-- ============================================================================
-- Tab 创建
-- ============================================================================

function App._createTab(tab, isActive)
    local tabColor = isActive and WX.darkGreen or WX.textSec

    local iconChildren = {
        UI.Label {
            text = tab.icon,
            fontSize = 10,
            fontColor = tabColor,
            textAlign = "center",
            pointerEvents = "none",
        },
    }

    -- 角标
    if tab.badge and tab.badge > 0 then
        local badgeText = tab.badge > 99 and "99+" or tostring(tab.badge)
        iconChildren[#iconChildren + 1] = UI.Panel {
            position = "absolute",
            top = -4, right = -10,
            height = 13, minWidth = 13,
            paddingHorizontal = 3,
            backgroundColor = { 250, 80, 80, 255 },
            borderRadius = 7,
            justifyContent = "center",
            alignItems = "center",
            pointerEvents = "none",
            children = {
                UI.Label { text = badgeText, fontSize = 8, fontColor = { 255, 255, 255, 255 } },
            },
        }
    end

    return UI.Button {
        flexGrow = 1,
        height = 50,
        backgroundColor = { 0, 0, 0, 0 },
        hoverBackgroundColor = { 0, 0, 0, 8 },
        pressedBackgroundColor = { 0, 0, 0, 15 },
        borderRadius = 0,
        flexDirection = "column",
        alignItems = "center",
        justifyContent = "center",
        gap = 2,
        onClick = function(self)
            if tab.id and tab.id ~= wxActiveTab_ then
                App.switchTab(tab.id)
            end
        end,
        children = {
            UI.Panel {
                width = 24, height = 20,
                justifyContent = "center",
                alignItems = "center",
                pointerEvents = "none",
                children = iconChildren,
            },
            UI.Label { text = tab.label, fontSize = 9, fontColor = tabColor, pointerEvents = "none" },
        },
    }
end

-- ============================================================================
-- 对外接口
-- ============================================================================

--- 创建完整的微言应用界面
---@param onGoHome fun() 返回主屏幕的回调
---@param defaultChatName string|nil 可选，创建后自动打开指定聊天
---@return table UI 组件
function App.Create(onGoHome, defaultChatName)
    goHomeFn_ = onGoHome

    wxContentContainer_ = UI.Panel {
        width = "100%",
        flexGrow = 1,
        flexBasis = 0,
        flexDirection = "column",
        overflow = "hidden",
        children = {
            App._createChatListPage(),
        },
    }

    wxTabBarContainer_ = UI.Panel {
        width = "100%",
        height = 50,
        backgroundColor = WX.headerBg,
        flexDirection = "row",
        alignItems = "center",
        justifyContent = "space-around",
        borderTopWidth = 1,
        borderTopColor = { 210, 210, 210, 255 },
    }

    wxActiveTab_ = "chat"
    refreshTabBar()

    -- 如果指定了默认聊天名，自动导航到该聊天
    if defaultChatName and defaultChatName ~= "" then
        local chatList = WechatData.GetChats()
        for _, chat in ipairs(chatList) do
            if chat.name == defaultChatName then
                navigateToChat(chat)
                break
            end
        end
    end

    return UI.Panel {
        width = "100%",
        height = "100%",
        backgroundColor = WX.bg,
        flexDirection = "column",
        children = {
            wxContentContainer_,
            wxTabBarContainer_,
        },
    }
end

-- ============================================================================
-- 聊天列表实时刷新
-- ============================================================================

--- 检查并刷新聊天列表（由 main.lua HandleUpdate 调度）
function App.RefreshChatListIfDirty()
    if WechatData.ConsumeChatListDirty() then
        -- 仅在聊天列表 Tab 可见时重建
        if wxActiveTab_ == "chat" and wxContentContainer_ then
            wxContentContainer_:ClearChildren()
            wxContentContainer_:AddChild(App._createChatListPage())
        end
    end
end

return App
