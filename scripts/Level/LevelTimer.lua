-- ============================================================================
-- LevelTimer - 关卡倒计时模块
-- 功能: 基于真实时间的关卡倒计时（默认 600 秒）
-- 联动: GameTime.Freeze/Unfreeze 暂停/恢复
-- ============================================================================

local GameTime = require("Utils.GameTime")

local LevelTimer = {}

--- 关卡总时长（秒）
---@type number
local duration_ = 0

--- 开始时的真实时间戳
---@type number
local startRealTime_ = 0

--- 暂停时累计的已用时间（秒）
---@type number
local pausedElapsed_ = 0

--- 暂停时刻的真实时间戳（nil 表示未暂停）
---@type number|nil
local pausedAt_ = nil

--- 是否正在运行
---@type boolean
local running_ = false

-- ============================================================================
-- 核心 API
-- ============================================================================

--- 开始计时
---@param durationSec number|nil 关卡总时长（秒），默认 600
function LevelTimer.Start(durationSec)
    duration_ = durationSec or 600
    startRealTime_ = os.time()
    pausedElapsed_ = 0
    pausedAt_ = nil
    running_ = true
    print(string.format("[LevelTimer] 开始计时: %d 秒", duration_))
end

--- 获取已用时间（秒）
---@return number
function LevelTimer.GetElapsed()
    if not running_ then return 0 end
    if pausedAt_ then
        return pausedElapsed_
    end
    return pausedElapsed_ + (os.time() - startRealTime_)
end

--- 获取剩余时间（秒）
---@return number
function LevelTimer.GetRemaining()
    if not running_ then return 0 end
    return math.max(0, duration_ - LevelTimer.GetElapsed())
end

--- 是否已到时间
---@return boolean
function LevelTimer.IsExpired()
    if not running_ then return false end
    return LevelTimer.GetElapsed() >= duration_
end

--- 是否正在运行
---@return boolean
function LevelTimer.IsRunning()
    return running_
end

--- 暂停计时（联动 GameTime.Freeze）
function LevelTimer.Pause()
    if not running_ or pausedAt_ then return end
    pausedElapsed_ = pausedElapsed_ + (os.time() - startRealTime_)
    pausedAt_ = os.time()
    GameTime.Freeze()
    print("[LevelTimer] 已暂停")
end

--- 恢复计时（联动 GameTime.Unfreeze）
function LevelTimer.Resume()
    if not running_ or not pausedAt_ then return end
    startRealTime_ = os.time()
    pausedAt_ = nil
    GameTime.Unfreeze()
    print("[LevelTimer] 已恢复")
end

--- 停止计时
function LevelTimer.Stop()
    running_ = false
    pausedAt_ = nil
    print("[LevelTimer] 已停止")
end

--- 重置
function LevelTimer.Reset()
    duration_ = 0
    startRealTime_ = 0
    pausedElapsed_ = 0
    pausedAt_ = nil
    running_ = false
end

--- 获取格式化的剩余时间 "MM:SS"
---@return string
function LevelTimer.GetFormattedRemaining()
    local remain = LevelTimer.GetRemaining()
    local min = math.floor(remain / 60)
    local sec = remain % 60
    return string.format("%02d:%02d", min, sec)
end

return LevelTimer
