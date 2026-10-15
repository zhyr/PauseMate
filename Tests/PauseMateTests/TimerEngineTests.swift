import XCTest
@testable import PauseMate

@MainActor
final class TimerEngineTests: XCTestCase {
    func testDefaultBreakDurationAndStoppedState() {
        let engine = TimerEngine()
        XCTAssertEqual(engine.breakDuration, 60)
        XCTAssertEqual(engine.state, .stopped)
    }

    func testStartingUsesRequestedInterval() {
        let engine = TimerEngine()
        engine.start(intervalMinutes: 30)
        guard case let .running(deadline) = engine.state else { return XCTFail("Expected running state") }
        XCTAssertEqual(deadline.timeIntervalSinceNow, 1800, accuracy: 1)
        engine.stop()
    }

    func testPauseAndResumePreserveRemainingTime() {
        let engine = TimerEngine()
        engine.start(intervalMinutes: 45)
        engine.pause()
        guard case let .paused(remaining) = engine.state else { return XCTFail("Expected paused state") }
        XCTAssertEqual(remaining, 2700, accuracy: 1)
        engine.resume()
        guard case let .running(deadline) = engine.state else { return XCTFail("Expected running state") }
        XCTAssertEqual(deadline.timeIntervalSinceNow, remaining, accuracy: 1)
        engine.stop()
    }
}
