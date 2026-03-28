-- ============================================================================
-- 叮叮子页面模块 (DingTalk Sub-Pages Module)
-- 薄编排层：将各页面功能委托给 DingtalkPages/ 下的独立子模块
-- ============================================================================

local CalendarPage      = require("DingtalkPages.CalendarPage")
local TodoPage          = require("DingtalkPages.TodoPage")
local DingPage          = require("DingtalkPages.DingPage")
local ChatPage          = require("DingtalkPages.ChatPage")
local ContactDetailPage = require("DingtalkPages.ContactDetailPage")
local ContactsPage      = require("DingtalkPages.ContactsPage")
local SearchPage        = require("DingtalkPages.SearchPage")
local MorePage          = require("DingtalkPages.MorePage")
local AboutPage         = require("DingtalkPages.AboutPage")

local M = {}

--- 创建日历页面
---@param onBack function 返回回调
---@return table UI.Panel
function M.CreateCalendarPage(onBack)
    return CalendarPage.Create(onBack)
end

--- 创建待办页面
---@param onBack function 返回回调
---@return table UI.Panel
function M.CreateTodoPage(onBack)
    return TodoPage.Create(onBack)
end

--- 创建 DING 页面
---@param onBack function 返回回调
---@return table UI.Panel
function M.CreateDingPage(onBack)
    return DingPage.Create(onBack)
end

--- 创建聊天详情页面
---@param chatName string 聊天对象名称
---@param chatIconBg table 聊天图标背景色
---@param onBack function 返回回调
---@param onAnnounce function|nil 发布公告回调（仅班级群/家校群）
---@return table UI.Panel
function M.CreateChatPage(chatName, chatIconBg, onBack, onAnnounce)
    return ChatPage.Create(chatName, chatIconBg, onBack, onAnnounce)
end

--- 创建联系人详情页面
---@param title string 联系人/群组名称
---@param onBack function 返回回调
---@return table UI.Panel
function M.CreateContactDetailPage(title, onBack)
    return ContactDetailPage.Create(title, onBack)
end

--- 创建通讯录页面
---@param onNavigate function 导航回调
---@return table UI.Panel
function M.CreateContactsPage(onNavigate)
    return ContactsPage.Create(onNavigate)
end

--- 创建搜索页面
---@param onBack function 返回回调
---@param onNavigate function 导航回调
---@return table UI.Panel
function M.CreateSearchPage(onBack, onNavigate)
    return SearchPage.Create(onBack, onNavigate)
end

--- 创建更多页面
---@return table UI.Panel
function M.CreateMorePage()
    return MorePage.Create()
end

--- 创建关于页面
---@param onBack function 返回回调
---@return table UI.Panel
function M.CreateAboutPage(onBack)
    return AboutPage.Create(onBack)
end

return M
