# 「一日班主任」代码审查报告

**审查日期**: 2026-03-27
**最后更新**: 2026-03-27（第二轮验证 + 试玩）
**审查范围**: `scripts/` 全部实现代码 vs `docs/design-requirements.md` + `docs/design-narrative.md`
**构建状态**: 通过（0 错误, 0 警告）

---

## 状态总览

| # | 问题 | 严重度 | 状态 |
|---|------|--------|------|
| 1 | FeedbackManager 超时取消粒度错误 | 严重 | ✅ 已修复 |
| 2 | 转发操作缺少确认弹窗 | 中等 | ✅ 已修复 |
| 3 | S4U 自动填充与关卡回复提示未打通 | 中等 | ✅ 已修复 |
| 4 | time_offset=0 教程提示 | 次要 | ⏭️ 设计决策，保留 |
| 5 | 班主任工作群与年级工作群合并 | 次要 | ⏭️ 设计决策，保留 |
| 6 | SettlementReport 转发匹配按 sourceChat 索引 | **严重** | 🔴 待修复 |
| 7 | t=540 系统提醒消息不可见 | **中等** | 🔴 待修复 |

---

## 已关闭的问题

### 问题 1：FeedbackManager 超时取消粒度错误 ✅ 已修复

**文件**: `scripts/Level/FeedbackManager.lua`

**原问题**: `OnCorrectForward(sourceChat)` 按 `sourceChat` 取消超时，导致来自同一群的不同信息链互相干扰。

**修复验证**: `OnCorrectForward` 已改为接收 `chainId` 参数，超时取消逻辑优先按 `chainId` 精确匹配，无 `chainId` 时回退到 `sourceChat`：

```lua
function FeedbackManager.OnCorrectForward(sourceChat, chainId, elapsedSec)
    for _, w in ipairs(timeoutWatches_) do
        if w.watchType == "forward" and not w.canceled then
            if chainId and chainId ~= "" and w.chainId ~= "" then
                if w.chainId == chainId then w.canceled = true end
            else
                if w.sourceChat == sourceChat then w.canceled = true end
            end
        end
    end
end
```

`main.lua` 中的调用方也已同步传入 `msg.chainId`。

---

### 问题 2：转发操作缺少确认弹窗 ✅ 已修复

**文件**: `scripts/main.lua`

**原问题**: 选择转发目标后直接执行，无确认步骤。

**修复验证**: 新增 `ShowForwardConfirm(msg, target)` 函数，选择目标后先弹出确认弹窗（"确认转发到「XXX」？"），玩家点确认才执行 `ForwardManager.ExecuteForward()`。

---

### 问题 3：S4U 自动填充与关卡回复提示未打通 ✅ 已修复

**文件**: `scripts/DingtalkPages/ChatPage.lua`、`scripts/WechatPages.lua`

**原问题**: `ReplyManager.GetReplyHint()` 存储了回复提示但未接入输入框自动填充。

**修复验证**: 两个聊天页面在打开时读取 `ReplyManager.GetReplyHint(app, chatName)`，若有提示则驱动 S4U 风格逐字填充，与 `ChatEventManager` 采用相同的打字范式。

---

### 问题 4：time_offset=0 教程提示 ⏭️ 设计决策

程序确认为有意设计，开局教程提示保留。

---

### 问题 5：班主任工作群与年级工作群合并 ⏭️ 设计决策

程序确认为有意合并，减少群聊数量降低认知负担。

---

## 待修复的问题

### 问题 6：SettlementReport 转发匹配按 sourceChat 索引（严重）🔴

**文件**: `scripts/Level/SettlementReport.lua`

**现象**: 结算报告生成转发结果时，按 `msgChat`（来源群名）索引转发记录：

```lua
local forwardedFromChat = {}
for _, entry in ipairs(forwardLog) do
    local chat = entry.msgChat
    if not forwardedFromChat[chat] then
        forwardedFromChat[chat] = {}
    end
    local list = forwardedFromChat[chat]
    list[#list + 1] = entry
end
```

信息链 A（调课通知，t=30）和信息链 C（体检注意事项，t=240）都来自"年级工作群"。当玩家只转发了链 A 时，结算报告查找 `forwardedFromChat["年级工作群"]` 会认为链 C 也被转发了——两条链共享同一组转发记录，导致报告结果不准确。

**预期行为**: 每条信息链的转发结果应独立判定。转发链 A 不应影响链 C 的结算。

**建议修复**: 将索引 key 从 `msgChat` 改为 `chainId`：

```lua
-- 改为按 chainId 索引
local forwardedByChain = {}
for _, entry in ipairs(forwardLog) do
    local key = entry.chainId or entry.msgChat  -- chainId 优先，兼容无 chainId 的旧数据
    if not forwardedByChain[key] then
        forwardedByChain[key] = {}
    end
    local list = forwardedByChain[key]
    list[#list + 1] = entry
end

-- 查询时也按 chainId
local entries = forwardedByChain[msg.chainId or msg.chat]
```

同时确认 `ForwardManager.ExecuteForward()` 写入转发日志时已包含 `chainId` 字段（当前代码已包含）。

---

### 问题 7：t=540 系统提醒消息不可见（中等）🔴

**文件**: `scripts/Level/LevelMessageScheduler.lua`、`scripts/main.lua`

**现象**: `messages.csv` 中 `time_offset=540` 有一条 `type=system` 的提醒消息（"别忘了发公告"），但该消息在两个环节被过滤：

1. **LevelMessageScheduler** 跳过了系统消息的通知：
   ```lua
   if msg.type ~= "system" and callbacks_.onNotification then
       callbacks_.onNotification(msg)
   end
   ```

2. **main.lua 的 onDeliverMessage** 对 `type=system` 的消息提前 return，不调用 `AddMessage`：
   ```lua
   if msg.type == "system" then
       return  -- 消息被丢弃，玩家永远看不到
   end
   ```

**结果**: 玩家在游戏最后 60 秒完全没有公告提醒，只能靠倒计时自行注意。

**建议修复**（二选一）：

**方案 A — 作为系统提示渲染在聊天内**：
在 `onDeliverMessage` 中不再跳过 system 消息，而是以特殊样式（如居中灰色文字）渲染在对应聊天窗口：

```lua
if msg.type == "system" then
    -- 添加到钉钉首页或当前活跃聊天，以系统提示样式展示
    DingtalkData.AddSystemMessage(msg.chat, msg.text)
    return
end
```

**方案 B — 作为全局 Toast 提醒**：
不走聊天消息流，而是弹出一个临时 Toast 通知：

```lua
if msg.type == "system" then
    ShowToast(msg.text, 3)  -- 显示 3 秒
    return
end
```

---

## 附录：审查通过的部分

以下模块实现与设计文档一致，无需修改：

- **LevelManager 状态机**: idle → briefing → playing → settlement 流程正确
- **ForwardManager**: 多目标验证（pipe 分隔）、链路记录逻辑正确，`chainId` 已正确存入日志
- **AnnouncementManager**: 自由文本 + 关键词 AND 检测逻辑正确
- **ReplyManager**: 180 秒超时机制、关键词匹配逻辑正确
- **BriefingScreen / SettlementScreen**: UI 展示符合设计
- **LevelTimer**: 基于 `os.time()` 的计时器工作正常
- **CSV 数据加载**: `LevelConfig.lua` 字段映射正确
- **消息调度**: 按 `timeOffset` 排序投递，逻辑正确
- **公告发布**: 发送到所有 `is_forward_target` 群聊，逻辑正确
- **FeedbackManager**: 超时监控按 `chainId` 精确取消，逻辑正确
- **转发确认弹窗**: 两步确认流程完整
- **S4U 自动填充**: 钉钉/微信聊天页均已对接 `ReplyManager.GetReplyHint()`
