import XCTest
@testable import InnerCorners

final class PreferencesTests: XCTestCase {
    func testLegacyPreferencesDefaultToJapanese() throws {
        let data = Data(#"{"isEnabled":true,"assignments":[]}"#.utf8)
        let preferences = try JSONDecoder().decode(Preferences.self, from: data)
        XCTAssertEqual(preferences.appLanguage, .japanese)
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
}
