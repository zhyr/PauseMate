import Foundation

enum ScheduleState: Equatable {
    case stopped
    case running(deadline: Date)
    case paused(remaining: TimeInterval)
    case breakActive(endsAt: Date)
}

@MainActor
final class TimerEngine: ObservableObject {
    @Published private(set) var state: ScheduleState = .stopped
    @Published private(set) var remaining: TimeInterval = 0
    @Published private(set) var completedBreaks = 0

    let breakDuration: TimeInterval = 60
    private var interval: TimeInterval = 45 * 60
    private var timer: Timer?
    var onBreakStart: (() -> Void)?
    var onBreakEnd: (() -> Void)?

    func start(intervalMinutes: Int) {
        interval = TimeInterval(intervalMinutes * 60)
        schedule(after: interval)
    }

    func pause() {
        guard case let .running(deadline) = state else { return }
        state = .paused(remaining: max(0, deadline.timeIntervalSinceNow))
        timer?.invalidate()
        timer = nil
    }

    func resume() {
        guard case let .paused(seconds) = state else { return }
        schedule(after: seconds > 0 ? seconds : interval)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        state = .stopped
        remaining = 0
        onBreakEnd?()
    }

    func triggerBreak() {
        guard case .breakActive = state else { beginBreak(); return }
    }

    func endBreak() {
        guard case .breakActive = state else { return }
        timer?.invalidate()
        timer = nil
        completedBreaks += 1
        onBreakEnd?()
        schedule(after: interval)
    }

    private func schedule(after seconds: TimeInterval) {
        timer?.invalidate()
        let deadline = Date().addingTimeInterval(seconds)
        state = .running(deadline: deadline)
        arm(deadline: deadline) { [weak self] in self?.beginBreak() }
    }

    private func beginBreak() {
        timer?.invalidate()
        timer = nil
        let deadline = Date().addingTimeInterval(breakDuration)
        state = .breakActive(endsAt: deadline)
        onBreakStart?()
        arm(deadline: deadline) { [weak self] in self?.endBreak() }
    }

    private func arm(deadline: Date, action: @escaping () -> Void) {
        func tick() {
            let left = deadline.timeIntervalSinceNow
            self.remaining = max(0, left)
            if left <= 0 { self.timer?.invalidate(); self.timer = nil; action() }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in
            Task { @MainActor in tick() }
        }
        tick()
    }
}
