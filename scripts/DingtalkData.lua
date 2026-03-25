-- ============================================================================
-- 钉钉数据模块 (DingTalk Data Module)
-- 功能: 从 CSV 文件加载数据，提供统一的数据访问接口
-- CSV 文件位于 data/ 目录下，策划可直接编辑调整
-- ============================================================================

local Data = {}

-- ============================================================================
-- CSV 解析器
-- ============================================================================

--- 从资源目录读取文件内容
---@param path string 资源路径（相对于 scripts/）
---@return string|nil
local function readFile(path)
    if not cache:Exists(path) then
        print("[DingtalkData] 文件不存在: " .. path)
        return nil
    end
    local file = cache:GetFile(path)
    if not file then
        print("[DingtalkData] 无法打开文件: " .. path)
        return nil
    end
    local content = file:ReadString()
    file:Close()
    return content
end

--- 解析 CSV 内容为行数组（表头 + 数据行）
--- 支持简单 CSV（不含引号包裹字段）
---@param content string CSV 文本内容
---@return string[] headers 表头字段名数组
---@return table[] rows 数据行数组，每行为 { [字段名] = 值 } 的表
local function parseCSV(content)
    if not content or content == "" then return {}, {} end

    local lines = {}
    -- 按行分割（兼容 \r\n 和 \n）
    for line in content:gmatch("[^\r\n]+") do
        -- 跳过空行
        if line:match("%S") then
            lines[#lines + 1] = line
        end
    end

    if #lines < 1 then return {}, {} end

    -- 解析表头
    local headers = {}
    for field in lines[1]:gmatch("([^,]*)") do
        headers[#headers + 1] = field:match("^%s*(.-)%s*$")  -- trim
    end

    -- 解析数据行
    local rows = {}
    for i = 2, #lines do
        local row = {}
        local colIdx = 1
        for field in lines[i]:gmatch("([^,]*)") do
            local key = headers[colIdx]
            if key then
                row[key] = field:match("^%s*(.-)%s*$")  -- trim
            end
            colIdx = colIdx + 1
        end
        rows[#rows + 1] = row
    end

    return headers, rows
end

--- 加载并解析 CSV 文件
---@param path string
---@return string[] headers
---@return table[] rows
local function loadCSV(path)
    local content = readFile(path)
    if not content then return {}, {} end
    return parseCSV(content)
end

-- ============================================================================
-- 颜色预设映射（策划用命名颜色代替 RGBA）
-- ============================================================================

local COLOR_PRESETS = {
    blue       = { 48, 118, 255, 255 },
    red        = { 220, 60, 60, 255 },
    gray       = { 100, 100, 120, 255 },
    orange     = { 255, 140, 0, 255 },
    green      = { 60, 180, 80, 255 },
    dark_blue  = { 80, 120, 200, 255 },
    light_blue = { 100, 130, 200, 255 },
    purple     = { 200, 80, 200, 255 },
}

--- 将颜色名称转为 RGBA 表
---@param name string 颜色名称（如 "blue"、"red"）
---@return table|nil RGBA 数组 { r, g, b, a }
local function resolveColor(name)
    if not name or name == "" then return nil end
    return COLOR_PRESETS[name]
end

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

-- ============================================================================
-- 聊天列表
-- ============================================================================

--- 获取聊天列表
---@return table[] 每项包含 { name, tag, tagColor, time, msg, badge, iconBg, iconText }
function Data.GetChats()
    if cachedChats_ then return cachedChats_ end

    local _, rows = loadCSV("data/chats.csv")
    cachedChats_ = {}

    for _, row in ipairs(rows) do
        local badgeNum = tonumber(row.badge) or 0
        local iconText = (row.icon_text or ""):gsub("|", "\n")

        cachedChats_[#cachedChats_ + 1] = {
            name     = row.name or "",
            tag      = row.tag or "",
            tagColor = resolveColor(row.tag_color),
            time     = row.time or "",
            msg      = row.msg or "",
            badge    = badgeNum,
            iconBg   = resolveColor(row.icon_color) or { 100, 100, 120, 255 },
            iconText = iconText,
        }
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
---@return table[] 消息数组 { sender, text, time, showTime }
function Data.GetChatMessages(chatName)
    local events = Data.GetChatScenario(chatName)
    local matched = {}

    for _, ev in ipairs(events) do
        if ev.type == "message" then
            matched[#matched + 1] = {
                sender   = ev.sender,
                text     = ev.text,
                time     = ev.time,
                showTime = ev.showTime,
            }
        end
    end

    return matched
end

-- ============================================================================
-- 聊天场景事件（事件驱动架构）
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
            time       = row.time or "",
            showTime   = (row.show_time == "yes"),
            next       = row.next or "",
            options    = row.options or "",
            timeout    = tonumber(row.timeout) or 0,
            default_next = row.default_next or "",
        }
    end
end

--- 根据聊天名称获取对应的场景事件序列
---@param chatName string 聊天名称
---@return table[] 事件数组 { id, delay, type, sender, text, time, showTime, next, options, ... }
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

return Data
