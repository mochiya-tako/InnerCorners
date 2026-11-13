import XCTest
@testable import InnerCorners

final class ActivationGateTests: XCTestCase {
    func testDwellAndLatchUntilExit() {
        var gate = ActivationGate()
        XCTAssertNil(gate.update(zoneID: "A", now: 10.0, dwell: 0.2))
        XCTAssertNil(gate.update(zoneID: "A", now: 10.19, dwell: 0.2))
        XCTAssertEqual(gate.update(zoneID: "A", now: 10.21, dwell: 0.2), "A")
        XCTAssertNil(gate.update(zoneID: "A", now: 11.0, dwell: 0.2))

        XCTAssertNil(gate.update(zoneID: nil, now: 11.1, dwell: 0.2))
        XCTAssertNil(gate.update(zoneID: "A", now: 11.2, dwell: 0.2))
        XCTAssertEqual(gate.update(zoneID: "A", now: 11.41, dwell: 0.2), "A")
    }

    func testMovingDirectlyToAnotherZoneArmsThatZone() {
        var gate = ActivationGate()
        XCTAssertEqual(gate.update(zoneID: "A", now: 1, dwell: 0), "A")
        XCTAssertEqual(gate.update(zoneID: "B", now: 2, dwell: 0), "B")
    }

    func testLeavingBeforeDwellCancelsCandidate() {
        var gate = ActivationGate()
        XCTAssertNil(gate.update(zoneID: "A", now: 1.0, dwell: 0.5))
        XCTAssertNil(gate.update(zoneID: nil, now: 1.4, dwell: 0.5))
        XCTAssertNil(gate.update(zoneID: "A", now: 1.6, dwell: 0.5))
        XCTAssertEqual(gate.update(zoneID: "A", now: 2.11, dwell: 0.5), "A")
    }
}
