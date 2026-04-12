# Rhythm

[English](README.md) | **中文**

Rhythm 是一个 macOS 节奏提醒工具，帮助用户建立稳定的「专注-休息」电脑使用节奏。

<img src="assets/rhythm-logo.svg" alt="Rhythm Logo" width="64" />

## 界面预览

<img src="assets/menu-panel.png" alt="Rhythm Menu Panel" width="480" />

<img src="assets/rest-overlay.png" alt="Rhythm Rest Overlay" width="480" />

## 文档说明

本 README 描述当前 fork 已落地的产品行为；如果你想区分上游 V1 基线与 fork 的后续方向，请同时参考以下文档：

- [English README](README.md)：英文版已发布功能说明
- [V1 设计文档](docs/V1-design.md)：上游 `main` 的 V1 基线与历史设计记录
- [V2 PRD（中文 / Fork 草案）](docs/V2-prd.zh.md)：fork 当前基线与下一阶段方向
- [V2 PRD (English / Fork Draft)](docs/V2-prd.en.md)：fork 基线与路线图的英文版本

## 当前功能

- 自定义节奏：可设置专注间隔（10-120 分钟，5 分钟步进）和休息时长（30 秒-20 分钟，常用档位）
- Phase 临时控制：支持 `提前休息 5 分钟`、`延长专注 5 分钟`、`延长专注 10 分钟`，以及当前休息阶段延长
- 中英双语：支持 `中文` / `English` 界面切换；首次使用时，`zh*` 系统语言默认中文，其他语言默认英文
- 每日总量：菜单中保留紧凑的 `今日` 专注 / 休息内联总量摘要，并提供快速进入数据概览的入口
- 数据概览窗口：可从菜单打开独立窗口，查看 `今日`、`最近 7 天`、`最近 30 天`、`全部历史` 汇总、紧凑范围总量、按天浏览的 session 列表，以及按范围导出；固定范围图表会遵循当前配置的统计日切换点，而 `全部历史` 会按月聚合
- 日切换点：可在设置中把“今天”的统计分界点调到 `00:00`-`23:00`
- 不休息模式：可开启“不休息”，到点自动跳过并记录本次应休息会话
- 锁屏离屏休息：锁屏会结束当前专注或休息片段，并把锁定到解锁之间的时间记为离屏休息；解锁后自动开始新的专注周期
- 睡眠离屏休息：如果 Mac 在未先锁屏的情况下直接进入睡眠，Rhythm 会在入睡时结束当前可见片段，并把睡眠时间记为隐藏休息；若唤醒后先进入锁屏，则会继续累计到真正解锁
- 应用关闭休息：正常退出或关机时会记录关闭时间；下次启动时把关闭期间记为隐藏休息，并用 15 分钟 heartbeat 作为异常退出兜底，单次最多计入 12 小时
- 桌前休息：菜单中提供单独的 `桌前休息` 快捷动作，用于“继续用电脑但不工作”的休息场景
- 休息呈现分层：
  - 普通休息使用全屏半透明遮罩，支持 `ESC` 提前结束
  - `桌前休息` 不锁屏，可继续使用 Mac，倒计时在菜单中继续，结束后自动恢复专注并尝试发送通知
- 数据记录：保存专注 / 休息片段、计划时长、实际时长、结束原因，并按周写入本地 `Application Support/Rhythm/history/weeks/` JSON 历史目录；数据概览窗口提供固定范围图表，其中 `全部历史` 使用按月聚合，支持按统计日逐天浏览 session，并支持把 `今日`、`最近 7 天`、`最近 30 天`、`全部历史`、当前所选统计日 导出为 CSV 或 JSON；应用关闭恢复状态写入 `Application Support/Rhythm/state/app-lifecycle.json`
- 菜单栏应用：常驻状态栏，保留图标并实时显示当前倒计时，快速查看状态与最近记录
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
- 专注 / 休息 history、周目录迁移与每日总量统计
- 数据概览快照、隐藏休息历史状态与固定范围 / 所选日期 CSV / JSON 导出
- 跳过休息与 `桌前休息` 的 session 记录
- 锁屏离屏休息与解锁后新专注周期
- 睡眠离屏休息与唤醒后新专注周期
- 应用关闭后的隐藏休息、heartbeat 异常退出恢复与 12 小时上限
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
├── README.md
├── README.zh.md
├── docs/
│   ├── V1-design.md
│   ├── V2-prd.zh.md
│   └── V2-prd.en.md
├── Sources/
│   ├── RhythmApp/
│   │   ├── AppModel.swift
│   │   ├── BreakNotificationManager.swift
│   │   ├── InsightsView.swift
│   │   ├── LaunchAtLoginManager.swift
│   │   ├── LockMonitor.swift
│   │   ├── LongBreakPresetsView.swift
│   │   ├── MenuBarView.swift
│   │   ├── OverlayManager.swift
│   │   ├── RhythmBrand.swift
│   │   ├── SleepWakeMonitor.swift
│   │   ├── RhythmWindowID.swift
│   │   └── RhythmApp.swift
│   ├── RhythmCore/
│   │   ├── AppLifecycleStore.swift
│   │   ├── BreakKind.swift
│   │   ├── HistoryInsights.swift
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
