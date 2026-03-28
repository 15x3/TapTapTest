-- ============================================================================
-- 叮叮数据模块 (DingTalk Data Module)
-- 功能: 从 CSV 文件加载数据，提供统一的数据访问接口
-- CSV 文件位于 data/ 目录下，策划可直接编辑调整
-- ============================================================================

local CSVParser = require "Utils.CSVParser"
local Colors = require "Utils.Colors"
local EventScheduler = require "Utils.EventScheduler"

local Data = {}

-- 便捷别名
local loadCSV = function(path) return CSVParser.Load(path, "[DingtalkData]") end
local resolveColor = Colors.Resolve

-- ============================================================================
-- 数据缓存（首次访问时从 CSV 加载，之后使用内存缓存）
-- ============================================================================

---@type table[]|nil
local cachedChats_ = nil
---@type table<string, table[]>|nil
local cachedContacts_ = nil
---@type table[]|nil
local cachedScenarios_ = nil
---@type table[]|nil
local cachedTodos_ = nil
---@type table[]|nil
local cachedDings_ = nil
---@type table[]|nil
local cachedCalendar_ = nil

--- 运行时消息存储（关卡系统动态添加的消息）
---@type table<string, table[]>
local runtimeMessages_ = {}

--- 消息监听器（chatName → callback(msg)）
---@type table<string, fun(msg: table)>
local messageListeners_ = {}

-- ============================================================================
-- 聊天列表
-- ============================================================================

--- 加载场景事件原始数据（内部缓存）
local function ensureScenarios()
    if cachedScenarios_ then return end

    local _, rows = loadCSV("data/chat_scenarios.csv")
    cachedScenarios_ = {}

    for _, row in ipairs(rows) do
        cachedScenarios_[#cachedScenarios_ + 1] = {
            id         = row.id or "",
            chat_match = row.chat_match or "*",
            delay      = tonumber(row.delay) or 0,
            type       = row.type or "message",
            sender     = row.sender or "",
            text       = row.text or "",
            next       = row.next or "",
            options    = row.options or "",
            timeout    = tonumber(row.timeout) or 0,
            default_next = row.default_next or "",
            tag        = row.tag or "",
            thresholds = row.thresholds or "",
            require_tag = row.require_tag or "",
            trigger_time = row.trigger_time or "",
        }

        -- 解析 trigger_time 并注册定时事件（格式: "HH:MM"）
        local tt = row.trigger_time or ""
        if tt ~= "" then
            local hStr, mStr = tt:match("^(%d+):(%d+)$")
            if hStr then
                local chatMatch = row.chat_match or "*"
                if chatMatch ~= "*" and chatMatch ~= "" then
                    EventScheduler.Register({
                        hour        = tonumber(hStr),
                        min         = tonumber(mStr),
                        app         = "dingtalk",
                        chatName    = chatMatch,
                        eventId     = (row.id and row.id ~= "") and row.id or nil,
                        once        = true,
                        require_tag = row.require_tag or "",
                    })
                end
            end
        end
    end
end

--- 获取聊天列表
---@return table[] 每项包含 { name, tag, tagColor, time, msg, badge, iconBg, iconText }
function Data.GetChats()
    if cachedChats_ then return cachedChats_ end

    local _, rows = loadCSV("data/chats.csv")
    cachedChats_ = {}

    -- 记录已有聊天名称，用于后续自动补全
    local existingNames = {}

    for _, row in ipairs(rows) do
        local badgeNum = tonumber(row.badge) or 0
        local iconText = (row.icon_text or ""):gsub("|", "\n")
        local chatName = row.name or ""

        cachedChats_[#cachedChats_ + 1] = {
            name     = chatName,
            tag      = row.tag or "",
            tagColor = resolveColor(row.tag_color),
            time     = row.time or "",
            msg      = row.msg or "",
            badge    = badgeNum,
            iconBg   = resolveColor(row.icon_color) or { 100, 100, 120, 255 },
            iconText = iconText,
        }
        existingNames[chatName] = true
    end

    -- 自动补全：扫描场景 CSV 中的 chat_match，为缺失的聊天自动生成入口
    ensureScenarios()
    local seenMatch = {}
    for _, ev in ipairs(cachedScenarios_) do
        local cm = ev.chat_match
        if cm ~= "*" and cm ~= "" and not seenMatch[cm] then
            seenMatch[cm] = true
            -- 检查是否已有对应的聊天入口（子字符串匹配，与 GetChatScenario 逻辑一致）
            local found = false
            for name, _ in pairs(existingNames) do
                if name:find(cm, 1, true) then
                    found = true
                    break
                end
            end
            if not found then
                -- 从该场景的第一条 message 事件提取预览信息
                local firstMsg = ""
                local firstSender = ""
                for _, sev in ipairs(cachedScenarios_) do
                    if sev.chat_match == cm and sev.type == "message" and sev.sender ~= "" then
                        firstSender = sev.sender
                        firstMsg = sev.text
                        break
                    end
                end
                local preview = firstSender ~= "" and (firstSender .. ": " .. firstMsg) or firstMsg
                cachedChats_[#cachedChats_ + 1] = {
                    name     = cm,
                    tag      = "",
                    tagColor = resolveColor("gray"),
                    time     = "",
                    msg      = preview,
                    badge    = 0,
                    iconBg   = resolveColor("gray") or { 100, 100, 120, 255 },
                    iconText = cm:sub(1, 4),
                }
                existingNames[cm] = true
            end
        end
    end

    return cachedChats_
end

-- ============================================================================
-- 通讯录
-- ============================================================================

--- 获取通讯录（按分组）
---@return table<string, table[]> key=组名, value=人员数组 { name, role, initial }
function Data.GetContacts()
    if cachedContacts_ then return cachedContacts_ end

    local _, rows = loadCSV("data/contacts.csv")
    cachedContacts_ = {}

    -- 使用有序 key 列表保持组顺序
    local groupOrder = {}

    for _, row in ipairs(rows) do
        local group = row.group or "未分组"
        if not cachedContacts_[group] then
            cachedContacts_[group] = {}
            groupOrder[#groupOrder + 1] = group
        end
        local people = cachedContacts_[group]
        people[#people + 1] = {
            name    = row.name or "",
            role    = row.role or "",
            initial = row.initial or "",
        }
    end

    -- 将组顺序存到元信息中，方便页面按 CSV 顺序遍历
    cachedContacts_._groupOrder = groupOrder

    return cachedContacts_
end

--- 获取通讯录分组的有序列表
---@return string[]
function Data.GetContactGroupOrder()
    local contacts = Data.GetContacts()
    return contacts._groupOrder or {}
end

-- ============================================================================
-- 聊天消息（从场景数据派生，供搜索等功能使用）
-- ============================================================================

--- 根据聊天名称获取对应的消息列表（从场景事件中提取 type=message 的事件）
---@param chatName string 聊天名称
---@return table[] 消息数组 { sender, text }
function Data.GetChatMessages(chatName)
    local events = Data.GetChatScenario(chatName)
    local matched = {}

    for _, ev in ipairs(events) do
        if ev.type == "message" then
            matched[#matched + 1] = {
                sender   = ev.sender,
                text     = ev.text,
            }
        end
    end

    return matched
end

-- ============================================================================
-- 聊天场景事件（事件驱动架构）
-- ============================================================================

--- 根据聊天名称获取对应的场景事件序列
---@param chatName string 聊天名称
---@return table[] 事件数组 { id, delay, type, sender, text, next, options, ... }
function Data.GetChatScenario(chatName)
    ensureScenarios()

    -- 先尝试匹配特定 chat_match 模式
    local matched = {}
    local hasSpecific = false

    for _, ev in ipairs(cachedScenarios_) do
        if ev.chat_match ~= "*" and chatName:find(ev.chat_match, 1, true) then
            matched[#matched + 1] = ev
            hasSpecific = true
        end
    end

    -- 如果没有匹配到特定事件，使用通用 "*" 事件
    if not hasSpecific then
        for _, ev in ipairs(cachedScenarios_) do
            if ev.chat_match == "*" then
                matched[#matched + 1] = ev
            end
        end
    end

    return matched
end

-- ============================================================================
-- 待办事项（支持运行时修改：切换完成状态、添加新待办）
-- ============================================================================

--- 获取待办列表
---@return table[] 每项 { text, done, priority, due }
function Data.GetTodos()
    if cachedTodos_ then return cachedTodos_ end

    local _, rows = loadCSV("data/todos.csv")
    cachedTodos_ = {}

    for _, row in ipairs(rows) do
        cachedTodos_[#cachedTodos_ + 1] = {
            text     = row.text or "",
            done     = (row.done == "yes"),
            priority = row.priority or "medium",
            due      = row.due or "",
        }
    end

    return cachedTodos_
end

--- 获取未完成待办数量
---@return number
function Data.GetPendingTodoCount()
    local todos = Data.GetTodos()
    local count = 0
    for _, todo in ipairs(todos) do
        if not todo.done then count = count + 1 end
    end
    return count
end

--- 切换待办完成状态
---@param index number 待办索引（Lua 从 1 开始）
function Data.ToggleTodo(index)
    local todos = Data.GetTodos()
    if index >= 1 and index <= #todos then
        todos[index].done = not todos[index].done
        if todos[index].done then
            todos[index].due = "已完成"
        end
    end
end

--- 添加新待办（插入到列表开头）
---@param text string 待办内容
---@param priority string 优先级 "high"/"medium"/"low"
function Data.AddTodo(text, priority)
    local todos = Data.GetTodos()
    table.insert(todos, 1, {
        text     = text,
        done     = false,
        priority = priority or "medium",
        due      = "今天",
    })
end

-- ============================================================================
-- DING 消息（支持运行时修改：标记已读）
-- ============================================================================

--- 获取 DING 列表
---@return table[] 每项 { sender, time, content, status, urgent }
function Data.GetDings()
    if cachedDings_ then return cachedDings_ end

    local _, rows = loadCSV("data/dings.csv")
    cachedDings_ = {}

    for _, row in ipairs(rows) do
        cachedDings_[#cachedDings_ + 1] = {
            sender  = row.sender or "",
            time    = row.time or "",
            content = row.content or "",
            status  = row.status or "read",
            urgent  = (row.urgent == "yes"),
        }
    end

    return cachedDings_
end

--- 获取未读 DING 数量
---@return number
function Data.GetUnreadDingCount()
    local dings = Data.GetDings()
    local count = 0
    for _, d in ipairs(dings) do
        if d.status == "unread" then count = count + 1 end
    end
    return count
end

--- 将所有未读 DING 标记为已读
function Data.MarkAllDingRead()
    local dings = Data.GetDings()
    for _, d in ipairs(dings) do
        if d.status == "unread" then
            d.status = "read"
        end
    end
end

-- ============================================================================
-- 日历日程
-- ============================================================================

--- 获取日历事件
---@return table[] 每项 { dayOffset, time, title, color }
function Data.GetCalendarEvents()
    if cachedCalendar_ then return cachedCalendar_ end

    local _, rows = loadCSV("data/calendar.csv")
    cachedCalendar_ = {}

    for _, row in ipairs(rows) do
        cachedCalendar_[#cachedCalendar_ + 1] = {
            dayOffset = tonumber(row.day_offset) or 0,
            time      = row.time or "",
            title     = row.title or "",
            color     = resolveColor(row.color) or { 48, 118, 255, 255 },
        }
    end

    return cachedCalendar_
end

-- ============================================================================
-- 全局搜索
-- ============================================================================

--- 搜索所有数据，返回分类结果
---@param keyword string 搜索关键词
---@return table|nil { contacts, chats, todos, dings, calendar }
function Data.SearchAll(keyword)
    if not keyword or keyword == "" then return nil end
    local kw = string.lower(keyword)

    local function match(text)
        if not text then return false end
        return string.find(string.lower(text), kw, 1, true) ~= nil
    end

    local results = { contacts = {}, chats = {}, todos = {}, dings = {}, calendar = {} }
    local seenContact = {}  -- 去重

    -- 1. 联系人
    local contactsData = Data.GetContacts()
    for group, people in pairs(contactsData) do
        if type(people) == "table" and group ~= "_groupOrder" then
            for _, p in ipairs(people) do
                if match(p.name) or match(p.role) or match(group) then
                    local key = p.name .. "|" .. (p.role or "")
                    if not seenContact[key] then
                        seenContact[key] = true
                        results.contacts[#results.contacts + 1] = {
                            name = p.name, role = p.role, initial = p.initial, group = group,
                        }
                    end
                end
            end
        end
    end

    -- 2. 群聊 / 会话
    local chats = Data.GetChats()
    for _, chat in ipairs(chats) do
        if match(chat.name) or match(chat.msg) or match(chat.tag) then
            results.chats[#results.chats + 1] = chat
        end
    end

    -- 3. 待办
    local todos = Data.GetTodos()
    for _, todo in ipairs(todos) do
        if match(todo.text) or match(todo.due) then
            results.todos[#results.todos + 1] = todo
        end
    end

    -- 4. DING
    local dings = Data.GetDings()
    for _, d in ipairs(dings) do
        if match(d.sender) or match(d.content) then
            results.dings[#results.dings + 1] = d
        end
    end

    -- 5. 日历日程
    local calEvents = Data.GetCalendarEvents()
    local dayDescs = { [0] = "今日日程", [1] = "明日日程" }
    for _, ev in ipairs(calEvents) do
        if match(ev.title) then
            results.calendar[#results.calendar + 1] = {
                title = ev.title,
                time  = ev.time,
                desc  = dayDescs[ev.dayOffset] or (ev.dayOffset .. "日后"),
            }
        end
    end

    return results
end

-- ============================================================================
-- 运行时消息管理（关卡系统使用）
-- ============================================================================

--- 添加运行时消息到指定聊天
---@param chatName string
---@param sender string
---@param text string
function Data.AddMessage(chatName, sender, text, extra)
    if not runtimeMessages_[chatName] then
        runtimeMessages_[chatName] = {}
    end
    local msgs = runtimeMessages_[chatName]
    local entry = {
        sender = sender,
        text   = text,
    }
    -- 合并额外字段（关卡系统可附加 chat, forwardTarget, chainId 等）
    if extra then
        for k, v in pairs(extra) do
            entry[k] = v
        end
    end
    msgs[#msgs + 1] = entry
    -- 更新聊天列表预览
    Data.UpdateChatPreview(chatName, sender .. ": " .. text)
    -- 通知监听器
    local listener = messageListeners_[chatName]
    if listener then
        listener(entry)
    end
end

--- 获取指定聊天的运行时消息
---@param chatName string
---@return table[]
function Data.GetRuntimeMessages(chatName)
    return runtimeMessages_[chatName] or {}
end

--- 注册消息监听器（聊天页面打开时调用）
---@param chatName string
---@param callback fun(msg: table)
function Data.SetMessageListener(chatName, callback)
    messageListeners_[chatName] = callback
end

--- 移除消息监听器（聊天页面关闭时调用）
---@param chatName string
function Data.RemoveMessageListener(chatName)
    messageListeners_[chatName] = nil
end

--- 确保聊天列表中存在指定聊天，不存在则创建
---@param chatName string
---@param iconBg string|table|nil 图标背景色
---@param iconText string|nil 图标文字
---@return table chatData
function Data.EnsureChat(chatName, iconBg, iconText)
    local chats = Data.GetChats()
    for _, chat in ipairs(chats) do
        if chat.name == chatName then
            return chat
        end
    end
    local initial = string.sub(chatName, 1, 4)
    local bgColor = iconBg
    if type(iconBg) == "string" and iconBg ~= "" then
        bgColor = resolveColor(iconBg) or { 100, 100, 120, 255 }
    elseif type(iconBg) ~= "table" then
        bgColor = { 100, 100, 120, 255 }
    end
    local newChat = {
        name     = chatName,
        tag      = "",
        tagColor = nil,
        time     = "",
        msg      = "",
        badge    = 0,
        iconBg   = bgColor,
        iconText = iconText or initial,
    }
    table.insert(chats, 1, newChat)
    return newChat
end

--- 聊天列表脏标记（UpdateChatPreview 时置 true，UI 消费后置 false）
local chatListDirty_ = false

--- 更新聊天列表中某个聊天的最后一条消息摘要
---@param chatName string
---@param lastMsg string
function Data.UpdateChatPreview(chatName, lastMsg)
    local chats = Data.GetChats()
    for _, chat in ipairs(chats) do
        if chat.name == chatName then
            chat.msg = lastMsg
            chat.time = "刚刚"
            chatListDirty_ = true
            return
        end
    end
end

--- 检查并消费聊天列表脏标记
---@return boolean 是否有更新
function Data.ConsumeChatListDirty()
    if chatListDirty_ then
        chatListDirty_ = false
        return true
    end
    return false
end

-- ============================================================================
-- 热重载支持
-- ============================================================================

--- 本模块依赖的所有 CSV 文件路径
Data.CSV_PATHS = {
    "data/chats.csv",
    "data/contacts.csv",
    "data/chat_scenarios.csv",
    "data/todos.csv",
    "data/dings.csv",
    "data/calendar.csv",
}

--- 清除所有内存缓存，下次访问时将重新从 CSV 读取
function Data.Invalidate()
    cachedChats_ = nil
    cachedContacts_ = nil
    cachedScenarios_ = nil
    cachedTodos_ = nil
    cachedDings_ = nil
    runtimeMessages_ = {}
    messageListeners_ = {}
    cachedCalendar_ = nil
    print("[DingtalkData] 缓存已清除，下次访问将重新加载 CSV")
end

return Data
