import XCTest
@testable import InnerCorners

final class SystemHotCornerActionTests: XCTestCase {
    func testKnownDockValues() {
        XCTAssertEqual(SystemHotCornerAction(dockValue: 0), .none)
        XCTAssertEqual(SystemHotCornerAction(dockValue: 2), .missionControl)
        XCTAssertEqual(SystemHotCornerAction(dockValue: 3), .applicationWindows)
        XCTAssertEqual(SystemHotCornerAction(dockValue: 4), .showDesktop)
        XCTAssertEqual(SystemHotCornerAction(dockValue: 5), .startScreenSaver)
        XCTAssertEqual(SystemHotCornerAction(dockValue: 6), .disableScreenSaver)
        XCTAssertEqual(SystemHotCornerAction(dockValue: 10), .putDisplayToSleep)
        XCTAssertEqual(SystemHotCornerAction(dockValue: 11), .apps)
        XCTAssertEqual(SystemHotCornerAction(dockValue: 12), .notificationCenter)
        XCTAssertEqual(SystemHotCornerAction(dockValue: 13), .lockScreen)
        XCTAssertEqual(SystemHotCornerAction(dockValue: 14), .quickNote)
    }

    func testUnknownDockValueIsPreserved() {
        XCTAssertEqual(SystemHotCornerAction(dockValue: 999), .unknown(999))
    }

    func testKnownUnsupportedActionHasSpecificLocalizedTitle() {
        XCTAssertEqual(
            SystemHotCornerAction(dockValue: 14).title(language: .japanese),
            "クイックメモ"
        )
        XCTAssertEqual(
            SystemHotCornerAction(dockValue: 12).title(language: .english),
            "Notification Center"
        )
    }
}
