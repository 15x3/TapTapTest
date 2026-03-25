-- ============================================================================
-- 聊天事件管理器 (Chat Event Manager)
-- 功能: 状态机 + 时间轴调度器，驱动聊天剧情事件序列
--
-- 状态流:
--   processing → delay → (execute) → processing / wait_input / wait_choice / done
--
-- 分支选择模式:
--   type=choice 时，不再弹出选项按钮让玩家点选，
--   而是进入 wait_input 状态等待玩家输入文本，
--   然后通过关键词匹配 + 语气分析自动选择分支。
--
-- 自动输入功能（"随意敲打键盘"）:
--   由策划在 CSV 的 wait_input 行的 text 字段控制:
--     text 非空 → 启用自动输入，内容为 text 的值
--     text 为空 → 不启用，玩家自由打字
--
-- 回调接口:
--   onMessage(msg)   -- 收到一条消息事件（含 sender/text/time/showTime）
--   onTyping(sender)  -- 对方正在输入（用于显示 "xxx 正在输入..."）
--   onTypingEnd()     -- 输入指示结束
--   onAutoFill(partialText, isComplete) -- 自动填充进度更新
--   onBranchHint(hint) -- 分支匹配结果提示（关键词/语气/默认）
--   onDone()           -- 全部事件播放完毕
-- ============================================================================

local SentimentAnalyzer = require("Utils.SentimentAnalyzer")

local Manager = {}
Manager.__index = Manager

--- 创建事件管理器实例
---@param events table[] 事件序列（从 DingtalkData.GetChatScenario 获取）
---@param callbacks table 回调函数表 { onMessage, onTyping, onTypingEnd, onBranchHint, onDone }
---@return table 管理器实例
function Manager.Create(events, callbacks)
    local self = setmetatable({}, Manager)

    self.events = events or {}
    self.callbacks = callbacks or {}
    self.index = 1             -- 当前事件索引
    self.state = "processing"  -- processing | delay | wait_input | wait_choice | done
    self.delayTimer = 0        -- 延迟计时器
    self.delayTarget = 0       -- 延迟目标时间
    self.isTyping = false      -- 是否正在显示"输入中"

    -- 超时相关
    self.timeoutTimer = 0      -- 超时计时器
    self.timeoutTarget = 0     -- 超时目标时间（秒）
    self.timeoutNextId = ""    -- 超时跳转目标

    -- 分支选择相关（关键词+语气模式）
    self.pendingBranches = nil  -- 当前待匹配的分支选项（choice 事件解析后存储）
    self.pendingDefaultNext = "" -- choice 事件的 default_next

    -- "随意敲打键盘" 自动输入功能
    -- 由策划在 CSV 的 wait_input 行的 text 字段控制
    self.autoFillText = ""     -- 预设的自动填充文本（来自 CSV text 字段）
    self.autoFillIndex = 0     -- 当前已填充到第几个字符
    self.autoFillTotal = 0     -- 总字符数（UTF-8）
    self.autoFillEnabled = false -- 当前 wait_input 是否启用自动填充

    -- 立即处理所有 delay=0 的初始事件（历史消息）
    self:Process()

    return self
end

--- 每帧更新（由外部 Update 事件调用）
---@param dt number deltaTime
function Manager:Update(dt)
    if self.state == "delay" then
        self.delayTimer = self.delayTimer + dt
        if self.delayTimer >= self.delayTarget then
            self.delayTimer = 0
            self.delayTarget = 0
            -- 延迟结束，执行当前事件
            self:Execute()
        end
    elseif self.state == "wait_choice" and self.timeoutTarget > 0 then
        -- 超时逻辑：等待超时后自动跳转
        self.timeoutTimer = self.timeoutTimer + dt
        if self.timeoutTimer >= self.timeoutTarget then
            self.timeoutTimer = 0
            self.timeoutTarget = 0
            local nextId = self.timeoutNextId
            self.timeoutNextId = ""
            if nextId and nextId ~= "" then
                self:JumpTo(nextId)
                self.state = "processing"
                self:Process()
            else
                -- 无超时跳转目标，顺序推进
                self.index = self.index + 1
                self.state = "processing"
                self:Process()
            end
        end
    end
    -- wait_input / done 状态不做自动推进
end

--- 处理事件链（连续执行 delay=0 的事件，遇到非零 delay 或等待状态则停下）
function Manager:Process()
    while self.index <= #self.events do
        local event = self.events[self.index]
        local delay = tonumber(event.delay) or 0

        if delay > 0 then
            -- 需要延迟，进入 delay 状态
            self.state = "delay"
            self.delayTimer = 0
            self.delayTarget = delay
            return
        end

        -- delay == 0，立即执行
        local shouldContinue = self:Execute()
        if not shouldContinue then
            return  -- 执行后进入了等待状态，停止处理链
        end
    end

    -- 所有事件处理完毕
    self.state = "done"
    if self.callbacks.onDone then
        self.callbacks.onDone()
    end
end

--- 执行当前索引的事件
---@return boolean 是否可以继续处理下一个事件（false = 进入了等待状态）
function Manager:Execute()
    if self.index > #self.events then
        self.state = "done"
        if self.callbacks.onDone then
            self.callbacks.onDone()
        end
        return false
    end

    local event = self.events[self.index]
    local eventType = event.type

    if eventType == "message" then
        -- 清除之前的输入指示
        if self.isTyping then
            self.isTyping = false
            if self.callbacks.onTypingEnd then
                self.callbacks.onTypingEnd()
            end
        end

        -- 触发消息回调
        if self.callbacks.onMessage then
            self.callbacks.onMessage({
                sender   = event.sender,
                text     = event.text,
                time     = event.time,
                showTime = event.showTime,
            })
        end

        -- 前进到下一个事件
        self:Advance()
        return true  -- 可以继续处理

    elseif eventType == "typing" then
        -- 显示"正在输入"指示
        self.isTyping = true
        if self.callbacks.onTyping then
            self.callbacks.onTyping(event.sender)
        end

        -- 前进到下一个事件
        self:Advance()

        -- typing 后面通常紧跟一个 delay>0 的 message，继续 Process
        self:Process()
        return false  -- Process 内部会处理后续

    elseif eventType == "wait_input" then
        -- 等待用户输入
        self.state = "wait_input"

        -- "随意敲打键盘"：由策划在 CSV text 字段决定是否启用及内容
        local autoText = (event.text and event.text ~= "") and event.text or ""
        self.autoFillText = autoText
        self.autoFillIndex = 0
        self.autoFillTotal = 0
        self.autoFillEnabled = (autoText ~= "")

        if self.autoFillEnabled then
            -- 统计 UTF-8 字符数
            local i = 1
            while i <= #autoText do
                local b = string.byte(autoText, i)
                if b < 0x80 then
                    i = i + 1
                elseif b < 0xE0 then
                    i = i + 2
                elseif b < 0xF0 then
                    i = i + 3
                else
                    i = i + 4
                end
                self.autoFillTotal = self.autoFillTotal + 1
            end
        end

        return false

    elseif eventType == "choice" then
        -- ======================================================================
        -- 关键词+语气分支选择模式
        -- 不再弹出选项按钮，而是进入 wait_choice 状态等待用户输入文本，
        -- 用户发送消息后通过 OnUserMessage 自动匹配分支。
        -- ======================================================================
        self.state = "wait_choice"

        -- 解析分支选项并存储
        if event.options then
            self.pendingBranches = SentimentAnalyzer.ParseBranchOptions(event.options)
        else
            self.pendingBranches = {}
        end
        self.pendingDefaultNext = event.default_next or ""

        -- 初始化超时计时器
        local timeout = tonumber(event.timeout) or 0
        local defaultNext = event.default_next or ""
        if timeout > 0 then
            self.timeoutTimer = 0
            self.timeoutTarget = timeout
            self.timeoutNextId = defaultNext
        else
            self.timeoutTimer = 0
            self.timeoutTarget = 0
            self.timeoutNextId = ""
        end

        -- 通知前端：进入分支等待输入（可选显示提示）
        if self.callbacks.onBranchHint then
            -- 提取关键词提示
            local hints = {}
            for _, branch in ipairs(self.pendingBranches) do
                hints[#hints + 1] = branch.keywords
            end
            self.callbacks.onBranchHint(hints, timeout)
        end

        return false

    else
        -- 未知事件类型，跳过
        self:Advance()
        return true
    end
end

--- 推进到下一个事件（支持 next 字段跳转）
function Manager:Advance()
    local event = self.events[self.index]
    if event and event.next and event.next ~= "" then
        -- 按 id 跳转
        self:JumpTo(event.next)
    else
        -- 顺序推进
        self.index = self.index + 1
    end
end

--- 按事件 ID 跳转
---@param eventId string 目标事件 ID
function Manager:JumpTo(eventId)
    for i, ev in ipairs(self.events) do
        if ev.id == eventId then
            self.index = i
            return
        end
    end
    -- 找不到目标，顺序推进
    self.index = self.index + 1
end

--- 用户发送了消息
--- 同时处理 wait_input 和 wait_choice 两种状态
---@param text string 用户输入的文本
function Manager:OnUserMessage(text)
    if self.state == "wait_input" then
        -- 普通等待输入：直接推进
        self.index = self.index + 1
        self.state = "processing"
        self:Process()

    elseif self.state == "wait_choice" then
        -- 分支选择：通过关键词/语气分析选择分支
        local nextId, matchType = SentimentAnalyzer.SelectBranch(
            text,
            self.pendingBranches,
            self.pendingDefaultNext
        )

        -- 通知前端匹配结果（用于调试或显示提示）
        if self.callbacks.onBranchMatched then
            self.callbacks.onBranchMatched(nextId, matchType)
        end

        -- 清理分支状态
        self.pendingBranches = nil
        self.pendingDefaultNext = ""
        self.timeoutTimer = 0
        self.timeoutTarget = 0
        self.timeoutNextId = ""

        -- 跳转到匹配的分支
        if nextId then
            self:JumpTo(nextId)
        else
            -- 完全无匹配，顺序推进
            self.index = self.index + 1
        end

        self.state = "processing"
        self:Process()
    end
end

--- 用户选择了选项（保留兼容，但在新模式下不再使用）
---@param index number 选项索引（从 1 开始）
function Manager:OnSelectOption(index)
    if self.state ~= "wait_choice" then return end

    local event = self.events[self.index]
    if event and event.options then
        -- 解析选项，找到对应的 nextId
        local optIdx = 0
        for part in event.options:gmatch("[^;]+") do
            optIdx = optIdx + 1
            if optIdx == index then
                local _, nextId = part:match("^(.-)>(.+)$")
                if nextId then
                    -- 清理分支状态
                    self.pendingBranches = nil
                    self.pendingDefaultNext = ""

                    self:JumpTo(nextId)
                    self.state = "processing"
                    self:Process()
                    return
                end
            end
        end
    end

    -- fallback: 顺序推进
    self.pendingBranches = nil
    self.pendingDefaultNext = ""
    self.index = self.index + 1
    self.state = "processing"
    self:Process()
end

--- 获取当前状态
---@return string
function Manager:GetState()
    return self.state
end

--- 是否已结束
---@return boolean
function Manager:IsDone()
    return self.state == "done"
end

--- 是否正在等待用户输入（wait_input 或 wait_choice 都算）
---@return boolean
function Manager:IsWaitingInput()
    return self.state == "wait_input" or self.state == "wait_choice"
end

--- 是否正在等待用户选择（保留兼容）
---@return boolean
function Manager:IsWaitingChoice()
    return self.state == "wait_choice"
end

--- 获取超时剩余时间（秒）
---@return number 剩余秒数，0 表示无超时
function Manager:GetTimeoutRemaining()
    if self.state ~= "wait_choice" or self.timeoutTarget <= 0 then
        return 0
    end
    return math.max(0, self.timeoutTarget - self.timeoutTimer)
end

-- ============================================================================
-- "随意敲打键盘" 自动输入功能
-- 由策划在 CSV 的 wait_input 行的 text 字段控制：
--   text 非空 → 启用，玩家按任意键逐字填充 text 的内容
--   text 为空 → 不启用，玩家自由打字
-- ============================================================================

--- UTF-8 安全截取前 n 个字符
---@param str string 原始字符串
---@param n number 截取字符数
---@return string 截取结果
local function utf8Sub(str, n)
    if n <= 0 then return "" end
    local i = 1
    local count = 0
    while i <= #str and count < n do
        local b = string.byte(str, i)
        if b < 0x80 then
            i = i + 1
        elseif b < 0xE0 then
            i = i + 2
        elseif b < 0xF0 then
            i = i + 3
        else
            i = i + 4
        end
        count = count + 1
    end
    return string.sub(str, 1, i - 1)
end

--- 当前 wait_input 是否启用了自动填充
---@return boolean
function Manager:IsAutoFillEnabled()
    return self.autoFillEnabled
end

--- 处理"随意敲打键盘"的按键事件
--- 每次按键调用一次，逐步填充预设回复文本
--- 填充完成后再次按键会从头开始重新填充
---@return string|nil 当前部分填充的文本，nil 表示未启用或不在 wait_input 状态
function Manager:OnKeyPress()
    if self.state ~= "wait_input" then return nil end
    if not self.autoFillEnabled then return nil end
    if self.autoFillText == "" then return nil end

    -- 如果已经填充完毕，重新开始填充
    if self.autoFillIndex >= self.autoFillTotal then
        self.autoFillIndex = 0
    end

    -- 每次按键推进 1-2 个字符（随机，更自然）
    local step = (self.autoFillIndex < 2) and 1 or math.random(1, 2)
    self.autoFillIndex = math.min(self.autoFillIndex + step, self.autoFillTotal)

    local partialText = utf8Sub(self.autoFillText, self.autoFillIndex)
    local isComplete = self.autoFillIndex >= self.autoFillTotal

    -- 通知外部更新输入框显示
    if self.callbacks.onAutoFill then
        self.callbacks.onAutoFill(partialText, isComplete)
    end

    return partialText
end

--- 重置自动填充进度（当用户删除文字时调用）
function Manager:ResetAutoFill()
    self.autoFillIndex = 0
end

--- 获取自动填充是否已完成
---@return boolean
function Manager:IsAutoFillComplete()
    return self.autoFillEnabled and self.autoFillIndex >= self.autoFillTotal and self.autoFillTotal > 0
end

--- 获取自动填充进度 (0.0 ~ 1.0)
---@return number
function Manager:GetAutoFillProgress()
    if not self.autoFillEnabled or self.autoFillTotal <= 0 then return 0 end
    return self.autoFillIndex / self.autoFillTotal
end

return Manager
