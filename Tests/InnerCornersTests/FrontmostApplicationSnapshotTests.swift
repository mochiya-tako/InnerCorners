import XCTest
@testable import InnerCorners

final class FrontmostApplicationSnapshotTests: XCTestCase {
    func testActivationNotificationWinsOverStaleWorkspaceQuery() {
        let finder = FrontmostApplicationSnapshot(
            localizedName: "Finder",
            bundleIdentifier: "com.apple.finder",
            processIdentifier: 100
        )
        let stale = FrontmostApplicationSnapshot(
            localizedName: "InnerCorners GE",
            bundleIdentifier: "local.prototype.InnerCorners.GE",
            processIdentifier: 200
        )

        XCTAssertEqual(
            FrontmostApplicationSnapshot.resolved(
                activationNotification: finder,
                currentQuery: stale
            ),
            finder
        )
    }

    func testCurrentQueryIsUsedWithoutActivationNotification() {
        let current = FrontmostApplicationSnapshot(
            localizedName: "TextEdit",
            bundleIdentifier: "com.apple.TextEdit",
            processIdentifier: 300
        )

        XCTAssertEqual(
            FrontmostApplicationSnapshot.resolved(
                activationNotification: nil,
                currentQuery: current
            ),
            current
        )
    }
}
