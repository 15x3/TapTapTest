-- ============================================================================
-- GameTime - 虚拟时间模块
-- 功能: 提供可自定义的虚拟时间，保持正常时间流动
-- 用法:
--   local GameTime = require("Utils.GameTime")
--   GameTime.Init()           -- 初始化（默认周二 08:00）
--   local t = GameTime.Now()  -- 获取虚拟时间（os.date("*t") 格式）
--   GameTime.SetTime(14, 30)  -- 调整为 14:30
--   GameTime.SetWeekday(1)    -- 调整为周日 (1=周日..7=周六)
-- ============================================================================

local GameTime = {}

--- 时间偏移量（秒），虚拟时间 = 系统时间 + offset_
local offset_ = 0

--- 是否已初始化
local inited_ = false

--- 冻结状态：冻结时记录冻结瞬间的系统时间戳，Now() 始终返回该时刻的虚拟时间
---@type number|nil
local frozenAt_ = nil

--- 脏标记：SetTime/Freeze/Unfreeze 后置 true，供外部检测并强制刷新 UI
local dirty_ = false

-- ============================================================================
-- 核心 API
-- ============================================================================

--- 初始化虚拟时间，使起始时刻为最近的周二 08:00:00
function GameTime.Init()
    if inited_ then return end
    inited_ = true

    local now = os.time()
    local t = os.date("*t", now)

    -- 计算目标：周二(wday=3) 08:00:00
    local targetWday = 3  -- 周二
    local targetHour = 8
    local targetMin  = 0
    local targetSec  = 0

    -- 当前星期几的差值（让虚拟时间变成周二）
    local dayDiff = targetWday - t.wday
    -- 不需要特别限制范围，直接用差值即可

    -- 构建目标时间点
    local targetTime = os.time({
        year  = t.year,
        month = t.month,
        day   = t.day + dayDiff,
        hour  = targetHour,
        min   = targetMin,
        sec   = targetSec,
    })

    offset_ = targetTime - now
end

--- 获取当前虚拟时间（返回 os.date("*t") 格式的 table）
---@return table t { year, month, day, hour, min, sec, wday, yday, isdst }
function GameTime.Now()
    local base = frozenAt_ or os.time()
    local virtualTime = base + offset_
    return os.date("*t", virtualTime)
end

--- 获取当前虚拟时间的 Unix 时间戳
---@return number
function GameTime.Time()
    local base = frozenAt_ or os.time()
    return base + offset_
end

-- ============================================================================
-- 调整接口
-- ============================================================================

--- 调整时间（只改时、分），日期不变
---@param hour number 小时 (0-23)
---@param min number 分钟 (0-59)
function GameTime.SetTime(hour, min)
    local base = frozenAt_ or os.time()
    local virtualNow = base + offset_
    local t = os.date("*t", virtualNow)
    t.hour = hour
    t.min  = min
    t.sec  = 0
    local newTime = os.time(t)
    offset_ = newTime - base
    dirty_ = true
end

--- 调整星期几，时分秒不变
---@param wday number 星期几 (1=周日, 2=周一, 3=周二, ..., 7=周六)
function GameTime.SetWeekday(wday)
    local base = frozenAt_ or os.time()
    local virtualNow = base + offset_
    local t = os.date("*t", virtualNow)
    local dayDiff = wday - t.wday
    t.day = t.day + dayDiff
    local newTime = os.time(t)
    offset_ = newTime - base
    dirty_ = true
end

--- 完整设置日期时间
---@param dt table 包含 {year, month, day, hour, min, sec} 中的部分或全部字段
function GameTime.SetDateTime(dt)
    local base = frozenAt_ or os.time()
    local virtualNow = base + offset_
    local t = os.date("*t", virtualNow)
    -- 用传入的字段覆盖
    t.year  = dt.year  or t.year
    t.month = dt.month or t.month
    t.day   = dt.day   or t.day
    t.hour  = dt.hour  or t.hour
    t.min   = dt.min   or t.min
    t.sec   = dt.sec   or t.sec
    local newTime = os.time(t)
    offset_ = newTime - base
    dirty_ = true
end

--- 获取当前偏移量（秒）
---@return number
function GameTime.GetOffset()
    return offset_
end

--- 直接设置偏移量（秒）
---@param seconds number
function GameTime.SetOffset(seconds)
    offset_ = seconds
end

-- ============================================================================
-- 冻结 / 解冻
-- ============================================================================

--- 冻结时间（时间停止流动，Now() 始终返回冻结瞬间的值）
function GameTime.Freeze()
    if not frozenAt_ then
        frozenAt_ = os.time()
        dirty_ = true
    end
end

--- 解冻时间（恢复正常流动，调整 offset 使虚拟时间从冻结时刻无缝衔接）
function GameTime.Unfreeze()
    if frozenAt_ then
        -- 冻结期间系统时间流逝了 (os.time() - frozenAt_) 秒
        -- 将这段差值补偿到 offset 中，使解冻后虚拟时间从冻结时刻继续
        offset_ = offset_ - (os.time() - frozenAt_)
        frozenAt_ = nil
        dirty_ = true
    end
end

--- 是否处于冻结状态
---@return boolean
function GameTime.IsFrozen()
    return frozenAt_ ~= nil
end

--- 检查并消费脏标记（调用后自动清除）
--- 用于外部在 Update 中检测时间是否被修改过，以强制刷新 UI
---@return boolean 是否有待刷新的时间变更
function GameTime.ConsumeDirty()
    if dirty_ then
        dirty_ = false
        return true
    end
    return false
end

return GameTime
