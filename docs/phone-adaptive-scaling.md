# 手机模拟器页面自适应缩放方案

> 本文档以「一日班主任」项目为参考实现，详细说明手机模拟器在不同屏幕分辨率下如何自适应显示。
> 适用于所有需要在屏幕中"嵌套一部手机"的模拟器类项目。

---

## 一、核心思路

整个方案可以用一句话概括：

> **组件代码只写"基础像素"，框架层统一乘 scale 输出到屏幕。**

开发者永远不需要在业务代码里写 `* scale` 或 `/ scale`，所有缩放由 UI 框架在初始化和渲染环节自动处理。

---

## 二、三层架构

```
┌─────────────────────────────────────────────────────┐
│  UI 框架层 （自动缩放）                              │
│  ─ YGConfigSetPointScaleFactor(scale)               │
│  ─ nvgScale(scale, scale)                           │
│  ─ 事件坐标 ÷ scale → 基础像素                      │
└─────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────┐
│  Yoga 布局层 （基础像素空间）                        │
│  ─ baseWidth  = screenWidth  / scale                │
│  ─ baseHeight = screenHeight / scale                │
│  ─ PointScaleFactor 保证像素对齐                    │
└─────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────┐
│  组件代码层 （只用基础像素，无需任何 scale）          │
│  ─ 手机壳：380 × 800                                │
│  ─ 字体：fontSize = 12                              │
│  ─ 间距：padding = 8                                │
└─────────────────────────────────────────────────────┘
```

**数据流方向**：

| 环节 | 坐标系 | 转换 |
|------|--------|------|
| 用户点击屏幕 | 屏幕像素 | ÷ scale → 基础像素 |
| 组件声明尺寸 | 基础像素 | 直接写数字 |
| Yoga 计算布局 | 基础像素 | 在 baseWidth × baseHeight 空间中计算 |
| NanoVG 渲染 | 基础像素 → 屏幕像素 | nvgScale(scale, scale) 自动放大 |

---

## 三、Scale 的计算

### 3.1 初始化

```lua
UI.Init({
    fonts = { ... },
    scale = UI.Scale.DEFAULT,  -- 推荐：DPR + 密度自适应
})
```

### 3.2 UI.Scale.DEFAULT 算法

```lua
-- UI.Scale.DEFAULT = UI.Scale.DPR_DENSITY_ADAPTIVE
function DPR_DENSITY_ADAPTIVE()
    local dpr = graphics:GetDPR()

    -- 取逻辑短边（物理分辨率 ÷ DPR）
    local shortSide = math.min(graphics.width, graphics.height) / dpr

    -- 以 720 CSS-px 为参考基线，计算密度因子
    local PC_REF = 720
    local densityFactor = math.sqrt(shortSide / PC_REF)
    densityFactor = math.max(0.625, math.min(densityFactor, 1.0))

    return dpr * densityFactor
end
```

### 3.3 计算示例

| 屏幕 | 物理分辨率 | DPR | 逻辑短边 | densityFactor | scale | 基础分辨率 |
|------|-----------|-----|---------|---------------|-------|-----------|
| 标准笔记本 | 1920×1080 | 2.0 | 540 | 0.866 | 1.73 | 1109×624 |
| 低分屏 | 1280×720 | 1.0 | 720 | 1.0 | 1.0 | 1280×720 |
| 4K 显示器 | 3840×2160 | 2.0 | 1080 | 1.0 | 2.0 | 1920×1080 |
| 手机竖屏 | 1242×2688 | 3.0 | 414 | 0.758 | 2.27 | 547×1184 |
| 小屏幕 | 800×600 | 1.0 | 600 | 0.913 | 0.913 | 876×657 |

**densityFactor 的作用**：当逻辑短边 < 720px 时自动放大 UI 元素，避免小屏幕上 UI 过小；当逻辑短边 ≥ 720px 时锁定为 1.0，不再继续缩小。

### 3.4 Scale 在框架中的三个应用点

```lua
-- 1. Yoga 像素对齐（避免亚像素模糊）
YGConfigSetPointScaleFactor(config, scale)

-- 2. Yoga 布局空间
local baseWidth  = screenWidth  / scale
local baseHeight = screenHeight / scale
YGNodeCalculateLayout(rootNode, baseWidth, baseHeight, YGDirectionLTR)

-- 3. NanoVG 渲染
nvgScale(nvg, scale, scale)
```

---

## 四、手机外框的自适应策略

### 4.1 设计尺寸定义

```lua
local PHONE = {
    WIDTH  = 380,     -- 手机屏幕宽度（基础像素）
    HEIGHT = 800,     -- 手机屏幕高度（基础像素）
    BORDER_RADIUS = 16,
    BORDER_WIDTH  = 3,
    STATUS_BAR_HEIGHT = 32,
}

local CASE = {
    PAD_SIDE   = 10,  -- 手机壳左右内边距
    PAD_TOP    = 14,  -- 手机壳顶部内边距
    PAD_BOTTOM = 16,  -- 手机壳底部内边距
    RADIUS     = 22,  -- 手机壳圆角
}
```

手机壳总尺寸（基础像素）：
- 宽度 = 380 + 10×2 = **400**
- 高度 = 800 + 14 + 16 = **830**
- 宽高比 = 400 / 830 ≈ **0.482**

### 4.2 三条自适应规则

```lua
local phoneCase = UI.Panel {
    -- 规则 1：高度占屏幕 90%（留出上下呼吸空间）
    height = "90%",

    -- 规则 2：最大高度 830（基础像素），防止大屏过度放大
    maxHeight = PHONE.HEIGHT + CASE.PAD_TOP + CASE.PAD_BOTTOM,

    -- 规则 3：锁定宽高比，宽度由高度自动推算
    aspectRatio = (PHONE.WIDTH + CASE.PAD_SIDE * 2)
               / (PHONE.HEIGHT + CASE.PAD_TOP + CASE.PAD_BOTTOM),

    -- 其余是样式
    backgroundColor = CASE.COLOR,
    borderRadius = CASE.RADIUS,
    paddingLeft = CASE.PAD_SIDE,
    paddingRight = CASE.PAD_SIDE,
    paddingTop = CASE.PAD_TOP,
    paddingBottom = CASE.PAD_BOTTOM,

    children = { phoneFrame_ },
}
```

**这三条规则的协同效果**：

| 屏幕高度（基础像素） | 90% 高度 | maxHeight 生效? | 最终高度 | 最终宽度 |
|---------------------|---------|----------------|---------|---------|
| 500 | 450 | 否 | 450 | 217 |
| 624 | 561 | 否 | 561 | 270 |
| 720 | 648 | 否 | 648 | 312 |
| 1000 | 900 | **是** | **830** | **400** |
| 1080 | 972 | **是** | **830** | **400** |

当屏幕足够大时，手机壳固定为 400×830 设计尺寸；屏幕小时按比例缩小但保持宽高比不变形。

### 4.3 居中方式

手机壳放在一个全屏 Flex 容器中居中：

```lua
local rootContainer = UI.Panel {
    width = "100%",
    height = "100%",
    justifyContent = "center",  -- 垂直居中
    alignItems = "center",      -- 水平居中
    children = { phoneCase },
}
```

---

## 五、子页面如何自适应

### 5.1 核心原则：子页面不需要知道手机尺寸

Yoga Flexbox 的相对布局使得子页面天然自适应父容器尺寸。所有子页面只需：

```lua
return UI.Panel {
    width  = "100%",           -- 继承父容器宽度
    height = "100%",           -- 继承父容器高度
    flexDirection = "column",
    children = { ... },
}
```

### 5.2 典型页面结构

```lua
-- 三段式布局（标题栏 + 内容区 + 底栏）
return UI.Panel {
    width = "100%", height = "100%",
    flexDirection = "column",
    children = {
        -- 标题栏：固定高度
        UI.Panel { height = 44, ... },

        -- 内容区：自动填充剩余空间
        UI.Panel { flexGrow = 1, flexBasis = 0, overflow = "hidden", ... },

        -- 底部输入栏：固定高度
        UI.Panel { height = 52, ... },
    },
}
```

`flexGrow = 1` 让内容区自动占满标题栏和底栏之间的所有空间，无论手机屏幕实际多高。

### 5.3 布局传递链

```
phoneCase (400×561)
  └─ phoneFrame_ (380×531, 扣除壳边距)
       └─ statusBar (380×32, 固定)
       └─ screenContainer_ (380×499, flexGrow=1)
            └─ DingtalkApp (100%×100% = 380×499)
                 └─ topBar (100%×44)
                 └─ content (100%×flexGrow = 380×455)
                      └─ ChatPage (100%×100% = 380×455)
                           └─ chatHeader (100%×44)
                           └─ messageList (100%×flexGrow)
                           └─ inputBar (100%×52)
```

每一层只关心 `width="100%"` 和 `flexGrow=1`，不需要硬编码任何像素值。

---

## 六、字体和间距的缩放

### 6.1 字体

组件代码中直接写 pt 值，Theme 层自动转换：

```lua
-- 组件代码
UI.Label { fontSize = 12 }   -- 12pt

-- Theme 内部转换
Theme.FontSize(12)            -- → 12 × 1.333 ≈ 16 (基础像素)

-- NanoVG 渲染
nvgFontSize(nvg, 16)          -- 基础像素
nvgScale(nvg, scale, scale)   -- × scale → 屏幕像素
```

**最终屏幕上的像素**：16 × scale（如 scale=1.73 → 约 28 屏幕像素）。

### 6.2 间距和圆角

直接用基础像素数字，不需要任何换算：

```lua
UI.Panel {
    padding = 16,         -- 基础像素
    margin = 8,           -- 基础像素
    borderRadius = 12,    -- 基础像素
    gap = 8,              -- 子元素间距，基础像素
}
```

### 6.3 关键规则

| 做法 | 正确性 |
|------|-------|
| `fontSize = 12` | 正确，框架自动处理 |
| `padding = 16` | 正确，框架自动处理 |
| `width = 380` | 正确，基础像素 |
| `width = 380 * scale` | **错误**，会导致双重缩放 |
| `fontSize = 12 * dpr` | **错误**，会导致双重缩放 |

---

## 七、手机框架外的元素定位

手机壳外的桌面元素（便签、桌面小组件等）不在 phoneCase 的 Flexbox 布局中，需要手动计算位置：

```lua
local dpr = graphics:GetDPR()
local logW = graphics:GetWidth() / dpr    -- 逻辑宽度（系统逻辑分辨率）
local logH = graphics:GetHeight() / dpr   -- 逻辑高度

-- 计算手机壳左侧的可用空间
local phoneCaseW = PHONE.WIDTH + CASE.PAD_SIDE * 2  -- 400 基础像素
local leftArea = (logW - phoneCaseW) / 2             -- 手机壳左侧空白

-- 将桌面便签放在手机左侧
local stickyNoteX = math.max(8, leftArea - stickyNoteW - 16)
```

**注意**：这里用的是 `logW`（逻辑分辨率）而非 `baseWidth`（基础像素），因为桌面元素通过独立的 `DeskWidget.Create()` 管理定位，不在 Yoga 布局树中。

---

## 八、坐标系速查表

| 数据 | 坐标系 | 典型值 |
|------|--------|--------|
| `graphics.width / graphics.height` | 屏幕像素（物理分辨率） | 1920 × 1080 |
| `graphics:GetDPR()` | 设备像素比 | 1.0 / 2.0 / 3.0 |
| `width / dpr`（逻辑分辨率） | 系统逻辑像素 | 960 × 540 |
| `UI.Scale.DEFAULT()` | scale 因子 | 1.73 |
| `screenWidth / scale`（基础分辨率） | 基础像素 | 1109 × 624 |
| `PHONE.WIDTH / HEIGHT` | 基础像素 | 380 × 800 |
| 组件的 `width / height / padding / fontSize` | 基础像素 / pt | 直接写数字 |
| `GetLayout()` 返回值 | 基础像素 | Yoga 计算结果 |
| NanoVG 最终渲染 | 屏幕像素 | 基础像素 × scale |

**换算关系**：

```
屏幕像素 ÷ DPR = 逻辑像素
屏幕像素 ÷ scale = 基础像素
基础像素 × scale = 屏幕像素
```

---

## 九、常见问题与解决

### Q1：手机在小屏幕上显示太小

**原因**：`height="90%"` + `aspectRatio` 导致小屏幕上手机等比缩小。

**解决**：
- 降低 `maxHeight` 或去掉 `maxHeight` 限制
- 改用 `height="95%"` 减少留白
- 或设置 `minHeight` 保证最小可用尺寸

### Q2：手机在大屏幕上太小，周围大量留白

**原因**：`maxHeight = 830` 限制了手机最大尺寸。

**解决**：
- 提高或去掉 `maxHeight`
- 在手机壳外增加装饰元素填充留白（如桌面便签、背景图案）

### Q3：字体在某些分辨率下模糊

**原因**：scale 非整数时可能出现亚像素渲染。

**解决**：
- `YGConfigSetPointScaleFactor(scale)` 已处理 Yoga 布局的像素对齐
- NanoVG 文本渲染本身会做亚像素抗锯齿，通常不需要额外处理
- 如果仍有问题，可将 scale 四舍五入到 0.5 的倍数

### Q4：子页面内容溢出手机框架

**原因**：Yoga 默认 `flexShrink = 0`，子元素不会自动缩小。

**解决**：
```lua
UI.Panel {
    flexGrow = 1,
    flexShrink = 1,     -- 允许缩小
    flexBasis = 0,
    overflow = "hidden", -- 裁剪溢出内容
}
```

### Q5：想在组件中获取当前 scale 值

```lua
-- 通常不需要，但如果确实需要：
local scale = UI.GetScale()  -- 框架提供的获取方法
```

---

## 十、方案总结

```
          ┌─ UI.Init(scale=DEFAULT) ──────────────────────┐
          │                                                │
          │  scale = DPR × clamp(√(shortSide/720), 0.625, 1.0)
          │                                                │
          ├─ Yoga 空间 ───────────────────────────────────┤
          │  baseW = screenW / scale                       │
          │  baseH = screenH / scale                       │
          │  所有组件在 baseW×baseH 空间中 Flexbox 布局     │
          │                                                │
          ├─ 手机壳适配 ─────────────────────────────────┤
          │  height = "90%"           ← 自适应屏幕高度     │
          │  maxHeight = 830          ← 上限保护           │
          │  aspectRatio = 0.482      ← 宽高比锁定         │
          │  justifyContent = "center"← 居中               │
          │                                                │
          ├─ 子页面 ──────────────────────────────────────┤
          │  width = "100%"           ← 继承手机屏幕宽度   │
          │  flexGrow = 1             ← 自动填充剩余高度   │
          │  （不需要任何 scale 计算）                      │
          │                                                │
          ├─ 渲染 ────────────────────────────────────────┤
          │  nvgScale(scale, scale)   ← 基础像素→屏幕像素  │
          │                                                │
          └─ 事件 ────────────────────────────────────────┘
             event.xy / scale         ← 屏幕像素→基础像素
```

**核心优势**：

1. **开发者无感**：组件代码只写固定数字（基础像素），不关心屏幕分辨率
2. **自动适配**：同一份代码在 720p 到 4K 屏幕上都能正确显示
3. **像素对齐**：`YGConfigSetPointScaleFactor` 确保无亚像素模糊
4. **单一缩放点**：所有缩放转换集中在框架层（`nvgScale` + 事件坐标转换），不分散在业务代码中
