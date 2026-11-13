import CoreGraphics
import XCTest
@testable import InnerCorners

final class CollisionReactivationGateTests: XCTestCase {
    private let ownerFrame = CGRect(x: 0, y: 0, width: 1000, height: 800)

    func testIntentionalExitAndReturnBypassesDuplicateGuard() {
        let barrier = makeBarrier(displayID: 1, corner: .topLeft)
        var gate = CollisionReactivationGate()
        gate.recordTrigger(barrier)

        gate.observeMovement(at: CGPoint(x: 80, y: 80), now: 10.00, stableDisplayID: 1)
        gate.observeMovement(at: CGPoint(x: 90, y: 90), now: 10.05, stableDisplayID: 1)
        gate.observeMovement(at: CGPoint(x: 20, y: 20), now: 10.10, stableDisplayID: 1)

        XCTAssertTrue(gate.consumeReactivation(for: barrier))
        XCTAssertFalse(gate.consumeReactivation(for: barrier), "A re-entry is consumed only once")
    }

    func testSingleTransitionJumpDoesNotArmCancellation() {
        let barrier = makeBarrier(displayID: 1, corner: .topLeft)
        var gate = CollisionReactivationGate()
        gate.recordTrigger(barrier)

        gate.observeMovement(at: CGPoint(x: 200, y: 200), now: 20.00, stableDisplayID: 1)

        XCTAssertFalse(gate.consumeReactivation(for: barrier))
    }

    func testExitMustBeInsideTheOwningDisplay() {
        let barrier = makeBarrier(displayID: 1, corner: .topLeft)
        var gate = CollisionReactivationGate()
        gate.recordTrigger(barrier)

        gate.observeMovement(at: CGPoint(x: -80, y: 80), now: 30.00, stableDisplayID: 2)
        gate.observeMovement(at: CGPoint(x: -90, y: 90), now: 30.10, stableDisplayID: 2)

        XCTAssertFalse(gate.consumeReactivation(for: barrier))
    }

    func testDifferentJunctionDoesNotBecomeCancellation() {
        let first = makeBarrier(displayID: 1, corner: .topLeft)
        let other = makeBarrier(displayID: 1, corner: .bottomLeft)
        var gate = CollisionReactivationGate()
        gate.recordTrigger(first)
        gate.observeMovement(at: CGPoint(x: 80, y: 80), now: 40.00, stableDisplayID: 1)
        gate.observeMovement(at: CGPoint(x: 90, y: 90), now: 40.05, stableDisplayID: 1)

        XCTAssertFalse(gate.consumeReactivation(for: other))
    }

    private func makeBarrier(displayID: UInt32, corner: Corner) -> CursorBarrier {
        let y: CGFloat = corner == .topLeft ? 0 : ownerFrame.maxY
        return CursorBarrier(
            id: "\(displayID):\(corner.rawValue)",
            displayID: displayID,
            corner: corner,
            axis: .vertical,
            coordinate: 0,
            span: (y - 40)...(y + 40),
            ownerSide: .higherCoordinate,
            ownerFrame: ownerFrame
        )
    }
}
