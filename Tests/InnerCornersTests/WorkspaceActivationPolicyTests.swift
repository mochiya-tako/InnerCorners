import XCTest
@testable import InnerCorners

final class WorkspaceActivationPolicyTests: XCTestCase {
    func testWorkspaceUIActivationPreservesCancellationState() {
        for bundleIdentifier in [
            "com.apple.apps.launcher",
            "com.apple.launchpad.launcher",
            "com.apple.exposelauncher",
            "com.apple.dock"
        ] {
            XCTAssertFalse(
                WorkspaceActivationPolicy.shouldClearCancellationState(
                    activatedBundleIdentifier: bundleIdentifier
                ),
                bundleIdentifier
            )
        }
    }

    func testNormalApplicationActivationClearsCancellationState() {
        XCTAssertTrue(
            WorkspaceActivationPolicy.shouldClearCancellationState(
                activatedBundleIdentifier: "com.apple.TextEdit"
            )
        )
    }

    func testMissingApplicationIdentityClearsConservatively() {
        XCTAssertTrue(
            WorkspaceActivationPolicy.shouldClearCancellationState(
                activatedBundleIdentifier: nil
            )
        )
    }
}
