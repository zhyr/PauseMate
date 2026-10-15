import AppKit
import AVKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class OverlayManager {
    private var windows: [NSWindow] = []
    private var mediaURL: URL?

    func setMedia(_ url: URL?) { mediaURL = url }

    func show(engine: TimerEngine, end: @escaping () -> Void) {
        hide()
        for screen in NSScreen.screens {
            let panel = BreakPanel(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            panel.level = .screenSaver
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            panel.isOpaque = true
            panel.backgroundColor = NSColor(calibratedRed: 0.035, green: 0.12, blue: 0.17, alpha: 1)
            panel.ignoresMouseEvents = false
            panel.hidesOnDeactivate = false
            panel.isMovable = false
            let pixelWidth = screen.frame.width * screen.backingScaleFactor
            let pixelHeight = screen.frame.height * screen.backingScaleFactor
            let backgroundName = max(pixelWidth, pixelHeight) >= 3000
                ? "DefaultBreakBackground4K"
                : "DefaultBreakBackground2K"
            panel.contentView = NSHostingView(rootView: BreakView(mediaURL: mediaURL, backgroundName: backgroundName, engine: engine, end: end))
            panel.setFrame(screen.frame, display: true)
            windows.append(panel)
            panel.makeKeyAndOrderFront(nil)
        }
    }

    func hide() {
        windows.forEach { $0.orderOut(nil); $0.close() }
        windows.removeAll()
    }
}

private final class BreakPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private struct BreakView: View {
    let mediaURL: URL?
    let backgroundName: String
    @ObservedObject var engine: TimerEngine
    let end: () -> Void

    var body: some View {
        ZStack {
            Color(red: 0.035, green: 0.12, blue: 0.17).ignoresSafeArea()
            if let url = mediaURL, isVideo(url) {
                VideoBackground(url: url).ignoresSafeArea().overlay(Color.black.opacity(0.30))
            } else if let url = mediaURL, let image = NSImage(contentsOf: url) {
                Image(nsImage: image).resizable().scaledToFill().ignoresSafeArea().overlay(Color.black.opacity(0.36))
            } else {
                Image(backgroundName)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .overlay(Color.black.opacity(0.36))
            }
            VStack(spacing: 24) {
                BrandMark().frame(width: 92, height: 92)
                Text("PauseMate").font(.system(size: 20, weight: .semibold, design: .rounded)).tracking(1.2).foregroundStyle(Color(red: 0.47, green: 0.88, blue: 0.74))
                Text("Take a Break. Be Healthier.").font(.system(size: 15, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.72))
                Text("站起来，舒展一下").font(.system(size: 36, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Text("看看远处，活动肩颈与双腿，让身体重新充满活力。\n休息结束后，点击下方按钮继续。").font(.system(size: 17)).multilineTextAlignment(.center).lineSpacing(7).foregroundStyle(.white.opacity(0.78))
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(timeString(countdown(at: context.date))).font(.system(size: 72, weight: .light, design: .rounded).monospacedDigit()).foregroundStyle(.white)
                }
                Button(action: end) { Label("休息完成，继续工作", systemImage: "checkmark.circle.fill").font(.system(size: 16, weight: .semibold)).padding(.horizontal, 24).padding(.vertical, 14) }
                    .buttonStyle(.plain).foregroundStyle(Color(red: 0.04, green: 0.15, blue: 0.18)).background(Color(red: 0.49, green: 0.88, blue: 0.75), in: Capsule())
                Text("按 Control + Option + Escape 可紧急关闭遮罩").font(.system(size: 12)).foregroundStyle(.white.opacity(0.45))
            }.padding(36)
        }.frame(maxWidth: .infinity, maxHeight: .infinity).background(EmergencyKeyHandler(end: end))
    }

    private func isVideo(_ url: URL) -> Bool { ["mov", "mp4", "m4v"].contains(url.pathExtension.lowercased()) }
    private func timeString(_ time: TimeInterval) -> String { let s = max(0, Int(ceil(time))); return String(format: "%02d:%02d", s / 60, s % 60) }
    private func countdown(at date: Date) -> TimeInterval {
        if case let .breakActive(endsAt) = engine.state { return max(0, endsAt.timeIntervalSince(date)) }
        return engine.remaining
    }
}

private struct VideoBackground: View {
    let player: AVPlayer
    init(url: URL) { player = AVPlayer(url: url) }
    var body: some View { VideoPlayer(player: player).onAppear { player.isMuted = true; player.play() }.onDisappear { player.pause() } }
}

private struct EmergencyKeyHandler: NSViewRepresentable {
    let end: () -> Void
    func makeNSView(context: Context) -> NSView { KeyView(end: end) }
    func updateNSView(_ nsView: NSView, context: Context) { (nsView as? KeyView)?.end = end }
    private final class KeyView: NSView {
        var end: () -> Void
        init(end: @escaping () -> Void) { self.end = end; super.init(frame: .zero) }
        required init?(coder: NSCoder) { nil }
        override var acceptsFirstResponder: Bool { true }
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); window?.makeFirstResponder(self) }
        override func keyDown(with event: NSEvent) {
            let emergency = event.keyCode == 53 && event.modifierFlags.contains([.control, .option])
            if emergency { end() } else { super.keyDown(with: event) }
        }
    }
}

struct BrandMark: View {
    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [Color(red: 0.13, green: 0.72, blue: 0.69), Color(red: 0.39, green: 0.84, blue: 0.60)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Image(systemName: "figure.cooldown").font(.system(size: 48, weight: .medium)).foregroundStyle(Color(red: 0.035, green: 0.12, blue: 0.17))
            Circle().trim(from: 0.06, to: 0.43).stroke(.white.opacity(0.9), style: StrokeStyle(lineWidth: 2.5, lineCap: .round)).rotationEffect(.degrees(-90)).padding(7)
        }
    }
}
