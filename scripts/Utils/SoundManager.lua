-- ============================================================================
-- SoundManager - 音频管理模块
-- 统一管理 BGM 和音效的加载与播放
-- ============================================================================

local M = {}

-- BGM 节点与音源（全局唯一）
local bgmNode_ = nil
local bgmSource_ = nil
local bgmGain_ = 0.5

-- 音效缓存（避免重复加载）
local sfxCache_ = {}

-- 音效路径映射
local SFX = {
    CLICK           = "audio/sfx/sfx_button_click.ogg",
    APP_OPEN        = "audio/sfx/sfx_app_open.ogg",
    BACK_CLOSE      = "audio/sfx/sfx_back_close.ogg",
    MSG_RECEIVED    = "audio/sfx/sfx_message_received.ogg",
    MSG_SENT        = "audio/sfx/sfx_message_sent.ogg",
    TYPING          = "audio/sfx/sfx_typing_key.ogg",
    ANNOUNCE_OK     = "audio/sfx/sfx_announcement_success.ogg",
    FORWARD_OK      = "audio/sfx/sfx_forward_success.ogg",
    COPY            = "audio/sfx/sfx_copy_text.ogg",
    CONTEXT_MENU    = "audio/sfx/sfx_context_menu.ogg",
    SCHOOL_BELL     = "audio/sfx/sfx_school_bell.ogg",
    SCORE_REVEAL    = "audio/sfx/sfx_score_reveal.ogg",
    GUIDE_POPUP     = "audio/sfx/sfx_guide_popup.ogg",
}
M.SFX = SFX

-- BGM 路径
local BGM = {
    GAMEPLAY   = "audio/bgm_gameplay.ogg",
    SETTLEMENT = "audio/bgm_settlement.ogg",
}
M.BGM = BGM

-- 内部 Scene（纯 UI 项目无外部 Scene，自行创建）
local audioScene_ = nil

--- 初始化音频系统（无需外部 Scene）
function M.Init()
    if bgmNode_ then return end
    audioScene_ = Scene()
    bgmNode_ = audioScene_:CreateChild("SoundManager")
    bgmSource_ = bgmNode_:CreateComponent("SoundSource")
    bgmSource_.soundType = "Music"
    bgmSource_.gain = bgmGain_
end

--- 播放 BGM（自动循环）
---@param path string BGM 文件路径
---@param gain number|nil 音量（0~1，默认 0.5）
function M.PlayBGM(path, gain)
    if not bgmSource_ then return end
    local sound = cache:GetResource("Sound", path)
    if not sound then
        print("[SoundManager] BGM not found: " .. path)
        return
    end
    sound.looped = true
    bgmSource_.gain = gain or bgmGain_
    bgmSource_:Play(sound)
end

--- 停止 BGM
function M.StopBGM()
    if bgmSource_ then
        bgmSource_:Stop()
    end
end

--- 设置 BGM 音量
---@param gain number 0~1
function M.SetBGMGain(gain)
    bgmGain_ = gain
    if bgmSource_ then
        bgmSource_.gain = gain
    end
end

--- 播放音效（一次性，自动回收）
---@param path string 音效文件路径（使用 SFX.XXX 常量）
---@param gain number|nil 音量（0~1，默认 0.7）
function M.PlaySFX(path, gain)
    if not bgmNode_ then return end
    -- 从缓存加载 Sound 资源
    local sound = sfxCache_[path]
    if not sound then
        sound = cache:GetResource("Sound", path)
        if not sound then
            print("[SoundManager] SFX not found: " .. path)
            return
        end
        sfxCache_[path] = sound
    end
    -- 每次播放创建临时 SoundSource（自动移除）
    local sfxSource = bgmNode_:CreateComponent("SoundSource")
    sfxSource.soundType = "Effect"
    sfxSource.gain = gain or 0.7
    sfxSource.autoRemoveMode = REMOVE_COMPONENT
    sfxSource:Play(sound)
end

--- 快捷方法：播放按钮点击音
function M.Click()
    M.PlaySFX(SFX.CLICK, 0.5)
end

return M
