import XCTest
@testable import InnerCorners

final class WorkspaceCancellationGateTests: XCTestCase {
    func testSecondCornerCancelsAndDisarmsActiveWorkspaceCandidate() {
        var gate = WorkspaceCancellationGate(maximumLifetime: 30)
        XCTAssertEqual(gate.decision(target: .apps, now: 10, overviewDetected: false), .executeAndArm)
        XCTAssertEqual(
            gate.decision(target: .showDesktop, now: 12, overviewDetected: false),
            .cancelAndDisarm(.apps)
        )
        XCTAssertEqual(gate.decision(target: .showDesktop, now: 13, overviewDetected: false), .executeAndArm)
    }

    func testClickOrApplicationActivationCanClearCandidate() {
        var gate = WorkspaceCancellationGate(maximumLifetime: 30)
        XCTAssertEqual(gate.decision(target: .missionControl, now: 10, overviewDetected: false), .executeAndArm)
        gate.clear()
        XCTAssertEqual(gate.decision(target: .showDesktop, now: 12, overviewDetected: false), .executeAndArm)
    }

    func testExpiredCandidateDoesNotCancelLaterAction() {
        var gate = WorkspaceCancellationGate(maximumLifetime: 5)
        XCTAssertEqual(gate.decision(target: .applicationWindows, now: 10, overviewDetected: false), .executeAndArm)
        XCTAssertEqual(gate.decision(target: .showDesktop, now: 16, overviewDetected: false), .executeAndArm)
    }

    func testObservedOverviewCancelsEvenWithoutPriorTrigger() {
        var gate = WorkspaceCancellationGate()
        XCTAssertEqual(
            gate.decision(target: .showDesktop, now: 10, overviewDetected: true),
            .cancelAndDisarm(nil)
        )
    }
}
