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

    func testStableDiagnosticCodesDoNotIncludeFailureReasons() {
        XCTAssertEqual(ActionExecutor.Result.performed.diagnosticCode, "performed")
        XCTAssertEqual(ActionExecutor.Result.requested.diagnosticCode, "requested")
        XCTAssertEqual(ActionExecutor.Result.permissionRequired.diagnosticCode, "permission-required")
        XCTAssertEqual(ActionExecutor.Result.unsupported("private detail").diagnosticCode, "unsupported")
        XCTAssertEqual(ActionExecutor.Result.failed("private detail").diagnosticCode, "failed")
        XCTAssertEqual(ActionExecutor.Result.skipped("private detail").diagnosticCode, "skipped")
    }
}
