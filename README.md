# PauseMate

macOS 13+ 工作节律原型。PauseMate 每 30、45 或 60 分钟邀请用户离开屏幕活动 1 分钟，提供多显示器休息界面、可选图片/视频背景、暂停与立即休息控制。

## 打开与运行

1. 使用 Xcode 打开 `PauseMate.xcodeproj`。
2. 选择 PauseMate scheme 与本机 Mac 目标。
3. 首次运行会显示设置窗口，选择间隔后点击“开始计划”。
4. 菜单栏图标提供常驻控制入口；“立即休息”可验证遮罩。

也可在 Xcode 中对 `PauseMate` scheme 执行 Product → Test。

## 原型边界

- 遮罩为每个当前显示器创建 `.screenSaver` 层级面板，并加入所有 Spaces / 全屏辅助空间；macOS 不保证覆盖系统安全界面或所有全屏环境。
- 不启用 CGEventTap 或全局键鼠拦截。遮罩提供 Control + Option + Escape 紧急恢复；强制退出应用仍可关闭遮罩。
- 自定义媒体由 NSOpenPanel 选择，以 security-scoped bookmark 持久保存。
- 休息完成指用户主动确认，不声称应用验证了实际身体活动。
- iPhone 同步、开机启动、持久化运行状态和健康统计属于后续阶段。

## 视觉方向

沿用品牌概念板的海洋蓝、活力绿与青绿色，采用舒展人物 SF Symbol 与环形弧线表达从专注到活动的转换。界面避免锁头、红色警告和惩罚措辞。
