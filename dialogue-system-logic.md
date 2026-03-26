# 对话系统逻辑图

> 本文档描述当前对话系统的内部架构与执行流程，便于后续开发与维护参考。

---

## 1. 数据流总览

```
┌─────────────────────────────────────────────────────────┐
│                    CSV 数据层                            │
│                                                         │
│  chat_scenarios.csv / wechat_scenarios.csv               │
│  ┌──────────────────────────────────────────────────┐   │
│  │ id │ chat_match │ delay │ type │ sender │ text   │   │
│  │ next │ options │ timeout │ default_next           │   │
│  │ tag │ thresholds │ require_tag                    │   │
│  └──────────────────────────────────────────────────┘   │
└───────────────────────┬─────────────────────────────────┘
                        │ CSVParser.Load()
                        ▼
┌─────────────────────────────────────────────────────────┐
│              数据解析层                                   │
│      DingtalkData.lua / WechatData.lua                   │
│                                                         │
│  ensureScenarios() 解析每行 → 事件对象 table             │
│  GetChatScenario(chatName) → 按 chat_match 筛选事件序列  │
└───────────────────────┬─────────────────────────────────┘
                        │ events[]
                        ▼
┌─────────────────────────────────────────────────────────┐
│           ChatEventManager.Create(events, callbacks)     │
│                    状态机核心                              │
└─────────────────────────────────────────────────────────┘
```

### CSV 列定义

| 列名 | 类型 | 说明 |
|------|------|------|
| `id` | string | 事件唯一标识，用于跳转 |
| `chat_match` | string | 匹配聊天名称（子串匹配） |
| `delay` | number | 事件延迟秒数，0 = 立即执行 |
| `type` | string | 事件类型：`message` / `typing` / `wait_input` / `choice` / `set_time` / `freeze_time` |
| `sender` | string | 发送者名称（空 = 系统） |
| `text` | string | 消息内容 / 自动填充文本 / 时间值 |
| `next` | string | 下一个事件 ID |
| `options` | string | 分支选项（仅 choice 类型） |
| `timeout` | number | 超时秒数（仅 wechat CSV 有此列） |
| `default_next` | string | 超时或无匹配时的默认跳转 |
| `tag` | string | 触发的全局标签，支持 `\|` 分隔多个 |
| `thresholds` | string | 阈值分支规则，如 `branchA,3,branchB,1,branchC` |
| `require_tag` | string | 前置标签条件，支持 `\|` 分隔（OR 逻辑） |

---

## 2. 状态机主循环

```
                    ┌──────────┐
                    │  Create  │
                    └────┬─────┘
                         │ 初始化后立即调用
                         ▼
              ┌─────────────────────┐
              │     Process()       │◄──────────────────────────────┐
              │ 连续执行 delay=0    │                               │
              │ 的事件链            │                               │
              └─────────┬──────────┘                               │
                        │                                          │
           ┌────────────┼────────────────┐                         │
           │            │                │                         │
     delay > 0      delay == 0     所有事件完毕                     │
           │            │                │                         │
           ▼            ▼                ▼                         │
    ┌────────────┐ ┌──────────┐   ┌───────────┐                   │
    │   delay    │ │ Execute()│   │   done    │                   │
    │   状态     │ │ 执行事件  │   │ onDone() │                   │
    └─────┬──────┘ └────┬─────┘   └───────────┘                   │
          │             │                                          │
     计时结束           │ 返回值决定后续                             │
          │        ┌────┴────┐                                     │
          │   true=继续  false=等待                                 │
          │        │         │                                     │
          ▼        ▼         ▼                                     │
     Execute()  Process()  进入等待状态                              │
          │        │    (wait_input / wait_choice)                  │
          │        │         │                                     │
          └────────┘    用户输入后 ─────────────────────────────────┘
```

### 状态说明

| 状态 | 含义 | 退出条件 |
|------|------|---------|
| `processing` | 正在连续处理事件链 | 遇到 delay > 0 或等待型事件 |
| `delay` | 等待延迟时间结束 | 计时完毕 → Execute() |
| `wait_input` | 等待用户输入文本 | 用户发送消息 → OnUserMessage() |
| `wait_choice` | 等待用户选择/输入关键词 | 用户发送消息 → OnUserMessage() |
| `done` | 事件链执行完毕 | 终态 |

---

## 3. Execute() 事件执行详细流程

```
Execute()
    │
    ▼
┌──────────────────────────────────────┐
│ ① require_tag 前置检查               │
│                                      │
│   require_tag 非空？                  │
│   ├─ 是 → 检查 TagManager            │
│   │   ├─ Has(任一tag) = true → 继续  │
│   │   └─ 全部不存在 → Advance()      │
│   │       跳过此事件, return true     │
│   └─ 否 → 继续                       │
└──────────────────┬───────────────────┘
                   ▼
┌──────────────────────────────────────┐
│ ② tag 写入                           │
│                                      │
│   event.tag 非空？                    │
│   ├─ 是 → TagManager.Add(tag)        │
│   │   支持 "tagA|tagB" 批量写入       │
│   └─ 否 → 跳过                       │
└──────────────────┬───────────────────┘
                   ▼
┌──────────────────────────────────────┐
│ ③ 按 event.type 分发处理             │
└──────────────────────────────────────┘
```

---

## 4. 六种事件类型

### 4.1 message — 发送消息

```
回调 onMessage({sender, text})
→ Advance()
→ return true (继续处理链)
```

### 4.2 typing — 显示"正在输入..."

```
回调 onTyping(sender)
→ Advance()
→ 递归 Process()
→ return false
```

### 4.3 wait_input — 等待用户输入

```
状态 → wait_input
检查 text 字段:
├─ 非空 → 启用自动输入 (autoFill)
│   onInputStateChanged(false)   ← 自动模式，输入框白色
└─ 空   → 玩家自由打字
    onInputStateChanged(true)    ← 手动模式，输入框深绿色
→ return false (等待用户发送)
```

### 4.4 choice — 分支选择

```
状态 → wait_choice
解析 options → pendingBranches
检查 thresholds:
├─ 非空 → 阈值分支模式 (汇总关键词池)
└─ 空   → 关键词匹配模式
检查 timeout → 初始化超时计时器 (仅 wechat)
onInputStateChanged(true)   ← 总是手动模式
→ return false (等待用户发送)
```

### 4.5 set_time — 设置游戏时间

```
解析 text 为 "HH:MM"
→ GameTime.SetTime(hour, min)
→ Advance() → return true
```

### 4.6 freeze_time — 冻结/解冻时间

```
text == "on"  → GameTime.Freeze()
text == "off" → GameTime.Unfreeze()
→ Advance() → return true
```

---

## 5. 用户输入处理 — OnUserMessage(text)

```
OnUserMessage(text)
    │
    ├─ state == "wait_input"
    │   │
    │   onInputStateChanged(nil)    ← 离开输入状态，恢复默认
    │   index++ → state = "processing" → Process()
    │
    └─ state == "wait_choice"
        │
        ▼
   ┌─────────────────────────┐
   │ pendingThresholds 非空？ │
   │                         │
   ├── 是 → 【阈值模式】     │
   │   │                     │
   │   │  1. CountKeywords(text, pendingKeywordPool)
   │   │     统计用户输入中匹配的关键词数量
   │   │                     │
   │   │  2. SelectBranchByThresholds(count, thresholdsStr)
   │   │     按阈值降序匹配:
   │   │     count >= 阈值 → 对应分支
   │   │     否则 → 兜底分支 (末尾无阈值项)
   │   │                     │
   ├── 否 → 【关键词匹配模式】│
   │   │                     │
   │   │  SelectBranch(text, branches, default)
   │   │     优先级1: 关键词匹配数最高者
   │   │     优先级2: default_next
   │   │     优先级3: 首个分支兜底
   │   │                     │
   └───┴─────────────────────┘
        │
        ▼
   onInputStateChanged(nil)   ← 恢复默认
   清理 pendingThresholds / pendingKeywordPool
   JumpTo(nextId) → state = "processing" → Process()
```

---

## 6. 自动输入 (AutoFill) 子系统

当 `wait_input` 事件的 `text` 字段非空时激活。

```
wait_input 且 event.text 非空
    │
    ▼
解析 text 为多分支（竖线 | 分隔）
初始化第一个分支的部分文本
    │
    ▼
┌──────────────────────────────────────────────────────┐
│           OnTextChanged(newText) 循环监听              │
│                                                      │
│  newLen == 0 且已有进度                                │
│  └→ 轮换到下一个分支, onAutoFill("", false)           │
│                                                      │
│  已填充完毕 (autoFillComplete)                        │
│  └→ 保持完整文本不变                                   │
│                                                      │
│  newLen > 当前填充长度 (用户打了新字)                   │
│  └→ 推进 1~2 字符, onAutoFill(partialText, complete)  │
│     如果推进到末尾 → autoFillComplete = true           │
│                                                      │
│  newLen 减少但不为零 (部分删除)                         │
│  └→ 忽略，继续监听                                    │
│                                                      │
│  用户发送消息 → OnUserMessage() → 推进事件链           │
└──────────────────────────────────────────────────────┘
```

**用户交互体验**：用户只需随意敲打键盘，系统自动逐字显示预设文本，模拟打字效果。清空后切换到下一条候选文本。

---

## 7. Tag 系统 — 跨聊天条件触发

### 架构

```
┌─────────────────────────────────────────────────────────┐
│                   TagManager (全局单例)                   │
│                   table<string, boolean>                 │
│                                                         │
│  ┌─────────────────────┐    ┌─────────────────────────┐ │
│  │     写入 (Add)       │    │     读取 (Has)          │ │
│  │                     │    │                         │ │
│  │  CSV event.tag 字段  │    │  CSV require_tag 字段   │ │
│  │  "tagA|tagB"        │    │  "tagA|tagB" (OR逻辑)   │ │
│  │       │             │    │       │                 │ │
│  │       ▼             │    │       ▼                 │ │
│  │  Execute() 时自动    │    │  Execute() 入口检查      │ │
│  │  调用 TM.Add()      │    │  任一 tag 存在 → 执行    │ │
│  │                     │    │  全部不存在 → 跳过事件    │ │
│  └─────────────────────┘    └─────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

### 跨聊天示例

```
  聊天A「Tag触发」                  聊天B「Tag响应」
  ┌──────────────┐                  ┌──────────────────┐
  │ 小明: 秘密    │                  │ 小红: 你来了！    │
  │ 用户回复      │                  │ (无条件显示)      │
  │ event.tag =   │─── 写入 ──►     │                  │
  │ "发现秘密"    │   TagManager    │ require_tag =     │
  └──────────────┘                  │ "发现秘密"        │
                                    │ ├─ 有tag → 聊秘密 │
                                    │ └─ 无tag → 跳过   │
                                    └──────────────────┘
```

**关键点**：TagManager 是全局 Lua 模块单例，不同聊天的 ChatEventManager 实例共享同一份 tag 数据，无需额外同步。

---

## 8. 输入框颜色状态

通过 `onInputStateChanged(state)` 回调控制输入框外观：

| 回调参数 | 触发时机 | 输入框背景色 | 文字颜色 | 含义 |
|---------|---------|------------|---------|------|
| `true` | choice / 无 autoFill 的 wait_input | `rgb(34, 120, 69)` 深绿 | 白色 | 手动输入，用户需要自己打字 |
| `false` | 有 autoFill 的 wait_input | `rgb(255, 255, 255)` 白色 | 深色 | 自动输入，随意敲击即可 |
| `nil` | 事件推进后 / 离开等待状态 | `rgb(255, 255, 255)` 白色 | 深色 | 恢复默认 |

---

## 9. CSV options 与 thresholds 格式速查

### 关键词匹配模式（thresholds 为空）

```
options = "关键词1|关键词2>跳转ID, 关键词3|关键词4>跳转ID2"

示例: "爬山|登山>outdoor, 看书|电影>indoor"
用户输入 "我想去爬山" → 匹配 "爬山" → 跳转到 outdoor
```

### 阈值分支模式（thresholds 非空）

```
options    = "kw1|kw2|kw3>任意ID"     ← 关键词池来源（汇总所有分支的关键词）
thresholds = "branchA,3,branchB,1,branchC"

解析规则（从左到右，阈值降序）:
  匹配数 >= 3  → branchA
  匹配数 >= 1  → branchB
  匹配数 == 0  → branchC (兜底，末尾无阈值项)
```

### 超时机制（仅 wechat CSV）

```
timeout = 10, default_next = "fallbackId"
→ 10 秒内无输入 → 自动跳转到 fallbackId
```

---

## 10. 核心文件索引

| 文件路径 | 职责 |
|---------|------|
| `scripts/ChatEventManager.lua` | 状态机核心，事件调度与用户输入处理 |
| `scripts/Utils/SentimentAnalyzer.lua` | 关键词匹配、阈值分支选择 |
| `scripts/Utils/TagManager.lua` | 全局标签存储（写入 / 查询 / 清空） |
| `scripts/Utils/CSVParser.lua` | CSV 文件解析 |
| `scripts/DingtalkData.lua` | 钉钉聊天数据加载与场景筛选 |
| `scripts/WechatData.lua` | 微信聊天数据加载与场景筛选 |
| `scripts/DingtalkPages/ChatPage.lua` | 钉钉聊天 UI，含输入框颜色回调 |
| `scripts/WechatPages.lua` | 微信聊天 UI，含输入框颜色回调 |
| `scripts/data/chat_scenarios.csv` | 钉钉场景数据（12 列） |
| `scripts/data/wechat_scenarios.csv` | 微信场景数据（13 列，多 timeout） |

---

## 11. 回调函数一览

`ChatEventManager.Create(events, callbacks)` 接受的回调：

| 回调 | 参数 | 说明 |
|------|------|------|
| `onMessage` | `{sender, text}` | 显示一条聊天消息 |
| `onTyping` | `sender` | 显示"正在输入..."状态 |
| `onAutoFill` | `text, isComplete` | 自动填充输入框文本 |
| `onInputStateChanged` | `true/false/nil` | 切换输入框颜色状态 |
| `onDone` | 无 | 事件链执行完毕 |
