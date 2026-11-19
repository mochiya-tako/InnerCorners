import XCTest
@testable import InnerCorners

final class DisplayConfigurationGateTests: XCTestCase {
    func testInvalidConfigurationStaysInvalidUntilUsableGeometryIsAccepted() {
        var gate = DisplayConfigurationGate()
        XCTAssertFalse(gate.isValid)

        gate.acceptUsableConfiguration()
        XCTAssertTrue(gate.isValid)

        gate.invalidate()
        XCTAssertFalse(gate.isValid)

        // Unrelated preference/UI refreshes do not mutate the gate.
        XCTAssertFalse(gate.isValid)

        gate.acceptUsableConfiguration()
        XCTAssertTrue(gate.isValid)
    }
}
