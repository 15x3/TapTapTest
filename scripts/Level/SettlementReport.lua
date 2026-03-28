-- ============================================================================
-- SettlementReport - 关卡结算报告生成器
-- 功能: 汇总转发/回复/公告操作结果，按信息链分组，纯事实无评分
-- ============================================================================

local ForwardManager = require("Level.ForwardManager")
local ReplyManager = require("Level.ReplyManager")
local AnnouncementManager = require("Level.AnnouncementManager")
local Log = require("Utils.Logger")

local SettlementReport = {}

local TAG = "[SettlementReport]"

--- 生成结算报告
---@param levelData table 关卡数据（来自 LevelConfig.Load）
---@return table report { chains=[], announcements=[], summary={} }
function SettlementReport.Generate(levelData)
    local forwardLog = ForwardManager.GetLog()
    local replyLog = ReplyManager.GetLog()
    local announcementLog = AnnouncementManager.GetLog()

    -- 转发日志索引：chainId → entry[]（chainId 优先，兼容无 chainId 的旧数据回退到 msgChat）
    local forwardedByChain = {}
    for _, entry in ipairs(forwardLog) do
        local key = entry.chainId or entry.msgChat
        if not forwardedByChain[key] then
            forwardedByChain[key] = {}
        end
        local list = forwardedByChain[key]
        list[#list + 1] = entry
    end

    -- 回复日志索引：chat → entry
    local repliedToChat = {}
    for _, entry in ipairs(replyLog) do
        repliedToChat[entry.chat] = entry
    end

    -- 从关卡消息数据中提取信息链
    local chainMap = {}    -- chainId → { name, forwardMsgs[], replyMsgs[] }
    local chainOrder = {}  -- 保持插入顺序
    for _, msg in ipairs(levelData.messages) do
        local cid = msg.chainId
        if cid and cid ~= "" then
            if not chainMap[cid] then
                chainMap[cid] = {
                    name = msg.chainName or cid,
                    forwardMsgs = {},
                    replyMsgs = {},
                }
                chainOrder[#chainOrder + 1] = cid
            end
            if msg.forwardTarget and msg.forwardTarget ~= "" then
                chainMap[cid].forwardMsgs[#chainMap[cid].forwardMsgs + 1] = msg
            end
            if msg.type == "wait_reply" then
                chainMap[cid].replyMsgs[#chainMap[cid].replyMsgs + 1] = msg
            end
        end
    end

    -- 构建信息链结果
    local chains = {}
    local totalActions = 0
    local handledCount = 0
    local missedCount = 0
    local wrongCount = 0

    for _, cid in ipairs(chainOrder) do
        local chain = chainMap[cid]
        local hasActions = (#chain.forwardMsgs > 0 or #chain.replyMsgs > 0)
        if hasActions then
            local chainResult = {
                id = cid,
                name = chain.name,
                events = {},
            }

            -- 处理转发操作（按 chainId 匹配，同一链内去重）
            local processedKeys = {}
            for _, msg in ipairs(chain.forwardMsgs) do
                local lookupKey = msg.chainId or msg.chat
                if not processedKeys[lookupKey] then
                    processedKeys[lookupKey] = true
                    totalActions = totalActions + 1

                    local entries = forwardedByChain[lookupKey]
                    if entries then
                        local hasCorrect = false
                        for _, e in ipairs(entries) do
                            if e.isCorrect then hasCorrect = true end
                        end

                        if hasCorrect then
                            handledCount = handledCount + 1
                            chainResult.events[#chainResult.events + 1] = {
                                type = "forward",
                                result = "correct",
                                description = string.format("已将「%s」的消息转发到正确群组", msg.chat),
                            }
                        else
                            wrongCount = wrongCount + 1
                            chainResult.events[#chainResult.events + 1] = {
                                type = "forward",
                                result = "wrong",
                                description = string.format("将「%s」的消息转发到了错误群组", msg.chat),
                            }
                        end
                    else
                        missedCount = missedCount + 1
                        chainResult.events[#chainResult.events + 1] = {
                            type = "forward",
                            result = "missed",
                            description = string.format("未转发「%s」的重要消息", msg.chat),
                        }
                    end
                end
            end

            -- 处理回复操作
            for _, msg in ipairs(chain.replyMsgs) do
                totalActions = totalActions + 1

                local entry = repliedToChat[msg.chat]
                if entry then
                    if entry.result == "matched" then
                        handledCount = handledCount + 1
                        chainResult.events[#chainResult.events + 1] = {
                            type = "reply",
                            result = "correct",
                            description = string.format("已妥善回复「%s」", msg.chat),
                        }
                    elseif entry.result == "timeout" then
                        missedCount = missedCount + 1
                        chainResult.events[#chainResult.events + 1] = {
                            type = "reply",
                            result = "timeout",
                            description = string.format("未及时回复「%s」", msg.chat),
                        }
                    else
                        wrongCount = wrongCount + 1
                        chainResult.events[#chainResult.events + 1] = {
                            type = "reply",
                            result = "wrong",
                            description = string.format("对「%s」的回复不够准确", msg.chat),
                        }
                    end
                else
                    missedCount = missedCount + 1
                    chainResult.events[#chainResult.events + 1] = {
                        type = "reply",
                        result = "missed",
                        description = string.format("未回复「%s」的消息", msg.chat),
                    }
                end
            end

            if #chainResult.events > 0 then
                chains[#chains + 1] = chainResult
            end
        end
    end

    -- 公告结果
    local announcementResults = {}
    if announcementLog.checkResults then
        for _, cr in ipairs(announcementLog.checkResults) do
            totalActions = totalActions + 1
            if cr.passed then
                handledCount = handledCount + 1
            else
                missedCount = missedCount + 1
            end
            announcementResults[#announcementResults + 1] = {
                passed = cr.passed,
                matchedKw = cr.matchedCount,
                totalKw = cr.totalCount,
                description = cr.passed
                    and string.format("公告包含必要信息（%d/%d 关键词命中）", cr.matchedCount, cr.totalCount)
                    or "公告缺少必要信息或未发布公告",
            }
        end
    end

    local report = {
        chains = chains,
        announcements = announcementResults,
        summary = {
            total   = totalActions,
            handled = handledCount,
            missed  = missedCount,
            wrong   = wrongCount,
        },
    }

    Log.info(TAG, string.format("生成结算报告 | 总: %d | 处理: %d | 遗漏: %d | 错误: %d",
        totalActions, handledCount, missedCount, wrongCount))

    return report
end

return SettlementReport
