import CoreGraphics
import XCTest
@testable import InnerCorners

final class AppSuppressionPolicyTests: XCTestCase {
    func testCompanionAppConflictSuppressesBothBarriersAndActionsRegardlessOfScope() {
        var prefs = Preferences()
        prefs.suppressionScope = .actionsOnly

        let state = AppSuppressionPolicy.evaluate(
            now: Date(timeIntervalSince1970: 1_000),
            pausedUntil: nil,
            frontmostBundleID: nil,
            isFrontmostFullscreen: false,
            isCompanionAppRunning: true,
            preferences: prefs
        )

        XCTAssertTrue(state.isCompanionAppRunning)
        XCTAssertTrue(state.shouldSuppressActions)
        XCTAssertTrue(state.shouldSuppressBarriers)
        XCTAssertTrue(state.shouldPreserveBarrierSafetyState(whenBarrierIsEnabled: true))
        XCTAssertFalse(state.shouldPreserveBarrierSafetyState(whenBarrierIsEnabled: false))
    }

    func testTemporaryPauseSuppressesBothBarriersAndActions() {
        let now = Date(timeIntervalSince1970: 1_000)
        let deadline = Date(timeIntervalSince1970: 1_300)
        let state = AppSuppressionPolicy.evaluate(
            now: now,
            pausedUntil: deadline,
            frontmostBundleID: "com.apple.Finder",
            isFrontmostFullscreen: false,
            preferences: Preferences()
        )
        XCTAssertTrue(state.isPausedByTimer)
        XCTAssertTrue(state.shouldSuppressActions)
        XCTAssertTrue(state.shouldSuppressBarriers)
    }

    func testExcludedAppRespectsSuppressionScope() {
        let now = Date(timeIntervalSince1970: 1_000)
        var prefs = Preferences()
        prefs.excludedBundleIdentifiers = ["com.valvesoftware.steam"]
        prefs.suppressionScope = .actionsOnly

        let actionsOnlyState = AppSuppressionPolicy.evaluate(
            now: now,
            pausedUntil: nil,
            frontmostBundleID: "com.valvesoftware.steam",
            isFrontmostFullscreen: false,
            preferences: prefs
        )
        XCTAssertTrue(actionsOnlyState.isExcludedAppFrontmost)
        XCTAssertTrue(actionsOnlyState.shouldSuppressActions)
        XCTAssertFalse(actionsOnlyState.shouldSuppressBarriers)

        prefs.suppressionScope = .barriersAndActions
        let bothState = AppSuppressionPolicy.evaluate(
            now: now,
            pausedUntil: nil,
            frontmostBundleID: "com.valvesoftware.steam",
            isFrontmostFullscreen: false,
            preferences: prefs
        )
        XCTAssertTrue(bothState.shouldSuppressActions)
        XCTAssertTrue(bothState.shouldSuppressBarriers)
    }

    func testFullscreenWindowDetectionMatchesDisplayBounds() {
        let displays = [
            QuartzDisplayDescriptor(id: 1, name: "Main", frame: CGRect(x: 0, y: 0, width: 2560, height: 1080))
        ]
        XCTAssertFalse(AppSuppressionPolicy.hasFullscreenWindow(
            windowBounds: [CGRect(x: 100, y: 100, width: 1200, height: 800)],
            displays: displays
        ))
        XCTAssertTrue(AppSuppressionPolicy.hasFullscreenWindow(
            windowBounds: [CGRect(x: 0, y: 0, width: 2560, height: 1080)],
            displays: displays
        ))
    }
}
