-- ============================================================================
-- 微言数据模块 (WeChat Data Module)
-- 功能: 从 CSV 文件加载数据，提供统一的数据访问接口
-- ============================================================================

local CSVParser = require "Utils.CSVParser"
local Colors = require "Utils.Colors"
local EventScheduler = require "Utils.EventScheduler"

local Data = {}

-- 便捷别名
local loadCSV = function(path) return CSVParser.Load(path, "[WechatData]") end
local resolveColor = Colors.Resolve

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

--- 加载场景事件原始数据（内部缓存）
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
                        app         = "wechat",
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

function Data.GetChats()
    if cachedChats_ then return cachedChats_ end

    local _, rows = loadCSV("data/wechat_chats.csv")
    cachedChats_ = {}

    -- 记录已有聊天名称，用于后续自动补全
    local existingNames = {}

    for _, row in ipairs(rows) do
        local badgeNum = tonumber(row.badge) or 0
        local chatName = row.name or ""
        cachedChats_[#cachedChats_ + 1] = {
            name     = chatName,
            time     = row.time or "",
            msg      = row.msg or "",
            badge    = badgeNum,
            iconBg   = resolveColor(row.icon_color) or { 100, 100, 120, 255 },
            iconText = row.icon_text or "",
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

--- 消息监听器（chatName → callback(msg)）
---@type table<string, fun(msg: table)>
local messageListeners_ = {}

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
function Data.AddMessage(chatName, sender, text, extra)
    if not runtimeMessages_[chatName] then
        runtimeMessages_[chatName] = {}
    end
    local msgs = runtimeMessages_[chatName]
    local entry = {
        sender   = sender,
        text     = text,
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
    "data/wechat_chats.csv",
    "data/wechat_contacts.csv",
    "data/wechat_scenarios.csv",
}

--- 清除所有内存缓存，下次访问时将重新从 CSV 读取
function Data.Invalidate()
    cachedChats_ = nil
    cachedContacts_ = nil
    cachedScenarios_ = nil
    runtimeMessages_ = {}
    messageListeners_ = {}
    print("[WechatData] 缓存已清除，下次访问将重新加载 CSV")
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
