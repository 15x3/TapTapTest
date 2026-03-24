-- ============================================================================
-- 钉钉应用壳模块 (DingTalk App Shell)
-- 功能: 钉钉应用的主框架（Tab 栏、导航、主内容区）
-- 依赖: DingtalkPages, DingtalkData
-- ============================================================================

local UI = require("urhox-libs/UI")
local DingtalkPages = require("DingtalkPages")
local DingtalkData = require("DingtalkData")

local App = {}

-- 钉钉颜色
local DT = {
    blue    = { 48, 118, 255, 255 },
    bg      = { 245, 245, 245, 255 },
    white   = { 255, 255, 255, 255 },
    text    = { 25, 25, 25, 255 },
    textSec = { 153, 153, 153, 255 },
    border  = { 235, 235, 235, 255 },
}

-- 模块级状态
local dtContentContainer_ = nil  -- 钉钉内容区容器
local dtActiveTab_ = "msg"       -- 当前激活的底部 Tab
local dtTabBarContainer_ = nil   -- 底部 Tab 栏容器
local goHomeFn_ = nil            -- 返回主屏幕的回调

-- ============================================================================
-- 导航系统
-- ============================================================================

--- 钉钉子页面导航
local function navigateTo(page, chatData)
    if not dtContentContainer_ then return end
    dtContentContainer_:ClearChildren()

    local backToMain = function() navigateTo("main") end

    if page == "main" then
        dtContentContainer_:AddChild(App._createMainContent())
    elseif page == "calendar" then
        dtContentContainer_:AddChild(DingtalkPages.CreateCalendarPage(backToMain))
    elseif page == "todo" then
        dtContentContainer_:AddChild(DingtalkPages.CreateTodoPage(backToMain))
    elseif page == "ding" then
        dtContentContainer_:AddChild(DingtalkPages.CreateDingPage(backToMain))
    elseif page == "chat" and chatData then
        dtContentContainer_:AddChild(DingtalkPages.CreateChatPage(chatData.name, chatData.iconBg, backToMain))
    end
end

--- 通讯录子页面导航
local function contactsNavigateTo(title)
    if not dtContentContainer_ then return end
    dtContentContainer_:ClearChildren()
    local backToContacts = function() App.switchTab("contacts") end
    dtContentContainer_:AddChild(DingtalkPages.CreateContactDetailPage(title, backToContacts))
end

--- 搜索页面导航
local function navigateToSearch()
    if not dtContentContainer_ then return end
    dtContentContainer_:ClearChildren()
    local backToMain = function() App.switchTab("msg") end

    -- 搜索结果点击后的导航回调
    local function searchNavigate(target, data)
        if not dtContentContainer_ then return end
        dtContentContainer_:ClearChildren()
        local backToSearch = function() navigateToSearch() end

        if target == "chat" and data then
            dtContentContainer_:AddChild(DingtalkPages.CreateChatPage(data.name, data.iconBg, backToSearch))
        elseif target == "contact" and data then
            dtContentContainer_:AddChild(DingtalkPages.CreateContactDetailPage(data.group, backToSearch))
        elseif target == "todo" then
            dtContentContainer_:AddChild(DingtalkPages.CreateTodoPage(backToSearch))
        elseif target == "ding" then
            dtContentContainer_:AddChild(DingtalkPages.CreateDingPage(backToSearch))
        elseif target == "calendar" then
            dtContentContainer_:AddChild(DingtalkPages.CreateCalendarPage(backToSearch))
        end
    end

    dtContentContainer_:AddChild(DingtalkPages.CreateSearchPage(backToMain, searchNavigate))
end

-- ============================================================================
-- Tab 栏
-- ============================================================================

--- 刷新底部 Tab 栏高亮状态
local function refreshTabBar()
    if not dtTabBarContainer_ then return end
    dtTabBarContainer_:ClearChildren()

    local tabs = {
        { id = "msg",      label = "消息",   icon = "MSG", badge = 99 },
        { id = "contacts", label = "通讯录", icon = "DIR", badge = 0 },
        { id = "more",     label = "更多",   icon = "...", badge = 0 },
    }

    for _, tab in ipairs(tabs) do
        dtTabBarContainer_:AddChild(App._createTab(tab, tab.id == dtActiveTab_))
    end
end

--- 切换底部 Tab
function App.switchTab(tabId)
    dtActiveTab_ = tabId
    if not dtContentContainer_ then return end
    dtContentContainer_:ClearChildren()

    if tabId == "msg" then
        dtContentContainer_:AddChild(App._createMainContent())
    elseif tabId == "contacts" then
        dtContentContainer_:AddChild(DingtalkPages.CreateContactsPage(contactsNavigateTo))
    elseif tabId == "more" then
        dtContentContainer_:AddChild(DingtalkPages.CreateMorePage())
    end

    refreshTabBar()
end

-- ============================================================================
-- UI 组件
-- ============================================================================

--- 创建钉钉主页面内容（搜索栏 + 快捷栏 + 会话列表）
function App._createMainContent()
    local chatList = DingtalkData.GetChats()

    local chatItems = {}
    for _, chat in ipairs(chatList) do
        chatItems[#chatItems + 1] = App._createChatItem(chat)
    end

    -- 快捷栏按钮创建器
    local function QuickBtn(label, badgeNum, onClick)
        local children = {
            UI.Label { text = label, fontSize = 11, fontColor = DT.textSec, pointerEvents = "none" },
        }
        if badgeNum and badgeNum > 0 then
            children[#children + 1] = UI.Panel {
                width = 14, height = 14,
                backgroundColor = { 250, 80, 80, 255 },
                borderRadius = 7,
                justifyContent = "center",
                alignItems = "center",
                marginLeft = 2,
                pointerEvents = "none",
                children = {
                    UI.Label { text = tostring(badgeNum), fontSize = 8, fontColor = { 255, 255, 255, 255 } },
                },
            }
        end
        return UI.Button {
            height = 30,
            paddingHorizontal = 8,
            backgroundColor = { 0, 0, 0, 0 },
            hoverBackgroundColor = { 0, 0, 0, 10 },
            pressedBackgroundColor = { 0, 0, 0, 20 },
            borderRadius = 4,
            flexDirection = "row",
            alignItems = "center",
            onClick = function(self) onClick() end,
            children = children,
        }
    end

    return UI.Panel {
        width = "100%",
        height = "100%",
        backgroundColor = DT.white,
        flexDirection = "column",
        children = {
            -- 顶部导航栏
            UI.Panel {
                width = "100%",
                height = 44,
                backgroundColor = DT.white,
                flexDirection = "row",
                alignItems = "center",
                justifyContent = "space-between",
                paddingHorizontal = 12,
                borderBottomWidth = 1,
                borderBottomColor = DT.border,
                children = {
                    UI.Button {
                        width = 30, height = 30,
                        backgroundColor = { 0, 0, 0, 0 },
                        hoverBackgroundColor = { 0, 0, 0, 15 },
                        pressedBackgroundColor = { 0, 0, 0, 30 },
                        borderRadius = 4,
                        text = "<",
                        textColor = DT.text,
                        fontSize = 14,
                        onClick = function(self)
                            if goHomeFn_ then goHomeFn_() end
                        end,
                    },
                    UI.Button {
                        flexGrow = 1, flexBasis = 0, flexShrink = 1,
                        height = 30,
                        backgroundColor = { 242, 242, 242, 255 },
                        hoverBackgroundColor = { 235, 235, 235, 255 },
                        pressedBackgroundColor = { 225, 225, 225, 255 },
                        borderRadius = 15,
                        marginHorizontal = 8,
                        justifyContent = "center",
                        paddingHorizontal = 10,
                        onClick = function(self) navigateToSearch() end,
                        children = {
                            UI.Label { text = "搜索", fontSize = 11, fontColor = { 180, 180, 180, 255 }, pointerEvents = "none" },
                        },
                    },
                    UI.Panel {
                        width = 26, height = 26,
                        backgroundColor = DT.blue,
                        borderRadius = 13,
                        justifyContent = "center",
                        alignItems = "center",
                        children = {
                            UI.Label { text = "+", fontSize = 14, fontColor = DT.white },
                        },
                    },
                },
            },

            -- 功能快捷栏
            UI.Panel {
                width = "100%",
                height = 36,
                backgroundColor = DT.white,
                flexDirection = "row",
                alignItems = "center",
                paddingHorizontal = 8,
                gap = 4,
                borderBottomWidth = 1,
                borderBottomColor = DT.border,
                children = {
                    QuickBtn("日历", nil, function() navigateTo("calendar") end),
                    QuickBtn("待办", DingtalkData.GetPendingTodoCount(), function() navigateTo("todo") end),
                    QuickBtn("DING", DingtalkData.GetUnreadDingCount(), function() navigateTo("ding") end),
                },
            },

            -- 聊天列表（可滚动）
            UI.ScrollView {
                width = "100%",
                flexGrow = 1,
                flexBasis = 0,
                backgroundColor = DT.white,
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

--- 钉钉聊天列表项（可点击打开聊天详情）
function App._createChatItem(chat)
    local nameChildren = {
        UI.Label {
            text = chat.name,
            fontSize = 12,
            fontColor = DT.text,
            maxLines = 1,
            flexShrink = 1,
        },
    }
    if chat.tag and chat.tag ~= "" then
        nameChildren[#nameChildren + 1] = UI.Panel {
            paddingHorizontal = 4,
            paddingVertical = 1,
            backgroundColor = { chat.tagColor[1], chat.tagColor[2], chat.tagColor[3], 30 },
            borderRadius = 2,
            marginLeft = 4,
            children = {
                UI.Label { text = chat.tag, fontSize = 8, fontColor = chat.tagColor },
            },
        }
    end

    local badgeWidget = nil
    if chat.badge and chat.badge > 0 then
        badgeWidget = UI.Panel {
            position = "absolute",
            top = -2, right = -2,
            width = 14, height = 14,
            backgroundColor = { 255, 60, 60, 255 },
            borderRadius = 7,
            justifyContent = "center",
            alignItems = "center",
            children = {
                UI.Label { text = tostring(chat.badge), fontSize = 8, fontColor = { 255, 255, 255, 255 } },
            },
        }
    end

    local iconChildren = {
        UI.Label {
            text = chat.iconText,
            fontSize = 8,
            fontColor = { 255, 255, 255, 255 },
            textAlign = "center",
        },
    }
    if badgeWidget then
        iconChildren[#iconChildren + 1] = badgeWidget
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
        borderBottomColor = { 245, 245, 245, 255 },
        onClick = function(self)
            navigateTo("chat", chat)
        end,
        children = {
            -- 头像
            UI.Panel {
                width = 44, height = 44,
                backgroundColor = chat.iconBg,
                borderRadius = 8,
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
                pointerEvents = "none",
                children = {
                    UI.Panel {
                        flexDirection = "row",
                        justifyContent = "space-between",
                        alignItems = "center",
                        children = {
                            UI.Panel {
                                flexDirection = "row",
                                alignItems = "center",
                                flexShrink = 1,
                                children = nameChildren,
                            },
                            UI.Label { text = chat.time, fontSize = 9, fontColor = DT.textSec },
                        },
                    },
                    UI.Label {
                        text = chat.msg,
                        fontSize = 10,
                        fontColor = DT.textSec,
                        maxLines = 1,
                    },
                },
            },
        },
    }
end

--- 钉钉底部导航 tab
function App._createTab(tab, isActive)
    local tabColor = isActive and DT.blue or DT.textSec
    local iconChildren = {
        UI.Label {
            text = tab.icon,
            fontSize = 10,
            fontColor = tabColor,
            textAlign = "center",
            pointerEvents = "none",
        },
    }

    if tab.badge and tab.badge > 0 then
        local badgeText = tab.badge > 99 and "99+" or tostring(tab.badge)
        iconChildren[#iconChildren + 1] = UI.Panel {
            position = "absolute",
            top = -4, right = -8,
            height = 13, minWidth = 13,
            paddingHorizontal = 3,
            backgroundColor = { 255, 60, 60, 255 },
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
        hoverBackgroundColor = { 0, 0, 0, 10 },
        pressedBackgroundColor = { 0, 0, 0, 20 },
        borderRadius = 0,
        flexDirection = "column",
        alignItems = "center",
        justifyContent = "center",
        gap = 2,
        onClick = function(self)
            if tab.id and tab.id ~= dtActiveTab_ then
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

--- 创建完整的钉钉应用界面
---@param onGoHome fun() 返回主屏幕的回调
---@return table UI 组件
function App.Create(onGoHome)
    goHomeFn_ = onGoHome

    -- 内容容器
    dtContentContainer_ = UI.Panel {
        width = "100%",
        flexGrow = 1,
        flexBasis = 0,
        flexDirection = "column",
        overflow = "hidden",
        children = {
            App._createMainContent(),
        },
    }

    -- 底部 Tab 栏容器
    dtTabBarContainer_ = UI.Panel {
        width = "100%",
        height = 50,
        backgroundColor = DT.white,
        flexDirection = "row",
        alignItems = "center",
        justifyContent = "space-around",
        borderTopWidth = 1,
        borderTopColor = DT.border,
    }

    -- 初始化 Tab 栏内容
    dtActiveTab_ = "msg"
    refreshTabBar()

    return UI.Panel {
        width = "100%",
        height = "100%",
        backgroundColor = DT.bg,
        flexDirection = "column",
        children = {
            dtContentContainer_,
            dtTabBarContainer_,
        },
    }
end

return App
