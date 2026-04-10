# Rhythm

Rhythm 是一个 macOS 节奏提醒工具，帮助用户建立稳定的「专注-休息」电脑使用节奏。

<img src="assets/rhythm-logo.svg" alt="Rhythm Logo" width="64" />

## 界面预览

<img src="assets/menu-panel.png" alt="Rhythm Menu Panel" width="480" />

<img src="assets/rest-overlay.png" alt="Rhythm Rest Overlay" width="480" />

## 文档说明

本 README 描述当前 fork 已落地的产品行为；如果你想区分上游 V1 基线与 fork 的后续方向，请同时参考以下文档：

- [V1 设计文档](docs/V1-design.md)：上游 `main` 的 V1 基线与历史设计记录
- [V2 PRD（中文 / Fork 草案）](docs/V2-prd.zh.md)：fork 当前基线与下一阶段方向
- [V2 PRD (English / Fork Draft)](docs/V2-prd.en.md): English companion version of the fork baseline and roadmap

## 当前功能

- 自定义节奏：可设置专注间隔（10-120 分钟，5 分钟步进）和休息时长（30 秒-20 分钟，常用档位）
- Phase 临时控制：支持 `提前休息 5 分钟`、`延长专注 5 分钟`、`延长专注 10 分钟`，以及当前休息阶段延长
- 中英双语：支持 `中文` / `English` 界面切换；首次使用时，`zh*` 系统语言默认中文，其他语言默认英文
- 不休息模式：可开启“不休息”，到点自动跳过并记录本次应休息会话
- 锁屏重置：检测到系统锁屏后重置当前计时周期
- 长休息预设：菜单中可直接开始 `用餐`、`健身`、`小憩`、`外出`、`桌前休息`
- 休息呈现分层：
  - 普通休息、用餐、健身、小憩、外出使用全屏半透明遮罩，支持 `ESC` 提前结束
  - `桌前休息` 不锁屏，可继续使用 Mac，倒计时在菜单中继续，结束后自动恢复专注并尝试发送通知
- 数据记录：保存每次休息的类型、计划时长、实际时长、是否跳过
- 菜单栏应用：常驻状态栏，快速查看状态与最近记录
- 开机启动：支持在菜单中开启/关闭登录时启动（打包安装后可用）

## 技术栈

- Swift 6
- SwiftUI + AppKit
- Swift Package Manager

## 本地运行

```bash
swift build
swift run Rhythm
```

> 注意：需要在 macOS 环境运行。首次运行可能需要在系统设置中允许应用窗口置顶或辅助功能能力（取决于系统策略）。

## TDD 回归检查

```bash
swift run RhythmTDD
```

该命令会执行一组可重复的回归检查，覆盖：

- 设置变更回调、范围归一化与历史配置迁移
- 中英双语解析、持久化与文案格式化
- 跳过休息、长休息与 `桌前休息` 的 session 记录
- 锁屏导致的计时周期重置
- 休息遮罩可见性与焦点（自动 smoke）

如需临时跳过 UI 集成 smoke：

```bash
RHYTHM_TDD_UI=0 swift run RhythmTDD
```

手动跑遮罩 smoke（默认仅输出 smoke 流程日志）：

```bash
RHYTHM_SMOKE_OVERLAY=1 swift run Rhythm
```

如需输出遮罩焦点细节日志，再加：

```bash
RHYTHM_SMOKE_OVERLAY=1 RHYTHM_OVERLAY_DEBUG=1 swift run Rhythm
```

## 项目结构

```txt
.
├── AGENTS.md
├── docs/
│   ├── V1-design.md
│   ├── V2-prd.zh.md
│   └── V2-prd.en.md
├── Sources/
│   ├── RhythmApp/
│   │   ├── AppModel.swift
│   │   ├── BreakNotificationManager.swift
│   │   ├── LaunchAtLoginManager.swift
│   │   ├── LockMonitor.swift
│   │   ├── LongBreakPresetsView.swift
│   │   ├── MenuBarView.swift
│   │   ├── OverlayManager.swift
│   │   ├── RhythmBrand.swift
│   │   └── RhythmApp.swift
│   ├── RhythmCore/
│   │   ├── BreakKind.swift
│   │   ├── Localization.swift
│   │   ├── Persistence.swift
│   │   └── TimerEngine.swift
│   └── RhythmTDD/
│       └── RhythmTDDRunner.swift
└── Package.swift
```

## 开源

- License: MIT
- 欢迎通过 Issue / PR 贡献

## 品牌资产

- Logo 源文件：`assets/rhythm-logo.svg`
- 面板截图：`assets/menu-panel.png`
- 休息提醒截图：`assets/rest-overlay.png`
