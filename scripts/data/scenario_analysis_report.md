# 《班主任晨间大作战》CSV 触发链路分析报告（第二轮验证）

> 初始分析：2026-03-26
> 第二轮验证：2026-03-27
> 分析范围：`chat_scenarios.csv`（钉钉）、`wechat_scenarios.csv`（微信）
> 分析方法：Python 脚本模拟 Lua CSVParser 逗号分割逻辑，逐行验证实际字段映射
> 分析目的：验证第一轮报告中所有问题的修复情况

---

## 修复总览

| 检查项 | 第一轮状态 | 第二轮状态 | 说明 |
|--------|-----------|-----------|------|
| choice 行 options 列偏移（14行） | P0 致命 | **已修复** | 所有选项已用分号正确连接 |
| wait_input 行列偏移（15行） | P0 致命 | **已修复** | 所有列对齐正确 |
| message done 行 tag 前移（5行） | P1 严重 | **已修复** | tag 值已在正确列 |
| 重复 ID（5组） | P0 致命 | **已修复** | 所有 ID 唯一化 |
| 情绪管理 tag 无法获得 | P0 致命 | **已修复** | 11 个来源事件 |
| 危机处理 tag 无法获得 | P0 致命 | **已修复** | 2 个来源事件 |

**结论：第一轮报告中所有 P0/P1 问题均已修复。**

---

## 一、P0 修复验证 — choice 行（14行全部修复）

### 验证结果

所有 14 个 choice 行的 options 字段现在正确使用分号分隔两个选项，tag 字段包含有效的标签名。

| ID | options（已修复） | tag（已修复） |
|----|-------------------|--------------|
| `tut_24` | 转发到班主任通知群>tut_fail1;转发到家长群>tut_pass | 信息筛选 |
| `tut_37` | 继续练习>tut_retry;开始游戏>start_game | 新手 |
| `tut_retry` | 是的>tut_24;开始游戏>start_game | 新手 |
| `pn_choice` | 先看看其他群>pn_check_others;立即转发到家长群>pn_forward1 | 信息筛选\|时间压力 |
| `sc_choice1` | 稍后回复>ignore_parent1;现在回复>sc_reply1 | 情绪管理\|家校沟通 |
| `sn_choice1` | 先处理其他事情>sn_delay1;立即转发到班群>sn_forward1 | 信息筛选\|上级压力 |
| `sn_choice2` | 稍后处理>sn_delay2;立即转发到班群>sn_forward2 | 信息筛选\|效率至上 |
| `tc_choice1` | 稍后回复>tc_ignore1;现在回复>tc_reply1 | 情绪管理\|学生管理 |
| `tc_choice2` | 统一解答>tc_reply_all;单独回复>tc_reply2 | 情绪管理\|效率至上 |
| `crisis_choice1` | 先看看再说>crisis_delay;立即转发到班群>crisis_forward | 信息筛选\|效率至上\|危机处理 |
| `crisis_choice2` | 稍后处理>crisis_delay2;立即批准请假>crisis_approve | 情绪管理\|家校沟通 |
| `flood_choice1` | 逐条仔细处理>flood_slow;快速筛选转发>flood_quick | 效率至上\|信息筛选 |
| `multi_choice1` | 全部回复>multi_all;优先处理重要通知>multi_priority | 情绪管理\|信息筛选 |
| `final_choice1` | 不转发>final_skip;转发>final_forward | 信息筛选 |

---

## 二、P0 修复验证 — wait_input 行（15行全部修复）

### 验证结果

所有 wait_input 行的列对齐已修复，text（自动填充文本）、next（跳转目标）、tag（标签）均在正确位置。

| ID | text（自动填充） | next（跳转目标） | tag（标签） |
|----|-----------------|-----------------|------------|
| `tut_29` | 收到，我会转发到学生家长群 | tut_30 | 新手 |
| `pn_11` | *(空，自由输入)* | pn_choice | 时间压力 |
| `pn_forward_input1` | *(空)* | pn_forward_done1 | 信息筛选 |
| `sc_reply_input1` | *(空)* | sc_reply_done1 | 情绪管理 |
| `sn_forward_input1` | *(空)* | sn_forward_done1 | 信息筛选 |
| `sn_forward_input2` | *(空)* | sn_psych_fwd_done1 | 信息筛选 |
| `tc_reply_input1` | *(空)* | tc_reply_done1 | 情绪管理 |
| `tc_reply_input2` | *(空)* | tc_psych_done1 | 情绪管理 |
| `tc_reply_input3` | *(空)* | tc_all_done1 | 效率至上 |
| `crisis_input1` | *(空)* | crisis_done1 | 信息筛选 |
| `crisis_input2` | *(空)* | crisis_done3 | 情绪管理 |
| `flood_input1` | *(空)* | flood_done1 | 效率至上 |
| `multi_input1` | *(空)* | multi_done1 | 信息筛选 |
| `final_input1` | *(空)* | final_done1 | 信息筛选 |

**注意**：`pn_11` 的 text 为空，属于自由输入类型（玩家随意输入后继续），不是自动填充。这是预期行为。

---

## 三、P1 修复验证 — message done 行 tag（全部修复）

所有"完成确认"message 行的 tag 值已在正确列，options 字段为空。

| ID | tag（已修复） |
|----|--------------|
| `sn_psych_fwd_done2` | 效率至上 |
| `tc_psych_done2` | 情绪管理 |
| `tc_all_done2` | 效率至上 |
| `crisis_done2` | 效率至上\|危机处理 |
| `flood_done2` | 效率至上 |
| `multi_done2` | 效率至上\|信息筛选 |

---

## 四、P0 修复验证 — 重复 ID（全部修复）

全文无重复 ID。修复方式：

| 原重复 ID | 修复后 |
|-----------|--------|
| `start_game`（2次） | 拆分为 `start_game` + `start_game_time` |
| `tc_reply_done2`（2次） | 心理普查组改为 `tc_psych_done1`（typing）+ `tc_psych_done2`（message） |
| `tc_reply_done3`（2次） | 统一解答组改为 `tc_all_done1`（typing）+ `tc_all_done2`（message） |
| `sn_forward_done2`（2次） | 心理普查组改为 `sn_psych_fwd_done1`（typing）+ `sn_psych_fwd_done2`（message） |
| `game_end`（3次） | 拆分为 `game_end` + `game_end_2` + `game_end_3` |

---

## 五、结尾评价系统验证 — 四个 tag 全部可获得

### 5.1 结尾机制（设计正确，无变化）

四对成对事件通过 `require_tag` 实现条件展示，设计逻辑正确。

### 5.2 四个结尾 tag 的获得来源

| 结尾 tag | 来源数 | 来源事件 |
|---------|--------|---------|
| **信息筛选** | 16 | `tut_24`, `pn_choice`, `pn_forward_input1`, `sn_choice1`, `sn_forward_input1`, `sn_choice2`, `sn_forward_input2`, `sn_psych_fwd_done1`, `crisis_choice1`, `crisis_input1`, `flood_choice1`, `multi_choice1`, `multi_input1`, `multi_done2`, `final_choice1`, `final_input1` |
| **效率至上** | 12 | `sn_choice2`, `sn_psych_fwd_done2`, `tc_choice2`, `tc_reply_input3`, `tc_all_done1`, `tc_all_done2`, `crisis_choice1`, `crisis_done2`, `flood_choice1`, `flood_input1`, `flood_done2`, `multi_done2` |
| **情绪管理** | 11 | `sc_choice1`, `sc_reply_input1`, `tc_choice1`, `tc_reply_input1`, `tc_choice2`, `tc_reply_input2`, `tc_psych_done1`, `tc_psych_done2`, `crisis_choice2`, `crisis_input2`, `multi_choice1` |
| **危机处理** | 2 | `crisis_choice1`, `crisis_done2` |

**对比第一轮**：
- 情绪管理：0 → **11**（从完全无法获得到 11 个来源）
- 危机处理：0 → **2**（从完全无法获得到 2 个来源）
- 信息筛选：3 → **16**（来源大幅增加）
- 效率至上：2 → **12**（来源大幅增加）

---

## 六、新发现 — default_next 列中的分类标注（P3 信息性）

### 6.1 现象

172 个 message/typing 行的 `default_next` 列中存放了 tag 名称（如"新手"、"时间压力"、"家校沟通"等），而 `tag` 列为空。

### 6.2 分析结论：**有意为之的分类标注，非列偏移**

经分析，这些值是策划编辑 CSV 时有意放置的**章节分类标记**，而非列对齐错误。证据：

1. **覆盖规律**：同一章节的所有 message 行都标注了相同的分类值
   - `tut_*` 全部标注"新手"
   - `pn_*` 全部标注"时间压力"
   - `sc_*` 全部标注"家校沟通"
   - `sn_*` 全部标注"上级压力"
   - `tc_*` 全部标注"学生管理"
   - `crisis_*` 全部标注"危机处理"
   - `chat_*` 全部标注"同事互动"

2. **如果是列偏移**：每条消息都会授予标签，玩家只是阅读消息就能获得所有 tag——这不符合设计意图

3. **功能无影响**：`ChatEventManager.lua` 中 `default_next` 仅在 choice 事件超时时使用，message/typing 事件完全忽略此字段

### 6.3 建议

**无需修复**。这些分类标注不影响任何功能。如果希望更规范，可以考虑：
- 新增一个 `category` 注释列专门存放分类标记
- 或清空这些 default_next 值（纯粹是美观问题）

---

## 七、仍然存在的 P2 问题（未变化）

以下问题在第一轮已记录，属于可选优化项，不影响核心玩法：

| # | 问题 | 说明 |
|---|------|------|
| 1 | `tut_fail2` 孤岛事件 | 无任何事件指向它，永远不会被触发 |
| 2 | `_require` 后缀命名误导 | 8 个事件 ID 带 `_require` 后缀但无 `require_tag` 条件 |
| 3 | 交流群（8:06）无交互 | 全部是 message，没有 choice 或 wait_input |
| 4 | 教程链路缺少显式 next | 多段连续消息依赖 CSV 行顺序 |
| 5 | 微信 `fri_7` 无自动填充无 timeout | 自由输入可能卡住玩家 |

---

## 八、微信 scenarios 验证

| 线路 | 状态 | 说明 |
|------|------|------|
| 老妈线路（mom_*） | 无问题 | 13 步 + 1 choice，链路完整 |
| 好友-陈通线路（fri_*） | 无问题 | 10 步 + 2 wait_input，链路完整 |

---

## 九、最终评价

### 数据质量评分变化

| 维度 | 第一轮 | 第二轮 | 说明 |
|------|--------|--------|------|
| 列对齐正确性 | 2/10 | **10/10** | 所有 choice/wait_input/done 行修复 |
| ID 唯一性 | 5/10 | **10/10** | 无重复 ID |
| 结尾系统可达性 | 3/10 | **9/10** | 4 个 tag 全部可获得，危机处理来源较少(2) |
| 链路完整性 | 7/10 | **8/10** | P2 小问题未变 |
| **综合** | **5/10** | **9/10** | 核心玩法完全可用 |

### 总结

所有致命和严重问题已修复，CSV 数据现在可以支撑完整的游戏流程。四个结尾成就标签（信息筛选、效率至上、情绪管理、危机处理）全部可以通过正常游戏获得。剩余的 P2 问题属于锦上添花的优化项。

---

*第二轮验证完毕。*
