# "一日班主任" Phase 1 实施计划

## 概述

将现有手机模拟器改造为关卡制信息生存游戏。Phase 1 包含：关卡计时器、时间轴消息调度、转发操作、回复操作、公告系统、反馈系统、结算报告。

### 用户确认的关键决策

1. **时间系统**：关卡计时器是 GameTime 的子功能，基于 600 秒真实时间倒计时。所有时间显示（状态栏、壁纸、时钟）共用同一个 GameTime。冻结功能保留供教程使用。
2. **旧系统兼容**：保留 ChatEventManager，增加 `levelMode` 开关切换新旧模式。
3. **转发操作**：以"班主任"身份直接发出原文（非引用）。所有消息均支持长按/右键弹出上下文菜单。提供设置选项（长按 vs 右键）。复制功能为摆设。
4. **公告系统**：随时可发布，发布后可继续操作。特定时间点检查关键词。
5. **Phase 1 范围**：包含回复操作和反馈系统。第一关数据由文案团队后续填写，需提供数据格式文档。

---

## 新增文件清单（12 个）

| 文件路径 | 职责 |
|---------|------|
| `scripts/Level/LevelTimer.lua` | 关卡倒计时（600s 真实时间） |
| `scripts/Level/LevelConfig.lua` | 加载/解析关卡 CSV 数据包 |
| `scripts/Level/LevelMessageScheduler.lua` | 按时间轴调度消息投放 |
| `scripts/Level/LevelManager.lua` | 关卡生命周期管理（简报→游戏→结算） |
| `scripts/Level/ForwardManager.lua` | 转发操作逻辑（目标验证、消息投递） |
| `scripts/Level/AnnouncementManager.lua` | 公告编辑、发布、关键词检查 |
| `scripts/Level/FeedbackManager.lua` | 反馈触发（正确/超时/错误目标） |
| `scripts/Level/SettlementReport.lua` | 结算数据统计 |
| `scripts/UI/ContextMenu.lua` | 长按/右键上下文菜单（转发/复制） |
| `scripts/UI/BriefingScreen.lua` | 关卡简报界面 |
| `scripts/UI/SettlementScreen.lua` | 结算报告界面 |
| `scripts/data/levels/level1/mock_messages.csv` | Mock 第一关数据（占位） |

## 修改文件清单（8 个）

| 文件路径 | 修改内容 |
|---------|---------|
| `scripts/main.lua` | 添加 levelMode 开关、LevelManager 集成、关卡倒计时显示 |
| `scripts/Utils/GameTime.lua` | 添加 `GetElapsedSince(startTime)` 辅助方法 |
| `scripts/Utils/ChatBubble.lua` | 气泡 onClick→长按/右键触发 ContextMenu |
| `scripts/Utils/EventScheduler.lua` | 无需大改，levelMode 时由 LevelMessageScheduler 替代 |
| `scripts/DingtalkApp.lua` | 支持公告发布入口按钮 |
| `scripts/DingtalkPages/ChatPage.lua` | 接入 ForwardManager 的消息投递回调 |
| `scripts/WechatPages.lua` | 同上，微言端接入 |
| `scripts/WechatApp.lua` | 支持公告发布入口（如适用） |

---

## 实施步骤

### Step 1: 基础设施 — 计时器 + 消息调度 + Mock 数据

**目标**：关卡能按时间轴自动投放消息

**新建文件**：

1. **`scripts/Level/LevelTimer.lua`**
   - `LevelTimer.Start(durationSec)` — 记录 `startRealTime = os.time()`，设置 `duration = 600`
   - `LevelTimer.GetRemaining()` — 返回剩余秒数 `max(0, duration - elapsed)`
   - `LevelTimer.GetElapsed()` — 返回已用秒数
   - `LevelTimer.IsExpired()` — 是否归零
   - `LevelTimer.Pause()` / `Resume()` — 联动 `GameTime.Freeze/Unfreeze`
   - 内部用真实时间 `os.time()` 计算，暂停时记录暂停点

2. **`scripts/Level/LevelConfig.lua`**
   - `LevelConfig.Load(levelId)` — 加载 `scripts/data/levels/{levelId}/` 下的 CSV 文件
   - 解析 `config.csv`（关卡元信息：名称、时长、起始时间 HH:MM）
   - 解析 `messages.csv`（时间轴消息）
   - 解析 `chats.csv`（本关涉及的聊天列表）
   - 解析 `feedbacks.csv`（反馈规则）
   - 解析 `announcement.csv`（公告检查点）
   - 返回结构化的 levelData table

3. **`scripts/Level/LevelMessageScheduler.lua`**
   - `Scheduler.Init(messages, callbacks)` — 接收 LevelConfig 解析的消息列表
   - `Scheduler.Update(elapsedSec)` — 每帧检查 `time_offset <= elapsed` 的未投放消息
   - 回调 `onMessage(msg)` — 投放消息到对应 app/chat
   - 回调 `onNotification(msg)` — 触发通知横幅
   - 消息 priority 字段：`important` / `noise` — 用于结算统计

4. **`scripts/data/levels/level1/mock_messages.csv`**
   - 5-8 条占位消息，覆盖叮叮和微言两个 app
   - 包含至少 1 条 forward_target 非空的重要消息
   - 包含至少 1 条噪音消息

**修改文件**：

5. **`scripts/Utils/GameTime.lua`** — 新增 `GameTime.GetElapsedSince(startTimestamp)`

6. **`scripts/main.lua`**（最小改动）
   - 顶部新增 `local levelMode_ = false` 开关
   - HandleUpdate 中：若 `levelMode_` 则调用 `LevelMessageScheduler.Update()` 替代 `EventScheduler.CheckTriggers()`

**验证**：设置 `levelMode_ = true`，运行后控制台可见消息按时间轴投放的日志。

---

### Step 2: 关卡生命周期 — 简报 → 游戏 → 结算

**目标**：完整的关卡流程闭环

**新建文件**：

1. **`scripts/UI/BriefingScreen.lua`**
   - 全屏覆盖在手机 UI 上方
   - 显示：关卡名称、背景故事、本关目标提示、"开始"按钮
   - 点击开始 → 回调 `onStart()`

2. **`scripts/UI/SettlementScreen.lua`**（Phase 1 简版）
   - 全屏覆盖，分组显示已处理/未处理/错误操作
   - 无评分，纯事实陈述
   - "继续" 按钮 → 回调 `onContinue()`

3. **`scripts/Level/LevelManager.lua`**
   - 状态机：`idle → briefing → playing → settlement → idle`
   - `LevelManager.StartLevel(levelId)` — 加载 LevelConfig → 显示 BriefingScreen
   - 简报结束 → `GameTime.SetTime(startHour, startMin)` + `LevelTimer.Start(600)` + 开始消息调度
   - `LevelTimer.IsExpired()` → 进入结算 → 显示 SettlementScreen

**修改文件**：

4. **`scripts/main.lua`**
   - 状态栏右侧添加倒计时显示（`MM:SS` 格式）
   - `LevelManager` 集成到 HandleUpdate
   - 提供 `StartLevel(levelId)` 全局入口

**验证**：简报屏幕 → 点击开始 → 倒计时出现 → 消息投放 → 归零 → 结算屏幕。

---

### Step 3: 转发操作 — 上下文菜单 + 消息投递

**目标**：长按消息 → 选择转发 → 选择目标 → 消息出现在目标聊天

**新建文件**：

1. **`scripts/UI/ContextMenu.lua`**
   - `ContextMenu.Show(items, x, y, onSelect)` — 弹出菜单
   - 菜单项：转发 / 复制
   - 点击外部自动关闭
   - 用 `UI.Panel` + 绝对定位实现

2. **`scripts/Level/ForwardManager.lua`**
   - `ForwardManager.Init(levelData)` — 加载转发目标规则
   - `ForwardManager.GetTargets(msg)` — 返回可转发目标列表
   - `ForwardManager.Forward(msg, targetChat)` — 执行转发
     - 验证目标正确性（对比 `forward_target` 字段）
     - 以"班主任"身份在目标聊天添加消息
     - 记录到 SettlementReport
   - `ForwardManager.ShowTargetSelector(msg, onConfirm)` — 弹出目标选择 Modal

**修改文件**：

3. **`scripts/Utils/ChatBubble.lua`**
   - 替换 `onClick` 为长按/右键监听（`UI.Gesture` 的 `OnLongPressStart`）
   - 触发 `ContextMenu.Show()`
   - 复制仍为摆设

4. **`scripts/DingtalkPages/ChatPage.lua`** — 转发消息投递时调用 `addBubble()` 显示

5. **`scripts/WechatPages.lua`** — 同上

**验证**：长按气泡 → 菜单 → 转发 → 选目标 → 消息出现在目标聊天。

---

### Step 4: 回复操作 + 公告系统

**目标**：回复消息（S4U 自动填充）+ 发布公告

**回复操作**（复用 ChatEventManager）：
- `wait_reply` 类型消息投放后，在对应聊天激活 ChatEventManager 的 `wait_input` 状态
- S4U 自动填充、关键词匹配等逻辑完全复用
- 回复结果记录到 SettlementReport

**公告系统**：

1. **`scripts/Level/AnnouncementManager.lua`**
   - `AnnouncementManager.Init(announcementData)` — 加载公告检查点
   - `AnnouncementManager.Publish(text)` — 发布公告
   - `AnnouncementManager.CheckAtTime(elapsedSec)` — 特定时间点检查关键词
   - 使用 `SentimentAnalyzer.MatchKeywords()` 匹配

2. **`scripts/DingtalkApp.lua`**（修改）
   - 添加"发布公告"浮动按钮（仅 levelMode 显示）
   - 点击弹出 `UI.Modal` + 单行 `UI.TextField`
   - 确认后调用 `AnnouncementManager.Publish(text)`

**验证**：自动填充 → 发送回复 → 控制台确认。公告按钮 → 输入 → 发布 → 确认记录。

---

### Step 5: 反馈系统 + 结算报告

**目标**：操作后收到反馈，关卡结束时生成完整报告

1. **`scripts/Level/FeedbackManager.lua`**
   - 三种触发：`on_correct(delay)` / `on_timeout` / `on_wrong_target`
   - `FeedbackManager.Update(elapsedSec)` — 处理延迟反馈队列
   - 反馈消息通过消息投放通道发送到对应聊天

2. **`scripts/Level/SettlementReport.lua`**
   - 记录所有操作：转发/回复/公告/超时
   - `Report.Generate()` → `{ handled={...}, missed={...}, wrong={...}, announcements={...} }`
   - 纯事实，无评分

3. **`scripts/UI/SettlementScreen.lua`**（完善）— 读取 Report 数据，分组显示

**验证**：正确转发 → 延迟收到正面反馈。超时 → 催促消息。结算 → 完整记录。

---

### Step 6: 集成与打磨

1. **main.lua 最终集成**：levelMode 开关完整控制新旧流程
2. **向后兼容验证**：`levelMode_ = false` 时所有旧功能正常
3. **数据格式文档**：`docs/level-data-guide.md` 供文案团队使用

---

## Mock 数据格式（供文案团队参考）

### messages.csv
```
time_offset,app,chat,sender,type,content,priority,forward_target,keywords,reply_hint
30,dingtalk,教务处通知群,刘主任,message,下周二三年级调课安排已出,important,三年级班主任群,,
60,dingtalk,教务处通知群,刘主任,wait_reply,收到请回复,important,,,收到|好的|明白
120,wechat,李妈妈,李妈妈,message,老师您好请问体检表...,noise,,,,
```

### feedbacks.csv
```
trigger,source_chat,delay,app,chat,sender,content
on_correct:forward:教务处通知群,教务处通知群,15,dingtalk,教务处通知群,刘主任,好的收到
on_timeout:forward:教务处通知群,教务处通知群,180,dingtalk,教务处通知群,刘主任,请尽快转发调课通知
```

### announcement.csv
```
check_time_offset,required_keywords
480,体检|注意事项|空腹
```

---

## 验证清单

1. **旧模式兼容**：`levelMode_ = false` → 现有功能无报错
2. **关卡启动**：`levelMode_ = true` → 简报 → 点击开始
3. **计时器**：状态栏倒计时 MM:SS，GameTime 正常流动
4. **消息投放**：消息按 time_offset 出现在正确 app/chat
5. **通知横幅**：新消息时弹出通知
6. **转发操作**：长按 → 菜单 → 转发 → 选目标 → 消息出现
7. **回复操作**：wait_reply → 自动填充 → 发送 → 记录结果
8. **公告发布**：按钮 → 输入 → 发布 → 确认
9. **反馈消息**：正确操作→正面反馈；超时→催促
10. **结算报告**：倒计时归零 → 结算屏显示完整记录
11. **构建通过**：每步完成后调用 UrhoX MCP build 工具
