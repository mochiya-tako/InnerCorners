import CoreGraphics
import XCTest
@testable import InnerCorners

final class ActionExecutorResultTests: XCTestCase {
    func testApplicationWindowsIsSuppressedOnlyWhenInnerCornersIsFrontmost() {
        XCTAssertTrue(ActionExecutor.shouldSuppressApplicationWindows(
            frontmostProcessIdentifier: 42,
            currentProcessIdentifier: 42
        ))
        XCTAssertFalse(ActionExecutor.shouldSuppressApplicationWindows(
            frontmostProcessIdentifier: 7,
            currentProcessIdentifier: 42
        ))
        XCTAssertFalse(ActionExecutor.shouldSuppressApplicationWindows(
            frontmostProcessIdentifier: nil,
            currentProcessIdentifier: 42
        ))
    }

    func testPermissionCapabilitiesKeepAccessibilityAndEventPostingIndependent() {
        let accessibilityOnly = ActionExecutor.PermissionCapabilities(
            accessibilityAPI: true,
            eventPosting: false
        )
        XCTAssertTrue(accessibilityOnly.accessibilityAPI)
        XCTAssertFalse(accessibilityOnly.eventPosting)

        let eventPostingOnly = ActionExecutor.PermissionCapabilities(
            accessibilityAPI: false,
            eventPosting: true
        )
        XCTAssertFalse(eventPostingOnly.accessibilityAPI)
        XCTAssertTrue(eventPostingOnly.eventPosting)
    }

    func testObservedModifierFlagsTakePrecedenceOverLaterGlobalState() {
        XCTAssertEqual(
            ActionExecutor.resolvedModifierFlags(
                observedAtTrigger: .maskCommand,
                current: .maskControl
            ),
            .maskCommand
        )
        XCTAssertEqual(
            ActionExecutor.resolvedModifierFlags(
                observedAtTrigger: nil,
                current: .maskControl
            ),
            .maskControl
        )
    }


    func testStableDiagnosticCodesDoNotIncludeFailureReasons() {
        XCTAssertEqual(ActionExecutor.Result.performed.diagnosticCode, "performed")
        XCTAssertEqual(ActionExecutor.Result.requested.diagnosticCode, "requested")
        XCTAssertEqual(ActionExecutor.Result.permissionRequired.diagnosticCode, "permission-required")
        XCTAssertEqual(ActionExecutor.Result.unsupported("private detail").diagnosticCode, "unsupported")
        XCTAssertEqual(ActionExecutor.Result.failed("private detail").diagnosticCode, "failed")
        XCTAssertEqual(ActionExecutor.Result.skipped("private detail").diagnosticCode, "skipped")
    }

    func testAsyncCompletionUsesStableNonSensitiveDiagnosticCodes() {
        let success = ActionExecutor.AsyncCompletion(
            operation: .applicationLaunch,
            succeeded: true,
            diagnosticCode: "completed"
        )
        let failure = ActionExecutor.AsyncCompletion(
            operation: .systemCommand,
            succeeded: false,
            diagnosticCode: "exit-nonzero"
        )

        XCTAssertEqual(success.operation.rawValue, "application-launch")
        XCTAssertEqual(success.diagnosticCode, "completed")
        XCTAssertEqual(failure.operation.rawValue, "system-command")
        XCTAssertEqual(failure.diagnosticCode, "exit-nonzero")
    }
}
