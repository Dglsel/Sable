# Sable UI Design Brief

> 给外部设计工具（Codex / Figma AI / 其他 AI）的上下文文档。
> 目标：让设计师/AI 理解项目现状，输出可落地的视觉方案。

---

## 1. 产品定位

Sable 是 **OpenClaw**（AI Agent 平台）的 **macOS 原生桌面驾驶舱**。
用 SwiftUI + SwiftData 构建，目标用户是开发者/高级用户。

**核心气质**：克制、原生、高级、轻量。
**参考方向**：Apple Notes、Things 3、Linear Desktop、Arc Browser。
**反面参考**：Electron 套壳、网页感强的 UI、花哨动画。

---

## 2. 技术栈

| 层 | 技术 |
|---|---|
| UI 框架 | SwiftUI (macOS 14+) |
| 持久化 | SwiftData |
| 后端通信 | WebSocket (ACP 协议) + CLI subprocess fallback |
| 窗口 | 单窗口 + 设置独立窗口 |

---

## 3. 页面结构

```
┌─────────────────────────────────────────────┐
│  Toolbar: [sidebar] [+] [model]    [gear]   │
├────────────┬────────────────────────────────┤
│  Sidebar   │  Main Content                  │
│            │                                │
│  Dashboard │  (根据 sidebar 选中态切换)       │
│  Agents    │  - DashboardView               │
│  Skills    │  - AgentsView                  │
│  Chat      │  - SkillsView                  │
│            │  - ChatHomeView                │
│  ────────  │                                │
│  Recent    │                                │
│  对话列表   │                                │
│            │                                │
│  ────────  │                                │
│  Settings  │                                │
└────────────┴────────────────────────────────┘
```

---

## 4. 设计系统 Token

### 颜色

| Token | 值 | 用途 |
|-------|---|------|
| accent | RGB(0.36, 0.46, 0.49) | 主题色，柔和蓝绿 |
| sidebarBackground | NSColor.underPageBackgroundColor | 侧栏背景 |
| chatBackground | NSColor.windowBackgroundColor | 主内容区背景 |
| userBubble (light) | RGB(0.94, 0.95, 0.96) | 用户消息气泡 |
| userBubble (dark) | RGB(0.24, 0.24, 0.26) | 用户消息气泡 |
| assistantBubble (dark) | RGB(0.18, 0.18, 0.19) | 助手消息气泡 |
| inputBg (dark) | RGB(0.16, 0.16, 0.17) | 输入框背景 |
| border | primary @ 8% opacity | 通用边框 |
| textPrimary (light) | black @ 88% | 主文本 |
| textPrimary (dark) | white @ 94% | 主文本 |
| textSecondary (light) | black @ 52% | 次要文本 |
| textSecondary (dark) | white @ 60% | 次要文本 |

### 间距

| Token | 值 |
|-------|---|
| xSmall | 6pt |
| small | 10pt |
| medium | 16pt |
| large | 24pt |
| xLarge | 32pt |

### 布局约束

| Token | 值 |
|-------|---|
| sidebarWidth | 240pt (220-260) |
| chatColumnMaxWidth | 720pt |
| messageBubbleMaxWidth | 660pt |
| composerMaxWidth | 720pt |
| sidebarRowCornerRadius | 10pt |
| sidebarRowSpacing | 3pt |

---

## 5. 各页面现状与设计需求

### Chat（核心页面，最多精力）

**现状**：
- 消息列表：assistant 左侧（sparkles 图标 + 文本），user 右对齐
- 正在实现 WebSocket streaming（助手回复按 block 增量到达）
- Action bar 以 overlay 浮层显示，hover 触发
- ThinkingIndicator：三点脉冲 + 2秒后显示计时
- Metadata：消息下方轻量注脚（耗时、token 数）

**设计需求**：
- 消息列表的整体节奏和呼吸感
- streaming 状态下消息的视觉表达
- 输入框（ChatInputBar）的精细度
- 空状态（EmptyStateView）的优雅度

### Dashboard

**现状**：功能性仪表盘，显示 OpenClaw 运行状态。
**设计需求**：状态卡片的布局和视觉层级。

### Agents

**现状**：左侧 section 列表 + 右侧编辑器（markdown/structured form）。
**设计需求**：编辑器区域的排版和表单字段样式。

### Skills

**现状**：技能列表 + 详情 + 安装面板。
**设计需求**：列表卡片和详情页的视觉一致性。

### Sidebar

**现状**：
- 导航项（Dashboard/Agents/Skills/Chat）+ Recent 对话列表
- 展开/收起用两阶段动画（内容淡出→宽度收缩 / 宽度展开→内容淡入）
- 选中态：accent @ 18% 背景
- 对话行：标题 + 时间戳 + 预览

**设计需求**：整体精致度，特别是 Recent 列表的密度和节奏。

---

## 6. 已确定的设计决策（不要推翻）

1. **action bar 用 overlay**，不用 inline 展开（避免 hover 时的 layout shift）
2. **侧栏选中态是半透明 accent 背景**，不是实色填充
3. **侧栏开合是两阶段动画**：内容 opacity ↔ 容器 width 分离
4. **顶栏只做轻量全局控制**，不承担页面主标题
5. **model 标签在顶栏左侧**，纯只读状态显示，不是选择器
6. **不做假 streaming**，已实现真 WebSocket 直连

---

## 7. 已否决的方案（不要再提）

- 顶栏中间放"页面名 + 模型名"的大胶囊
- action bar 用 `frame(height:0) + clipped()` 展开（有 gap 问题）
- 选中态用纯白文字 + 实色 accent 背景（太重）
- 把 model 信息移到 ChatInputBar 上方

---

## 8. 输出要求

如果你为 Sable 设计 UI，请：

1. **输出静态视觉稿**（截图/描述），不要直接输出 SwiftUI 代码
2. **遵循上面的 token 值**，不要自创颜色/间距
3. **保持克制**：宁可简单也不要花哨
4. **适配 light + dark mode**
5. **标注关键尺寸**：字号、间距、圆角、opacity
6. **说明设计意图**：为什么这样选，解决什么问题

---

## 9. 当前优先级

| 优先级 | 页面/区域 | 说明 |
|--------|----------|------|
| P0 | Chat 消息列表 | 核心体验，streaming 后需要重新审视节奏 |
| P1 | ChatInputBar | 当前样式偏基础 |
| P1 | EmptyStateView | 第一印象 |
| P2 | Dashboard | 状态展示 |
| P2 | Sidebar Recent 列表 | 已基本成立，可继续精修 |
| P3 | Agents 编辑器 | 功能优先，视觉其次 |
| P3 | Skills 列表 | 同上 |
