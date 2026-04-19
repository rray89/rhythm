# Mac App Store 检查清单（未来待办）

这份文档只是为未来可能的 Mac App Store 发布做准备的检查清单。
它不属于当前 V2 范围，也不应该阻塞现在的直接分发路径。

## 当前判断

- Rhythm 目前还不算是可以直接提交 Mac App Store 的状态。
- 但它看起来也不是从根上就不适合上架。
- 更像是需要补齐打包、sandbox，以及少量 API / 审核风险清理，而不是重做产品。

## 主要缺口

### 1. 补一条真正的 App Store 构建路径

- 不要把 `scripts/package_dmg.sh` 继续当成这个方向的发布方案。
- 为 App Store 单独准备一套打包 / 签名 / 上传流程。
- 继续把直接分发的 DMG 路径和未来 App Store archive 路径分开维护。

仓库关注点：

- `scripts/package_dmg.sh`

### 2. 增加 App Sandbox 支持

- 增加 macOS App Sandbox capability 与 entitlements。
- 在 sandbox 条件下重新验证所有文件访问和系统集成行为。
- 确认本地历史、生命周期恢复状态与导出功能在 app container 内仍然正常。

仓库关注点：

- `Sources/RhythmCore/Persistence.swift`
- `Sources/RhythmCore/AppLifecycleStore.swift`

### 3. 为商店构建重审开机启动逻辑

- 如果 `SMAppService.mainApp` 在商店构建里表现正常，可以继续保留。
- 触达 `~/Library/LaunchAgents` 与调用 `launchctl` 的旧迁移清理逻辑，需要移除、禁用，或只留给非商店构建。
- 只在安装到 `/Applications` 后再重新验证登录启动行为。

仓库关注点：

- `Sources/RhythmApp/LaunchAtLoginManager.swift`

### 4. 按照公开 API 预期重查锁屏 / 解锁检测

- 重新确认当前锁屏检测方案是否适合 App Store 提交。
- 如果现在基于 `DistributedNotificationCenter` 的锁屏通知不适合继续依赖，就需要替换，或者在商店构建中优雅降级。
- 如果睡眠 / 唤醒路径依然可靠且属于可接受范围，则尽量保留。

仓库关注点：

- `Sources/RhythmApp/LockMonitor.swift`
- `Sources/RhythmApp/SleepWakeMonitor.swift`

### 5. 在 Sandboxed Build 里重测休息遮罩

- 在开启 sandbox 且使用正式签名后，重新测试全屏休息遮罩。
- 确认强制聚焦、全屏覆盖、以及 ESC 跳过行为仍然符合预期。
- 提前准备给 App Review 的说明，解释遮罩是核心休息提醒交互，以及如何退出 / 跳过。

仓库关注点：

- `Sources/RhythmApp/OverlayManager.swift`

### 6. 准备 App Store Connect 元数据

- 决定 Mac App Store 版本是免费还是付费。
- 准备应用描述、副标题、截图、支持 URL、隐私政策 URL。
- 提前写好 reviewer notes，解释：
  - 菜单栏行为
  - 开机启动
  - 休息遮罩行为
  - 锁屏 / 睡眠相关行为该如何触发和验证

## 未来建议顺序

1. 先做出一条 sandboxed 的 App Store 构建路径。
2. 在这条构建路径下修正开机启动和锁屏检测问题。
3. 重新验证遮罩、通知、持久化、导出和 Insights。
4. 准备元数据与 reviewer notes。
5. 再决定 App Store 发布是否值得持续维护。

## 参考链接

- Apple App Sandbox 总览：
  - <https://developer.apple.com/documentation/security/app-sandbox>
- Apple macOS sandbox 配置：
  - <https://developer.apple.com/documentation/xcode/configuring-the-macos-app-sandbox>
- Apple App Review 入口：
  - <https://developer.apple.com/app-store/review/>
