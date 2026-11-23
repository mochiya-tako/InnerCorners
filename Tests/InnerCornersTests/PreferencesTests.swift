import CoreGraphics
import XCTest
@testable import InnerCorners

final class PreferencesTests: XCTestCase {
    func testLegacyPreferencesDefaultToJapanese() throws {
        let data = Data(#"{"isEnabled":true,"assignments":[]}"#.utf8)
        let preferences = try JSONDecoder().decode(Preferences.self, from: data)
        XCTAssertEqual(preferences.appLanguage, .japanese)
        XCTAssertEqual(preferences.passThroughMode, .alwaysBlock)
        XCTAssertEqual(preferences.speedBumpHoldMilliseconds, 300)
        XCTAssertFalse(preferences.pauseInFullscreenApps)
        XCTAssertTrue(preferences.excludedBundleIdentifiers.isEmpty)
        XCTAssertEqual(preferences.suppressionScope, .actionsOnly)
    }

    func testLanguageRoundTrips() throws {
        var preferences = Preferences()
        preferences.appLanguage = .english
        let decoded = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(preferences))
        XCTAssertEqual(decoded.appLanguage, .english)
    }

    func testAssignmentsAreIndependentByDisplayAndCorner() throws {
        var preferences = Preferences()
        preferences.setAction(.missionControl, displayID: "display-A", corner: .topRight)
        preferences.setAction(.applicationWindows, displayID: "display-B", corner: .topLeft)

        XCTAssertEqual(preferences.action(displayID: "display-A", corner: .topRight), .missionControl)
        XCTAssertEqual(preferences.action(displayID: "display-B", corner: .topLeft), .applicationWindows)
        XCTAssertEqual(preferences.action(displayID: "display-A", corner: .topLeft), .systemHotCorner)
        XCTAssertEqual(preferences.barrierAction(displayID: "display-A", corner: .topLeft), .systemHotCorner)

        let data = try JSONEncoder().encode(preferences)
        let decoded = try JSONDecoder().decode(Preferences.self, from: data)
        XCTAssertEqual(decoded.action(displayID: "display-A", corner: .topRight), .missionControl)
        XCTAssertEqual(decoded.action(displayID: "display-B", corner: .topLeft), .applicationWindows)
        XCTAssertEqual(decoded.barrierAction(displayID: "display-C", corner: .bottomRight), .systemHotCorner)
    }

    func testLegacyPersistentBarrierFieldIsIgnored() throws {
        let legacy = Data(#"{"isEnabled":false,"barrierEnabled":true,"keepBarrierAfterTrigger":false,"barrierLength":40,"zoneSize":40,"dwellMilliseconds":200,"assignments":[]}"#.utf8)
        let decoded = try JSONDecoder().decode(Preferences.self, from: legacy)

        XCTAssertTrue(decoded.barrierEnabled)
        XCTAssertEqual(decoded.barrierLength, 40)
    }

    func testNewPublicActionsRoundTripWithoutChangingLegacyAssignments() throws {
        let actions: [CornerAction] = [
            .quickNote,
            .notificationCenter,
            .lockScreen,
            .startScreenSaver,
            .putDisplayToSleep,
            .screenshotSelection,
            .screenshotPanel,
            .openApplication,
            .runShortcut
        ]

        for action in actions {
            var preferences = Preferences()
            preferences.setAction(action, displayID: "display", corner: .bottomLeft)
            let decoded = try JSONDecoder().decode(
                Preferences.self,
                from: JSONEncoder().encode(preferences)
            )
            XCTAssertEqual(decoded.action(displayID: "display", corner: .bottomLeft), action)
        }
    }

    func testGeminiCornerPolicyModifierAndPayloadsRoundTrip() throws {
        var preferences = Preferences()
        preferences.passThroughMode = .speedBump
        preferences.speedBumpHoldMilliseconds = 450
        preferences.pauseInFullscreenApps = true
        preferences.excludedBundleIdentifiers = ["com.example.game"]
        preferences.suppressionScope = .barriersAndActions
        preferences.setBarrierPolicy(.stopperOnly, displayID: "display-1", corner: .topLeft)
        preferences.setBarrierPolicy(.disabled, displayID: "display-1", corner: .bottomLeft)
        preferences.setAction(.openApplication, displayID: "display-2", corner: .topRight)
        preferences.setModifierRequirement(.command, displayID: "display-2", corner: .topRight)
        preferences.setCustomApplicationPath("/System/Applications/Calculator.app", displayID: "display-2", corner: .topRight)
        preferences.setAction(.runShortcut, displayID: "display-2", corner: .bottomRight)
        preferences.setCustomShortcutName("My Workflow", displayID: "display-2", corner: .bottomRight)

        let decoded = try JSONDecoder().decode(
            Preferences.self,
            from: JSONEncoder().encode(preferences)
        )
        XCTAssertEqual(decoded.passThroughMode, .speedBump)
        XCTAssertEqual(decoded.speedBumpHoldMilliseconds, 450)
        XCTAssertTrue(decoded.pauseInFullscreenApps)
        XCTAssertEqual(decoded.excludedBundleIdentifiers, ["com.example.game"])
        XCTAssertEqual(decoded.suppressionScope, .barriersAndActions)
        XCTAssertEqual(decoded.barrierPolicy(displayID: "display-1", corner: .topLeft), .stopperOnly)
        XCTAssertEqual(decoded.barrierPolicy(displayID: "display-1", corner: .bottomLeft), .disabled)
        XCTAssertEqual(decoded.modifierRequirement(displayID: "display-2", corner: .topRight), .command)
        XCTAssertEqual(decoded.customApplicationPath(displayID: "display-2", corner: .topRight), "/System/Applications/Calculator.app")
        XCTAssertEqual(decoded.customShortcutName(displayID: "display-2", corner: .bottomRight), "My Workflow")
        XCTAssertTrue(CornerModifierRequirement.command.matches(current: [.maskCommand, .maskShift]))
        XCTAssertFalse(CornerModifierRequirement.command.matches(current: [.maskControl]))
    }
}
