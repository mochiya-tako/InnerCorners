import CoreGraphics
import XCTest
@testable import InnerCorners

final class SpeedBumpGateTests: XCTestCase {
    private let ownerFrame = CGRect(x: 0, y: 0, width: 2560, height: 1080)

    private var topLeftBarrier: CursorBarrier {
        CursorBarrier(
            id: "1:topLeft:left",
            displayID: 1,
            corner: .topLeft,
            axis: .vertical,
            coordinate: 0,
            span: -40...40,
            ownerSide: .higherCoordinate,
            ownerFrame: ownerFrame
        )
    }

    func testAlwaysBlockModeNeverOpens() {
        var gate = SpeedBumpGate()
        XCTAssertEqual(
            gate.evaluateCollision(barrier: topLeftBarrier, now: 10.0, mode: .alwaysBlock, holdDuration: 0.3),
            .block
        )
        XCTAssertEqual(
            gate.evaluateCollision(barrier: topLeftBarrier, now: 10.2, mode: .alwaysBlock, holdDuration: 0.3),
            .block
        )
        XCTAssertEqual(
            gate.evaluateCollision(barrier: topLeftBarrier, now: 10.4, mode: .alwaysBlock, holdDuration: 0.3),
            .block
        )
    }

    func testSpeedBumpModeBlocksInitialPushAndOpensAfterHoldDuration() {
        var gate = SpeedBumpGate()
        XCTAssertEqual(
            gate.evaluateCollision(barrier: topLeftBarrier, now: 10.00, mode: .speedBump, holdDuration: 0.30),
            .block
        )
        XCTAssertEqual(
            gate.evaluateCollision(barrier: topLeftBarrier, now: 10.15, mode: .speedBump, holdDuration: 0.30),
            .block
        )
        XCTAssertEqual(
            gate.evaluateCollision(barrier: topLeftBarrier, now: 10.31, mode: .speedBump, holdDuration: 0.30),
            .allowPassage
        )
        // Continues allowing passage while still at the junction
        XCTAssertEqual(
            gate.evaluateCollision(barrier: topLeftBarrier, now: 10.35, mode: .speedBump, holdDuration: 0.30),
            .allowPassage
        )
    }

    func testSpeedBumpResetsAfterMovingAwayFromJunction() {
        var gate = SpeedBumpGate()
        _ = gate.evaluateCollision(barrier: topLeftBarrier, now: 10.00, mode: .speedBump, holdDuration: 0.30)
        _ = gate.evaluateCollision(barrier: topLeftBarrier, now: 10.20, mode: .speedBump, holdDuration: 0.30)
        XCTAssertEqual(
            gate.evaluateCollision(barrier: topLeftBarrier, now: 10.35, mode: .speedBump, holdDuration: 0.30),
            .allowPassage
        )

        // Move far inside the display (beyond 16pt release distance)
        gate.observeNonCollidingMovement(at: CGPoint(x: 50, y: 50), now: 10.50)

        // Next approach must block again
        XCTAssertEqual(
            gate.evaluateCollision(barrier: topLeftBarrier, now: 10.60, mode: .speedBump, holdDuration: 0.30),
            .block
        )
    }

    func testInterruptedPushResetsHoldTimer() {
        var gate = SpeedBumpGate()
        XCTAssertEqual(
            gate.evaluateCollision(barrier: topLeftBarrier, now: 10.00, mode: .speedBump, holdDuration: 0.30),
            .block
        )
        // Pause longer than maxSampleGap (0.25s)
        XCTAssertEqual(
            gate.evaluateCollision(barrier: topLeftBarrier, now: 10.40, mode: .speedBump, holdDuration: 0.30),
            .block
        )
    }
}
