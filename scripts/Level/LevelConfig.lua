-- ============================================================================
-- LevelConfig - 关卡配置加载器
-- 功能: 加载并解析关卡数据包（CSV 文件集）
-- 路径: scripts/data/levels/{levelId}/
-- ============================================================================

local CSVParser = require("Utils.CSVParser")
local Log = require("Utils.Logger")

local LevelConfig = {}

local TAG = "[LevelConfig]"

-- ============================================================================
-- 加载 API
-- ============================================================================

--- 加载关卡数据包
---@param levelId string 关卡 ID（如 "level1"）
---@return table|nil levelData 加载成功返回关卡数据，失败返回 nil
function LevelConfig.Load(levelId)
    local basePath = "data/levels/" .. levelId .. "/"
    Log.info(TAG, "加载关卡:", levelId)

    -- 1. 加载关卡元信息
    local config = LevelConfig.LoadConfig(basePath)
    if not config then
        Log.error(TAG, "config.csv 加载失败")
        return nil
    end

    -- 2. 加载消息时间轴
    local messages = LevelConfig.LoadMessages(basePath)

    -- 3. 加载聊天列表
    local chats = LevelConfig.LoadChats(basePath)

    -- 4. 加载反馈规则
    local feedbacks = LevelConfig.LoadFeedbacks(basePath)

    -- 5. 加载公告检查点
    local announcements = LevelConfig.LoadAnnouncements(basePath)

    local levelData = {
        id            = levelId,
        config        = config,
        messages      = messages,
        chats         = chats,
        feedbacks     = feedbacks,
        announcements = announcements,
    }

    Log.info(TAG, string.format("关卡加载完成: %s | 消息: %d | 聊天: %d | 反馈: %d | 公告检查点: %d",
        config.name or levelId,
        #messages, #chats, #feedbacks, #announcements))

    return levelData
end

--- 加载 config.csv — 关卡元信息
---@param basePath string
---@return table|nil
function LevelConfig.LoadConfig(basePath)
    local _, rows = CSVParser.Load(basePath .. "config.csv", TAG)
    if #rows == 0 then return nil end

    local row = rows[1]
    return {
        name         = row.name or "未命名关卡",
        duration     = tonumber(row.duration) or 600,
        startHour    = tonumber(row.start_hour) or 9,
        startMin     = tonumber(row.start_min) or 40,
        briefingText = row.briefing or "",
        objectiveText = row.objective or "",
    }
end

--- 加载 messages.csv — 时间轴消息
---@param basePath string
---@return table[]
function LevelConfig.LoadMessages(basePath)
    local _, rows = CSVParser.Load(basePath .. "messages.csv", TAG)
    local messages = {}

    for _, row in ipairs(rows) do
        messages[#messages + 1] = {
            timeOffset     = tonumber(row.time_offset) or 0,
            app            = row.app or "dingtalk",
            chat           = row.chat or "",
            sender         = row.sender or "",
            type           = row.type or "message",  -- message | wait_reply | system
            content        = row.content or "",
            priority       = row.priority or "normal", -- important | noise | normal
            forwardTarget  = row.forward_target or "",
            keywords       = row.keywords or "",
            replyHint      = row.reply_hint or "",
            chainId        = row.chain_id or "",  -- 信息链标识，用于结算分组
            chainName      = row.chain_name or "", -- 信息链名称，用于结算显示
        }
    end

    -- 按 timeOffset 排序
    table.sort(messages, function(a, b) return a.timeOffset < b.timeOffset end)
    return messages
end

--- 加载 chats.csv — 本关涉及的聊天列表
---@param basePath string
---@return table[]
function LevelConfig.LoadChats(basePath)
    local _, rows = CSVParser.Load(basePath .. "chats.csv", TAG)
    local chats = {}

    for _, row in ipairs(rows) do
        chats[#chats + 1] = {
            name     = row.name or "",
            app      = row.app or "dingtalk",
            iconBg   = row.icon_color or "",
            iconText = row.icon_text or "",
            isTarget = (row.is_forward_target == "yes"),
        }
    end

    return chats
end

--- 加载 feedbacks.csv — 反馈规则
---@param basePath string
---@return table[]
function LevelConfig.LoadFeedbacks(basePath)
    local _, rows = CSVParser.Load(basePath .. "feedbacks.csv", TAG)
    local feedbacks = {}

    for _, row in ipairs(rows) do
        feedbacks[#feedbacks + 1] = {
            trigger     = row.trigger or "",        -- on_correct:forward:聊天名 | on_timeout:forward:聊天名 | on_wrong_target:forward:聊天名
            sourceChat  = row.source_chat or "",
            delay       = tonumber(row.delay) or 0,
            app         = row.app or "dingtalk",
            chat        = row.chat or "",
            sender      = row.sender or "",
            content     = row.content or "",
        }
    end

    return feedbacks
end

--- 加载 announcement.csv — 公告检查点
---@param basePath string
---@return table[]
function LevelConfig.LoadAnnouncements(basePath)
    local _, rows = CSVParser.Load(basePath .. "announcement.csv", TAG)
    local announcements = {}

    for _, row in ipairs(rows) do
        announcements[#announcements + 1] = {
            checkTimeOffset  = tonumber(row.check_time_offset) or 0,
            requiredKeywords = row.required_keywords or "",
        }
    end

    return announcements
end

return LevelConfig
