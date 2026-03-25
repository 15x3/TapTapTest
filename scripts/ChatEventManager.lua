-- ============================================================================
-- 聊天事件管理器 (Chat Event Manager)
-- 功能: 状态机 + 时间轴调度器，驱动聊天剧情事件序列
--
-- 状态流:
--   processing → delay → (execute) → processing / wait_input / wait_choice / done
--
-- 回调接口:
--   onMessage(msg)   -- 收到一条消息事件（含 sender/text/time/showTime）
--   onTyping(sender)  -- 对方正在输入（用于显示 "xxx 正在输入..."）
--   onTypingEnd()     -- 输入指示结束
--   onChoice(options)  -- 弹出选项（暂未使用，预留）
--   onDone()           -- 全部事件播放完毕
-- ============================================================================

local Manager = {}
Manager.__index = Manager

--- 创建事件管理器实例
---@param events table[] 事件序列（从 DingtalkData.GetChatScenario 获取）
---@param callbacks table 回调函数表 { onMessage, onTyping, onTypingEnd, onChoice, onDone }
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
    end
    -- wait_input / wait_choice / done 状态不做自动推进
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
        return false

    elseif eventType == "choice" then
        -- 等待用户选择（预留）
        self.state = "wait_choice"
        if self.callbacks.onChoice and event.options then
            -- 解析 options: "text1>next1;text2>next2"
            local opts = {}
            for part in event.options:gmatch("[^;]+") do
                local text, nextId = part:match("^(.-)>(.+)$")
                if text then
                    opts[#opts + 1] = { text = text, nextId = nextId }
                end
            end
            self.callbacks.onChoice(opts)
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

--- 用户发送了消息（恢复 wait_input 状态）
---@param text string 用户输入的文本
function Manager:OnUserMessage(text)
    if self.state ~= "wait_input" then return end

    -- 推进到下一个事件，继续处理
    self.index = self.index + 1
    self.state = "processing"
    self:Process()
end

--- 用户选择了选项（恢复 wait_choice 状态）
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
                    self:JumpTo(nextId)
                    self.state = "processing"
                    self:Process()
                    return
                end
            end
        end
    end

    -- fallback: 顺序推进
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

--- 是否正在等待用户输入
---@return boolean
function Manager:IsWaitingInput()
    return self.state == "wait_input"
end

return Manager
