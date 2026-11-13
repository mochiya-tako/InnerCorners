import XCTest
@testable import InnerCorners

final class BarrierSafetyGateTests: XCTestCase {
    func testWakeRequiresBothDelayAndSafePosition() {
        var gate = BarrierSafetyGate()
        gate.requireSafeRearm(now: 100, delay: 5)

        XCTAssertEqual(gate.decision(now: 104.9, isSafePosition: true), .bypassing)
        XCTAssertEqual(gate.decision(now: 105, isSafePosition: false), .bypassing)
        XCTAssertEqual(gate.decision(now: 105, isSafePosition: true), .rearmed)
    }

    func testSecondWakeExtendsDelay() {
        var gate = BarrierSafetyGate()
        gate.requireSafeRearm(now: 100, delay: 5)
        gate.requireSafeRearm(now: 103, delay: 5)

        XCTAssertEqual(gate.decision(now: 105, isSafePosition: true), .bypassing)
        XCTAssertEqual(gate.decision(now: 108, isSafePosition: true), .rearmed)
    }
}
