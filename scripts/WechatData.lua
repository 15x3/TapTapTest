-- ============================================================================
-- 微信数据模块 (WeChat Data Module)
-- 功能: 从 CSV 文件加载数据，提供统一的数据访问接口
-- ============================================================================

local Data = {}

-- ============================================================================
-- CSV 解析器（复用钉钉的解析逻辑）
-- ============================================================================

local function readFile(path)
    if not cache:Exists(path) then
        print("[WechatData] 文件不存在: " .. path)
        return nil
    end
    local file = cache:GetFile(path)
    if not file then
        print("[WechatData] 无法打开文件: " .. path)
        return nil
    end
    local content = file:ReadString()
    file:Close()
    return content
end

local function parseCSV(content)
    if not content or content == "" then return {}, {} end
    local lines = {}
    for line in content:gmatch("[^\r\n]+") do
        if line:match("%S") then
            lines[#lines + 1] = line
        end
    end
    if #lines < 1 then return {}, {} end

    local headers = {}
    for field in lines[1]:gmatch("([^,]*)") do
        headers[#headers + 1] = field:match("^%s*(.-)%s*$")
    end

    local rows = {}
    for i = 2, #lines do
        local row = {}
        local colIdx = 1
        for field in lines[i]:gmatch("([^,]*)") do
            local key = headers[colIdx]
            if key then
                row[key] = field:match("^%s*(.-)%s*$")
            end
            colIdx = colIdx + 1
        end
        rows[#rows + 1] = row
    end
    return headers, rows
end

local function loadCSV(path)
    local content = readFile(path)
    if not content then return {}, {} end
    return parseCSV(content)
end

-- ============================================================================
-- 颜色预设
-- ============================================================================

local COLOR_PRESETS = {
    blue       = { 48, 118, 255, 255 },
    red        = { 220, 60, 60, 255 },
    gray       = { 120, 120, 140, 255 },
    orange     = { 255, 140, 0, 255 },
    green      = { 7, 193, 96, 255 },
    dark_blue  = { 40, 120, 200, 255 },
    light_blue = { 100, 160, 220, 255 },
    purple     = { 150, 80, 200, 255 },
    pink       = { 180, 130, 170, 255 },
    teal       = { 60, 140, 180, 255 },
    yellow     = { 230, 190, 50, 255 },
}

local function resolveColor(name)
    if not name or name == "" then return nil end
    return COLOR_PRESETS[name]
end

-- ============================================================================
-- 数据缓存
-- ============================================================================

---@type table[]|nil
local cachedChats_ = nil
---@type table[]|nil
local cachedContacts_ = nil
---@type table[]|nil
local cachedScenarios_ = nil

-- ============================================================================
-- 聊天列表
-- ============================================================================

function Data.GetChats()
    if cachedChats_ then return cachedChats_ end

    local _, rows = loadCSV("data/wechat_chats.csv")
    cachedChats_ = {}

    for _, row in ipairs(rows) do
        local badgeNum = tonumber(row.badge) or 0
        cachedChats_[#cachedChats_ + 1] = {
            name     = row.name or "",
            time     = row.time or "",
            msg      = row.msg or "",
            badge    = badgeNum,
            iconBg   = resolveColor(row.icon_color) or { 100, 100, 120, 255 },
            iconText = row.icon_text or "",
        }
    end

    return cachedChats_
end

-- ============================================================================
-- 通讯录
-- ============================================================================

function Data.GetContacts()
    if cachedContacts_ then return cachedContacts_ end

    local _, rows = loadCSV("data/wechat_contacts.csv")
    cachedContacts_ = {}

    for _, row in ipairs(rows) do
        cachedContacts_[#cachedContacts_ + 1] = {
            name    = row.name or "",
            initial = row.initial or "",
            remark  = row.remark or "",
            group   = row.group or "",
        }
    end

    -- 按 group（首字母）排序
    table.sort(cachedContacts_, function(a, b)
        if a.group == b.group then
            return a.name < b.name
        end
        return a.group < b.group
    end)

    return cachedContacts_
end

--- 获取联系人分组索引（按首字母）
---@return string[] 有序的首字母列表
function Data.GetContactGroups()
    local contacts = Data.GetContacts()
    local seen = {}
    local groups = {}
    for _, c in ipairs(contacts) do
        if not seen[c.group] then
            seen[c.group] = true
            groups[#groups + 1] = c.group
        end
    end
    return groups
end

--- 搜索联系人
---@param keyword string
---@return table[]
function Data.SearchContacts(keyword)
    if not keyword or keyword == "" then return {} end
    local kw = string.lower(keyword)
    local contacts = Data.GetContacts()
    local results = {}
    for _, c in ipairs(contacts) do
        if string.find(string.lower(c.name), kw, 1, true)
            or string.find(string.lower(c.remark), kw, 1, true)
            or string.find(string.lower(c.initial), kw, 1, true) then
            results[#results + 1] = c
        end
    end
    return results
end

-- ============================================================================
-- 聊天场景事件（事件驱动架构）
-- ============================================================================

local function ensureScenarios()
    if cachedScenarios_ then return end
    local _, rows = loadCSV("data/wechat_scenarios.csv")
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
---@return table[] 事件数组
function Data.GetChatScenario(chatName)
    ensureScenarios()
    local matched = {}
    local hasSpecific = false

    for _, ev in ipairs(cachedScenarios_) do
        if ev.chat_match ~= "*" and chatName:find(ev.chat_match, 1, true) then
            matched[#matched + 1] = ev
            hasSpecific = true
        end
    end

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
-- 聊天消息（从场景数据派生，供搜索等功能使用）
-- ============================================================================

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
-- 运行时消息管理
-- ============================================================================

--- 运行时发送的消息（内存中，按聊天名索引）
---@type table<string, table[]>
local runtimeMessages_ = {}

--- 获取某个聊天的运行时消息
---@param chatName string
---@return table[]
function Data.GetRuntimeMessages(chatName)
    return runtimeMessages_[chatName] or {}
end

--- 向某个聊天添加一条运行时消息
---@param chatName string
---@param sender string
---@param text string
function Data.AddMessage(chatName, sender, text)
    if not runtimeMessages_[chatName] then
        runtimeMessages_[chatName] = {}
    end
    local msgs = runtimeMessages_[chatName]
    -- 生成时间戳
    local hour = math.random(8, 22)
    local minute = math.random(0, 59)
    local timeStr = string.format("%02d:%02d", hour, minute)
    msgs[#msgs + 1] = {
        sender   = sender,
        text     = text,
        time     = timeStr,
        showTime = (#msgs == 0),
    }
end

--- 确保聊天列表中存在指定聊天，不存在则创建
--- 返回对应的 chatData
---@param contactName string
---@param iconBg table|nil
---@param iconText string|nil
---@return table chatData
function Data.EnsureChat(contactName, iconBg, iconText)
    local chats = Data.GetChats()
    -- 查找已存在的
    for _, chat in ipairs(chats) do
        if chat.name == contactName then
            return chat
        end
    end
    -- 不存在，插入到列表最前面
    local initial = string.sub(contactName, 1, 3)
    local newChat = {
        name     = contactName,
        time     = "刚刚",
        msg      = "",
        badge    = 0,
        iconBg   = iconBg or { 100, 160, 220, 255 },
        iconText = iconText or initial,
    }
    table.insert(chats, 1, newChat)
    return newChat
end

--- 更新聊天列表中某个聊天的最后一条消息摘要
---@param chatName string
---@param lastMsg string
function Data.UpdateChatPreview(chatName, lastMsg)
    local chats = Data.GetChats()
    for _, chat in ipairs(chats) do
        if chat.name == chatName then
            chat.msg = lastMsg
            chat.time = "刚刚"
            return
        end
    end
end

-- ============================================================================
-- 未读消息总数
-- ============================================================================

function Data.GetTotalUnreadCount()
    local chats = Data.GetChats()
    local count = 0
    for _, chat in ipairs(chats) do
        count = count + (chat.badge or 0)
    end
    return count
end

return Data
