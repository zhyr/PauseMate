import AppKit
import Carbon
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

@main
struct PauseMateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    var body: some Scene { Settings { EmptyView() } }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    private let engine = TimerEngine()
    private let overlay = OverlayManager()
    private let breakShortcut = PauseBreakShortcut()
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var emergencyKeyMonitor: Any?
    private let defaults = UserDefaults.standard
    private var intervalMinutes: Int { defaults.object(forKey: "intervalMinutes") as? Int ?? 45 }
    private var mediaURL: URL? {
        guard let data = defaults.data(forKey: "mediaBookmark") else { return nil }
        var stale = false
        return try? URL(resolvingBookmarkData: data, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &stale)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        breakShortcut.onTrigger = { [weak self] in self?.engine.triggerBreak() }
        breakShortcut.register()
        overlay.setMedia(mediaURL)
        engine.onBreakStart = { [weak self] in
            guard let self else { return }
            self.overlay.show(engine: self.engine) { self.engine.endBreak() }
            self.emergencyKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                let isEmergency = event.keyCode == 53 && event.modifierFlags.contains([.control, .option])
                if isEmergency { Task { @MainActor in self.engine.endBreak() }; return nil }
                return event
            }
        }
        engine.onBreakEnd = { [weak self] in
            guard let self else { return }
            self.overlay.hide()
            if let monitor = self.emergencyKeyMonitor { NSEvent.removeMonitor(monitor); self.emergencyKeyMonitor = nil }
        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "figure.cooldown", accessibilityDescription: "PauseMate")
        statusItem.button?.toolTip = "PauseMate 健康工作节律"
        let menu = NSMenu()
        menu.addItem(withTitle: "显示 PauseMate", action: #selector(showSettingsFromMenu), keyEquivalent: "")
        menu.addItem(withTitle: "立即休息  ⌃⌥⌘L", action: #selector(triggerBreakFromMenu), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出 PauseMate", action: #selector(quitFromMenu), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
        showSettings()
    }

    @objc private func showSettingsFromMenu() { showSettings() }
    @objc private func triggerBreakFromMenu() { engine.triggerBreak() }
    @objc private func quitFromMenu() { engine.stop(); NSApp.terminate(nil) }

    private func showSettings() {
        if let settingsWindow { settingsWindow.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let view = SettingsView(engine: engine, shortcut: breakShortcut, interval: intervalMinutes, mediaURL: mediaURL, onInterval: { [weak self] in self?.defaults.set($0, forKey: "intervalMinutes") }, onMedia: { [weak self] url in
            guard let self else { return }
            if let url {
                let data = try? url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
                self.defaults.set(data, forKey: "mediaBookmark")
            } else { self.defaults.removeObject(forKey: "mediaBookmark") }
            self.overlay.setMedia(url)
        })
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 470, height: 710), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "PauseMate"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: view)
        let communityAccessory = NSTitlebarAccessoryViewController()
        communityAccessory.layoutAttribute = .right
        communityAccessory.view = NSHostingView(
            rootView: CommunityTitlebarButton()
                .frame(width: 82, height: 30)
        )
        window.addTitlebarAccessoryViewController(communityAccessory)
        window.makeKeyAndOrderFront(nil)
        settingsWindow = window
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct CommunityTitlebarButton: View {
    private let communityURL = URL(string: "https://haxitag.com/community")!

    var body: some View {
        Button {
            NSWorkspace.shared.open(communityURL)
        } label: {
            Label("社区", systemImage: "arrow.up.right.square")
        }
        .labelStyle(.titleAndIcon)
        .font(.system(size: 12, weight: .medium))
        .buttonStyle(.borderless)
        .help("访问 HaxiTAG 社区")
        .accessibilityLabel("打开 HaxiTAG 社区")
    }
}

private struct SettingsView: View {
    @ObservedObject var engine: TimerEngine
    @ObservedObject var shortcut: PauseBreakShortcut
    @ObservedObject var model: SettingsModel
    let onInterval: (Int) -> Void
    let onMedia: (URL?) -> Void

    init(engine: TimerEngine, shortcut: PauseBreakShortcut, interval: Int, mediaURL: URL?, onInterval: @escaping (Int) -> Void, onMedia: @escaping (URL?) -> Void) {
        self.engine = engine
        self.shortcut = shortcut
        self.model = SettingsModel(interval: interval, mediaURL: mediaURL)
        self.onInterval = onInterval
        self.onMedia = onMedia
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 14) {
                BrandMark().frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 3) { Text("PauseMate").font(.system(size: 24, weight: .bold, design: .rounded)); Text("Take a Break. Be Healthier.").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary) }
            }
            Text("建立健康的工作节律").font(.system(size: 20, weight: .semibold, design: .rounded))
            Text("每隔一段时间暂停工作，花一分钟活动身体。温和提醒，专注休息，随时可恢复。").font(.system(size: 13)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            GroupBox("工作间隔") {
                Picker("工作间隔", selection: $model.interval) { Text("30 分钟").tag(30); Text("45 分钟").tag(45); Text("60 分钟").tag(60) }.pickerStyle(.segmented).labelsHidden().onChange(of: model.interval) { value in onInterval(value); if isRunning { engine.start(intervalMinutes: value) } }
                Text("休息时长：1 分钟 · 推荐：45 分钟").font(.system(size: 11)).foregroundStyle(.secondary).padding(.top, 7)
            }
            GroupBox("启动选项") {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("登录时自动启动 PauseMate", isOn: $model.launchAtLoginEnabled)
                        .onChange(of: model.launchAtLoginEnabled) { enabled in
                            model.setLaunchAtLogin(enabled)
                        }
                    if let message = model.launchAtLoginMessage {
                        Text(message).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            GroupBox("快捷键") {
                HStack {
                    Label("立即开始休息", systemImage: "keyboard")
                    Spacer()
                    Text("⌃⌥⌘L")
                        .font(.system(size: 12, weight: .semibold, design: .rounded).monospaced())
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color(nsColor: .quaternaryLabelColor).opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
                }
                Text(shortcut.statusMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 5)
            }
            GroupBox("休息背景") {
                HStack { Label(model.mediaURL?.lastPathComponent ?? "使用 PauseMate 品牌背景", systemImage: model.mediaURL == nil ? "sparkles" : "photo").lineLimit(1); Spacer(); Button("选择…", action: chooseMedia) }
                if model.mediaURL != nil { Button("移除自定义背景") { model.mediaURL = nil; onMedia(nil) }.font(.system(size: 11)).buttonStyle(.link).padding(.top, 4) }
            }
            VStack(spacing: 12) {
                HStack { Text(stateLabel).font(.system(size: 13, weight: .medium)); Spacer(); if isRunning || isOnBreak { Text(timeString(engine.remaining)).font(.system(size: 15, weight: .semibold, design: .rounded).monospacedDigit()).foregroundStyle(Color.teal) } }
                HStack(spacing: 10) {
                    Button(action: toggle) { Label(isRunning ? "暂停计划" : (isPaused ? "继续计划" : "开始计划"), systemImage: isRunning ? "pause.fill" : "play.fill").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).tint(Color(red: 0.12, green: 0.60, blue: 0.57))
                    Button("立即休息") { engine.triggerBreak() }.frame(maxWidth: .infinity).buttonStyle(.bordered)
                }
                if isPaused || isRunning { Button("停止计划") { engine.stop() }.buttonStyle(.link).font(.system(size: 12)) }
            }.padding(16).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
            HStack { Label("已完成休息", systemImage: "checkmark.circle"); Spacer(); Text("\(engine.completedBreaks) 次").foregroundStyle(.secondary) }.font(.system(size: 12))
            Spacer(minLength: 0)
            Text("遮罩在常见空间中显示；macOS 系统安全界面和部分全屏场景可能不受覆盖。紧急关闭：Control + Option + Escape。未启用全局键鼠拦截。").font(.system(size: 10)).foregroundStyle(.tertiary).fixedSize(horizontal: false, vertical: true)
        }.padding(26).frame(minWidth: 430, minHeight: 660)
    }

    private var isRunning: Bool { if case .running = engine.state { true } else { false } }
    private var isPaused: Bool { if case .paused = engine.state { true } else { false } }
    private var isOnBreak: Bool { if case .breakActive = engine.state { true } else { false } }
    private var stateLabel: String { isOnBreak ? "正在休息 · 起来活动一下" : isRunning ? "节律运行中" : isPaused ? "计划已暂停" : "计划未启动" }
    private func toggle() { if isRunning { engine.pause() } else if isPaused { engine.resume() } else { engine.start(intervalMinutes: model.interval) } }
    private func timeString(_ time: TimeInterval) -> String { let s = max(0, Int(ceil(time))); return String(format: "%02d:%02d", s / 60, s % 60) }
    private func chooseMedia() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.png, .jpeg, .mpeg4Movie, .quickTimeMovie]; panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { model.mediaURL = url; onMedia(url) }
    }
}

@MainActor
private final class PauseBreakShortcut: ObservableObject {
    @Published private(set) var statusMessage = "在任何应用中按下 Control + Option + Command + L，即可立即进入休息。"
    var onTrigger: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    func register() {
        guard hotKeyRef == nil else { return }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            pauseMateHotKeyHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )
        guard installStatus == noErr else {
            statusMessage = "全局快捷键注册失败（\(installStatus)）。仍可从菜单栏选择“立即休息”。"
            return
        }

        let hotKeyID = EventHotKeyID(signature: OSType(0x504D4154), id: 1)
        let registerStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_L),
            UInt32(controlKey | optionKey | cmdKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard registerStatus == noErr else {
            if let eventHandlerRef { RemoveEventHandler(eventHandlerRef); self.eventHandlerRef = nil }
            statusMessage = "全局快捷键暂不可用（\(registerStatus)）。仍可从菜单栏选择“立即休息”。"
            return
        }
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandlerRef { RemoveEventHandler(eventHandlerRef) }
    }
}

private func pauseMateHotKeyHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let userData else { return noErr }
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr, hotKeyID.signature == OSType(0x504D4154), hotKeyID.id == 1 else { return noErr }

    let shortcut = Unmanaged<PauseBreakShortcut>.fromOpaque(userData).takeUnretainedValue()
    DispatchQueue.main.async { shortcut.onTrigger?() }
    return noErr
}

@MainActor
private final class SettingsModel: ObservableObject {
    @Published var interval: Int
    @Published var mediaURL: URL?
    @Published var launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
    @Published var launchAtLoginMessage: String?

    init(interval: Int, mediaURL: URL?) {
        self.interval = interval
        self.mediaURL = mediaURL
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            let status = SMAppService.mainApp.status
            launchAtLoginEnabled = status == .enabled
            launchAtLoginMessage = status == .requiresApproval
                ? "请在“系统设置 → 通用 → 登录项”中允许 PauseMate 登录时启动。"
                : nil
        } catch {
            launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
            launchAtLoginMessage = "无法更新登录启动设置：\(error.localizedDescription)"
        }
    }
}
