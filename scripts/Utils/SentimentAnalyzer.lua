-- ============================================================================
-- 轻量级语气与关键词分析器 (Sentiment & Keyword Analyzer)
-- 功能: 基于规则的中文文本语气判断 + 关键词匹配，用于对话分支选择
--
-- 语气类别:
--   positive  - 积极/同意/开心
--   negative  - 消极/拒绝/不满
--   question  - 疑问/询问
--   angry     - 愤怒/强烈不满
--   neutral   - 中性/平淡
--
-- 使用方式:
--   local SA = require("Utils.SentimentAnalyzer")
--   local sentiment = SA.Analyze("太好了！我很开心")  --> "positive"
--   local matched = SA.MatchKeywords("我想去爬山", "爬山,登山,运动")  --> true
--   local branch = SA.SelectBranch("我想去爬山", options)  --> bestOption
-- ============================================================================

local SA = {}

-- ============================================================================
-- 语气词典
-- ============================================================================

--- 积极语气词（权重: 词语 → 分数）
local POSITIVE_WORDS = {
    -- 肯定/同意
    ["好的"]   = 3, ["好"]     = 2, ["好啊"]   = 3, ["好呀"]   = 3,
    ["行"]     = 2, ["行啊"]   = 3, ["可以"]   = 2, ["没问题"] = 3,
    ["当然"]   = 3, ["必须"]   = 3, ["一定"]   = 2, ["同意"]   = 3,
    ["赞成"]   = 3, ["支持"]   = 3, ["对"]     = 1, ["对的"]   = 2,
    ["是的"]   = 2, ["嗯"]     = 1, ["嗯嗯"]   = 2, ["收到"]   = 2,
    ["了解"]   = 2, ["明白"]   = 2, ["OK"]     = 2, ["ok"]     = 2,
    ["好滴"]   = 3, ["好嘞"]   = 3, ["没毛病"] = 3, ["完全同意"] = 4,

    -- 开心/兴奋
    ["太好了"] = 4, ["太棒了"] = 4, ["真棒"]   = 3, ["厉害"]   = 3,
    ["开心"]   = 3, ["高兴"]   = 3, ["喜欢"]   = 3, ["爱"]     = 2,
    ["哈哈"]   = 3, ["哈哈哈"] = 4, ["嘿嘿"]   = 2, ["耶"]     = 3,
    ["赞"]     = 3, ["棒"]     = 2, ["酷"]     = 2, ["期待"]   = 3,
    ["兴奋"]   = 3, ["激动"]   = 3, ["感谢"]   = 3, ["谢谢"]   = 3,
    ["不错"]   = 2, ["挺好"]   = 2, ["可以的"] = 2,
}

--- 消极语气词
local NEGATIVE_WORDS = {
    -- 拒绝/否定
    ["不"]     = 2, ["不行"]   = 3, ["不好"]   = 3, ["不要"]   = 3,
    ["不想"]   = 3, ["不去"]   = 3, ["不了"]   = 3, ["算了"]   = 3,
    ["拒绝"]   = 4, ["反对"]   = 4, ["不同意"] = 4, ["不可以"] = 3,
    ["别"]     = 2, ["别了"]   = 3, ["免了"]   = 3, ["没兴趣"] = 4,
    ["不喜欢"] = 3, ["讨厌"]   = 3, ["无所谓"] = 2, ["随便"]   = 1,

    -- 悲伤/沮丧
    ["难过"]   = 3, ["伤心"]   = 3, ["失望"]   = 3, ["郁闷"]   = 3,
    ["烦"]     = 2, ["烦死了"] = 4, ["累"]     = 2, ["累了"]   = 3,
    ["唉"]     = 2, ["哎"]     = 2, ["呜呜"]   = 3, ["懒得"]   = 3,
    ["不想动"] = 3, ["麻烦"]   = 2, ["头疼"]   = 3,
}

--- 愤怒语气词
local ANGRY_WORDS = {
    ["生气"]   = 4, ["愤怒"]   = 5, ["气死"]   = 5, ["受不了"] = 4,
    ["过分"]   = 4, ["太过分"] = 5, ["无语"]   = 3, ["离谱"]   = 4,
    ["什么玩意"] = 4, ["搞什么"] = 4, ["凭什么"] = 4,
    ["滚"]     = 5, ["闭嘴"]   = 5, ["够了"]   = 3,
    ["混蛋"]   = 5, ["废物"]   = 5, ["垃圾"]   = 4,
}

--- 疑问语气词
local QUESTION_WORDS = {
    ["吗"]     = 2, ["呢"]     = 1, ["什么"]   = 2, ["怎么"]   = 2,
    ["为什么"] = 3, ["哪"]     = 2, ["哪里"]   = 2, ["哪个"]   = 2,
    ["谁"]     = 2, ["几"]     = 1, ["多少"]   = 2, ["如何"]   = 2,
    ["怎样"]   = 2, ["是否"]   = 2, ["能不能"] = 2, ["可不可以"] = 2,
    ["会不会"] = 2, ["有没有"] = 2, ["难道"]   = 3, ["真的吗"] = 3,
    ["确定"]   = 1,
}

-- ============================================================================
-- 标点符号语气分析
-- ============================================================================

--- 分析标点符号对语气的影响
---@param text string
---@return table {positive, negative, angry, question}
local function analyzePunctuation(text)
    local scores = { positive = 0, negative = 0, angry = 0, question = 0 }

    -- 问号 → 疑问
    local questionCount = 0
    for _ in text:gmatch("？") do questionCount = questionCount + 1 end
    for _ in text:gmatch("%?") do questionCount = questionCount + 1 end
    scores.question = scores.question + questionCount * 2

    -- 感叹号 → 强调（根据上下文可能是积极或愤怒）
    local exclamCount = 0
    for _ in text:gmatch("！") do exclamCount = exclamCount + 1 end
    for _ in text:gmatch("!") do exclamCount = exclamCount + 1 end
    -- 多个感叹号倾向愤怒
    if exclamCount >= 3 then
        scores.angry = scores.angry + exclamCount
    elseif exclamCount > 0 then
        scores.positive = scores.positive + 1  -- 轻度正面强调
    end

    -- 省略号 → 犹豫/消极
    local ellipsisCount = 0
    for _ in text:gmatch("%.%.%.") do ellipsisCount = ellipsisCount + 1 end
    for _ in text:gmatch("…") do ellipsisCount = ellipsisCount + 1 end
    scores.negative = scores.negative + ellipsisCount

    return scores
end

-- ============================================================================
-- 核心分析函数
-- ============================================================================

--- 分析文本语气
---@param text string 待分析的文本
---@return string sentiment 语气类别: "positive"|"negative"|"angry"|"question"|"neutral"
---@return table scores 各维度分数 {positive, negative, angry, question}
function SA.Analyze(text)
    if not text or text == "" then
        return "neutral", { positive = 0, negative = 0, angry = 0, question = 0 }
    end

    local scores = { positive = 0, negative = 0, angry = 0, question = 0 }

    -- 1. 关键词匹配
    for word, weight in pairs(POSITIVE_WORDS) do
        if text:find(word, 1, true) then
            scores.positive = scores.positive + weight
        end
    end

    for word, weight in pairs(NEGATIVE_WORDS) do
        if text:find(word, 1, true) then
            scores.negative = scores.negative + weight
        end
    end

    for word, weight in pairs(ANGRY_WORDS) do
        if text:find(word, 1, true) then
            scores.angry = scores.angry + weight
        end
    end

    for word, weight in pairs(QUESTION_WORDS) do
        if text:find(word, 1, true) then
            scores.question = scores.question + weight
        end
    end

    -- 2. 标点符号分析
    local punctScores = analyzePunctuation(text)
    scores.positive = scores.positive + punctScores.positive
    scores.negative = scores.negative + punctScores.negative
    scores.angry    = scores.angry    + punctScores.angry
    scores.question = scores.question + punctScores.question

    -- 3. 判定最终语气
    -- 愤怒优先级最高
    if scores.angry >= 4 then
        return "angry", scores
    end

    -- 找最高分
    local maxScore = 0
    local maxSentiment = "neutral"

    if scores.positive > maxScore then
        maxScore = scores.positive
        maxSentiment = "positive"
    end
    if scores.negative > maxScore then
        maxScore = scores.negative
        maxSentiment = "negative"
    end
    if scores.question > maxScore then
        maxScore = scores.question
        maxSentiment = "question"
    end
    if scores.angry > maxScore then
        maxScore = scores.angry
        maxSentiment = "angry"
    end

    -- 分数太低视为中性
    if maxScore < 2 then
        return "neutral", scores
    end

    return maxSentiment, scores
end

-- ============================================================================
-- 关键词匹配
-- ============================================================================

--- 检查文本是否匹配关键词列表
---@param text string 用户输入的文本
---@param keywords string 竖线分隔的关键词列表，如 "爬山|登山|运动"
---@return boolean 是否匹配
---@return number score 匹配得分（匹配到的关键词数量）
function SA.MatchKeywords(text, keywords)
    if not text or text == "" or not keywords or keywords == "" then
        return false, 0
    end

    local score = 0
    for kw in keywords:gmatch("[^|]+") do
        local trimmed = kw:match("^%s*(.-)%s*$")
        if trimmed and trimmed ~= "" then
            if text:find(trimmed, 1, true) then
                score = score + 1
            end
        end
    end

    return score > 0, score
end

-- ============================================================================
-- 分支选择
-- ============================================================================

--- 解析分支选项
--- 格式: "关键词1|关键词2>跳转ID[:语气]; ..."
--- 示例: "爬山|登山|运动>ch_a1;海边|游泳>ch_b1:positive;休息|不去>ch_c1:negative"
--- 注意: 关键词之间用竖线"|"分隔（避免与 CSV 逗号冲突），分支之间用分号";"分隔
---
--- 语气标签（冒号后的部分）是可选的。如果指定了语气标签，
--- 在关键词都不匹配的情况下，会尝试通过语气来匹配分支。
---
---@param optionsStr string CSV 中的 options 字段
---@return table[] 解析后的选项列表
function SA.ParseBranchOptions(optionsStr)
    if not optionsStr or optionsStr == "" then return {} end

    local branches = {}
    for part in optionsStr:gmatch("[^;]+") do
        -- 尝试匹配: keywords>nextId 或 keywords>nextId:sentiment
        local keywordsPart, nextId = part:match("^(.-)>(.+)$")
        if keywordsPart and nextId then
            -- 检查 nextId 中是否含语气标签
            local actualNextId, sentiment = nextId:match("^(.-):(.+)$")
            if not actualNextId then
                actualNextId = nextId
                sentiment = nil
            end
            -- 去除空格
            actualNextId = actualNextId:match("^%s*(.-)%s*$")
            if sentiment then
                sentiment = sentiment:match("^%s*(.-)%s*$")
            end

            branches[#branches + 1] = {
                keywords  = keywordsPart,
                nextId    = actualNextId,
                sentiment = sentiment,  -- 可选：对应的语气标签
            }
        end
    end

    return branches
end

--- 根据用户输入文本选择最佳分支
---@param userText string 用户输入的文本
---@param branches table[] 由 ParseBranchOptions 返回的分支列表
---@param defaultNextId string|nil 默认跳转 ID（超时或无匹配时使用）
---@return string|nil nextId 匹配到的跳转 ID，nil 表示无匹配
---@return string matchType 匹配方式: "keyword"|"sentiment"|"default"|"none"
function SA.SelectBranch(userText, branches, defaultNextId)
    if not branches or #branches == 0 then
        return defaultNextId, defaultNextId and "default" or "none"
    end

    -- 第一优先级：关键词匹配
    local bestKeywordMatch = nil
    local bestKeywordScore = 0

    for _, branch in ipairs(branches) do
        local matched, score = SA.MatchKeywords(userText, branch.keywords)
        if matched and score > bestKeywordScore then
            bestKeywordScore = score
            bestKeywordMatch = branch.nextId
        end
    end

    if bestKeywordMatch then
        return bestKeywordMatch, "keyword"
    end

    -- 第二优先级：语气匹配（已禁用）
    -- 语气分析功能暂停，跳过语气匹配直接使用默认分支
    -- local userSentiment = SA.Analyze(userText)
    --
    -- for _, branch in ipairs(branches) do
    --     if branch.sentiment and branch.sentiment == userSentiment then
    --         return branch.nextId, "sentiment"
    --     end
    -- end

    -- 第三优先级（当前为第二优先级）：默认分支
    if defaultNextId and defaultNextId ~= "" then
        return defaultNextId, "default"
    end

    -- 无匹配：使用第一个分支作为 fallback
    if #branches > 0 then
        return branches[1].nextId, "default"
    end

    return nil, "none"
end

-- ============================================================================
-- 关键词计数 + 阈值分支（用于 thresholds 模式）
-- ============================================================================

--- 统计文本中匹配到的关键词总数
--- 关键词池为竖线分隔的字符串，从所有分支的 keywords 合并而来
---@param text string 用户输入的文本
---@param keywordPool string 竖线分隔的关键词池，如 "爬山|登山|运动|海边|游泳"
---@return number count 匹配到的关键词总数
function SA.CountKeywords(text, keywordPool)
    if not text or text == "" or not keywordPool or keywordPool == "" then
        return 0
    end
    local count = 0
    for kw in keywordPool:gmatch("[^|]+") do
        local trimmed = kw:match("^%s*(.-)%s*$")
        if trimmed and trimmed ~= "" then
            if text:find(trimmed, 1, true) then
                count = count + 1
            end
        end
    end
    return count
end

--- 根据关键词匹配数量和阈值字符串选择分支
--- 格式: "branchA,3,branchB,1,branchC"
---   解析为: count>=3 → branchA, count>=1 → branchB, 否则 → branchC
---   规则: 逗号分隔，奇数位为分支ID，偶数位为阈值（数字），最后一个无阈值的为兜底分支
---@param count number 匹配到的关键词数量
---@param thresholdsStr string 阈值字符串
---@return string|nil nextId 匹配到的分支 ID
---@return string matchType "threshold" | "fallback" | "none"
function SA.SelectBranchByThresholds(count, thresholdsStr)
    if not thresholdsStr or thresholdsStr == "" then
        return nil, "none"
    end

    -- 解析阈值列表
    local parts = {}
    for part in thresholdsStr:gmatch("[^,]+") do
        local trimmed = part:match("^%s*(.-)%s*$")
        if trimmed and trimmed ~= "" then
            parts[#parts + 1] = trimmed
        end
    end

    -- 按 (branchId, threshold) 配对解析
    -- 格式: branchA, 3, branchB, 1, branchC
    -- 最后一个如果没有配对数字，则为兜底分支
    local i = 1
    while i <= #parts do
        local branchId = parts[i]
        local thresholdStr = parts[i + 1]
        local threshold = tonumber(thresholdStr)

        if threshold then
            -- 有阈值: count >= threshold 则匹配
            if count >= threshold then
                return branchId, "threshold"
            end
            i = i + 2
        else
            -- 无阈值（最后的兜底分支）
            return branchId, "fallback"
        end
    end

    return nil, "none"
end

return SA
