import CoreGraphics
import XCTest
@testable import InnerCorners

final class SystemHotCornerModifierTests: XCTestCase {
    func testKnownFlagsAreDecoded() {
        let requirement = SystemHotCornerModifier(
            dockValue: Int(CGEventFlags([.maskShift, .maskCommand]).rawValue)
        )
        XCTAssertEqual(requirement.eventFlags, [.maskShift, .maskCommand])
        XCTAssertFalse(requirement.hasUnknownBits)
        XCTAssertEqual(requirement.symbols(language: .japanese), "⇧⌘")
    }

    func testRequirementMatchesWithAdditionalKnownFlags() {
        let requirement = SystemHotCornerModifier(
            dockValue: Int(CGEventFlags.maskControl.rawValue)
        )
        XCTAssertTrue(requirement.matches(current: [.maskControl]))
        XCTAssertTrue(requirement.matches(current: [.maskControl, .maskCommand]))
        XCTAssertFalse(requirement.matches(current: [.maskCommand]))
    }

    func testOptionIsReservedForEmergencyBypass() {
        let requirement = SystemHotCornerModifier(
            dockValue: Int(CGEventFlags.maskAlternate.rawValue)
        )
        XCTAssertTrue(requirement.usesEmergencyOptionKey)
    }

    func testUnknownBitsAreRejected() {
        let requirement = SystemHotCornerModifier(dockValue: 1)
        XCTAssertTrue(requirement.hasUnknownBits)
        XCTAssertFalse(requirement.matches(current: []))
    }
}
