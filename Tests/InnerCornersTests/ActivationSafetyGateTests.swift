import XCTest
@testable import InnerCorners

final class ActivationSafetyGateTests: XCTestCase {
    func testSuspendedGateAlwaysBypasses() {
        var gate = ActivationSafetyGate()
        gate.suspend()

        XCTAssertEqual(gate.decision(now: 100, isOutsideActivationZone: true), .bypassing)
    }

    func testRearmRequiresDeadlineAndPointerOutsideEveryZone() {
        var gate = ActivationSafetyGate()
        gate.suspend()
        gate.prepareForRearm(now: 100, delay: 5)

        XCTAssertEqual(gate.decision(now: 104.99, isOutsideActivationZone: true), .bypassing)
        XCTAssertEqual(gate.decision(now: 105, isOutsideActivationZone: false), .bypassing)
        XCTAssertEqual(gate.decision(now: 105, isOutsideActivationZone: true), .rearmed)
        XCTAssertEqual(gate.decision(now: 105, isOutsideActivationZone: true), .active)
    }

    func testRepeatedPrepareExtendsExistingDeadline() {
        var gate = ActivationSafetyGate()
        gate.prepareForRearm(now: 100, delay: 5)
        gate.prepareForRearm(now: 103, delay: 5)

        XCTAssertEqual(gate.decision(now: 105, isOutsideActivationZone: true), .bypassing)
        XCTAssertEqual(gate.decision(now: 108, isOutsideActivationZone: true), .rearmed)
    }
}
