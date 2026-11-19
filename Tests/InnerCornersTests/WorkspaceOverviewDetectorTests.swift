import XCTest
@testable import InnerCorners

final class WorkspaceOverviewDetectorTests: XCTestCase {
    func testRecognizesObservedMissionControlAndShowDesktopWindows() {
        XCTAssertTrue(WorkspaceOverviewDetector.isOverviewWindow(.init(
            owner: "WindowManager",
            name: "ExposeShieldWindow",
            layer: 19
        )))
        XCTAssertTrue(WorkspaceOverviewDetector.isOverviewWindow(.init(
            owner: "WindowManager",
            name: "ShowDesktopOverlay",
            layer: 18
        )))
    }

    func testRejectsNormalAndLookalikeWindows() {
        XCTAssertFalse(WorkspaceOverviewDetector.isOverviewWindow(.init(
            owner: "Other App",
            name: "ExposeShieldWindow",
            layer: 19
        )))
        XCTAssertFalse(WorkspaceOverviewDetector.isOverviewWindow(.init(
            owner: "WindowManager",
            name: "Material Label Window",
            layer: 0
        )))
        XCTAssertFalse(WorkspaceOverviewDetector.isOverviewWindow(.init(
            owner: "WindowManager",
            name: "ShowDesktopOverlay",
            layer: 0
        )))
    }
}
