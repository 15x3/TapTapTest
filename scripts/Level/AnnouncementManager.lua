-- ============================================================================
-- AnnouncementManager - 公告系统管理器
-- 功能: 管理班主任公告的发布、检查点关键词验证
-- 流程: 玩家随时可发布公告 → 特定时间点检查已发布内容是否包含必需关键词
-- ============================================================================

local SentimentAnalyzer = require("Utils.SentimentAnalyzer")
local Log = require("Utils.Logger")

local AnnouncementManager = {}

local TAG = "[AnnouncementManager]"

--- 公告检查点配置（来自 announcement.csv）
---@type table[]
local checkpoints_ = {}

--- 已发布的公告列表 { text=string, timestamp=number, elapsedAtPublish=number }
---@type table[]
local publishedAnnouncements_ = {}

--- 检查点执行记录 { checkTimeOffset=number, passed=boolean, matchedKeywords=number, totalKeywords=number }
---@type table[]
local checkResults_ = {}

--- 已执行过的检查点索引集合（避免重复检查）
---@type table<number, boolean>
local checkedIndices_ = {}

--- 外部回调
---@type table
local callbacks_ = {}

--- 是否已初始化
---@type boolean
local inited_ = false

-- ============================================================================
-- 核心 API
-- ============================================================================

--- 初始化公告管理器
---@param announcementData table[] 公告检查点列表（来自 LevelConfig.Load().announcements）
---@param cbs table|nil 回调函数:
---   onCheckResult(result) — 检查完成时的回调 { passed, matchedCount, totalCount, checkTimeOffset }
function AnnouncementManager.Init(announcementData, cbs)
    checkpoints_ = announcementData or {}
    publishedAnnouncements_ = {}
    checkResults_ = {}
    checkedIndices_ = {}
    callbacks_ = cbs or {}
    inited_ = true

    Log.info(TAG, string.format("初始化完成 | 检查点: %d 个", #checkpoints_))
end

--- 发布公告
---@param text string 公告文本
---@param elapsedSec number 发布时的关卡已流逝秒数
function AnnouncementManager.Publish(text, elapsedSec)
    if not inited_ then return end
    if not text or text == "" then
        Log.warn(TAG, "公告文本为空，忽略")
        return
    end

    publishedAnnouncements_[#publishedAnnouncements_ + 1] = {
        text = text,
        timestamp = os.time(),
        elapsedAtPublish = elapsedSec or 0,
    }

    Log.info(TAG, string.format("公告已发布 @%.0fs: %s", elapsedSec or 0, string.sub(text, 1, 40)))
end

--- 每帧/定时调用：检查是否有到期的检查点
---@param elapsedSec number 关卡已流逝秒数
function AnnouncementManager.CheckAtTime(elapsedSec)
    if not inited_ then return end

    for i, cp in ipairs(checkpoints_) do
        -- 跳过已执行的检查点
        if not checkedIndices_[i] and elapsedSec >= cp.checkTimeOffset then
            checkedIndices_[i] = true
            AnnouncementManager._executeCheck(i, cp, elapsedSec)
        end
    end
end

--- 执行单个检查点的关键词验证
---@param index number 检查点索引
---@param checkpoint table 检查点数据
---@param elapsedSec number 当前已流逝秒数
function AnnouncementManager._executeCheck(index, checkpoint, elapsedSec)
    local requiredKw = checkpoint.requiredKeywords or ""
    if requiredKw == "" then
        Log.warn(TAG, string.format("检查点 #%d 无关键词要求，跳过", index))
        return
    end

    -- 将所有已发布公告的文本合并，检查是否覆盖了必需关键词
    local allText = ""
    for _, ann in ipairs(publishedAnnouncements_) do
        allText = allText .. " " .. ann.text
    end

    -- 统计匹配的关键词数量
    local totalKw = 0
    local matchedKw = 0
    for kw in requiredKw:gmatch("[^|]+") do
        local trimmed = kw:match("^%s*(.-)%s*$")
        if trimmed and trimmed ~= "" then
            totalKw = totalKw + 1
            if allText:find(trimmed, 1, true) then
                matchedKw = matchedKw + 1
            end
        end
    end

    local passed = (matchedKw >= totalKw)  -- 全部关键词命中才算通过（AND逻辑）

    local result = {
        checkTimeOffset = checkpoint.checkTimeOffset,
        passed          = passed,
        matchedCount    = matchedKw,
        totalCount      = totalKw,
        publishedCount  = #publishedAnnouncements_,
    }
    checkResults_[#checkResults_ + 1] = result

    Log.info(TAG, string.format("检查点 @%ds: %s | 匹配 %d/%d 关键词 | 已发布 %d 条公告",
        checkpoint.checkTimeOffset,
        passed and "通过" or "未通过",
        matchedKw, totalKw,
        #publishedAnnouncements_))

    -- 回调通知
    if callbacks_.onCheckResult then
        callbacks_.onCheckResult(result)
    end
end

-- ============================================================================
-- 查询 API
-- ============================================================================

--- 获取已发布的公告列表
---@return table[]
function AnnouncementManager.GetPublished()
    return publishedAnnouncements_
end

--- 获取检查结果日志
---@return table[]
function AnnouncementManager.GetCheckResults()
    return checkResults_
end

--- 是否有未通过的检查点
---@return boolean
function AnnouncementManager.HasFailedChecks()
    for _, r in ipairs(checkResults_) do
        if not r.passed then return true end
    end
    return false
end

--- 获取完整日志（供结算使用）
---@return table
function AnnouncementManager.GetLog()
    return {
        published    = publishedAnnouncements_,
        checkResults = checkResults_,
    }
end

--- 重置
function AnnouncementManager.Reset()
    checkpoints_ = {}
    publishedAnnouncements_ = {}
    checkResults_ = {}
    checkedIndices_ = {}
    callbacks_ = {}
    inited_ = false
end

return AnnouncementManager
