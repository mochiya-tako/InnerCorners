import CoreGraphics
import XCTest
@testable import InnerCorners

final class GeometryTests: XCTestCase {
    private let left = DisplayDescriptor(id: "left", displayNumber: 1, name: "Left", frame: CGRect(x: 0, y: 0, width: 1920, height: 1080))
    // Different heights, but aligned top edges: a common real multi-display arrangement.
    private let right = DisplayDescriptor(id: "right", displayNumber: 2, name: "Right", frame: CGRect(x: 1920, y: -360, width: 2560, height: 1440))

    func testAbuttingTopCornersAreIndependent() throws {
        let zones = HotZoneGeometry.zones(for: [left, right], size: 40)
        let leftTopRight = try XCTUnwrap(zones.first { $0.displayID == "left" && $0.corner == .topRight })
        let rightTopLeft = try XCTUnwrap(zones.first { $0.displayID == "right" && $0.corner == .topLeft })

        XCTAssertTrue(HotZoneGeometry.contains(CGPoint(x: 1919, y: 1079), in: leftTopRight.rect))
        XCTAssertFalse(HotZoneGeometry.contains(CGPoint(x: 1919, y: 1079), in: rightTopLeft.rect))
        XCTAssertTrue(HotZoneGeometry.contains(CGPoint(x: 1920, y: 1079), in: rightTopLeft.rect))
        XCTAssertFalse(HotZoneGeometry.contains(CGPoint(x: 1920, y: 1079), in: leftTopRight.rect))
    }

    func testDifferentDisplayHeightsDoNotCreateFalseOverlap() throws {
        let tallRight = DisplayDescriptor(id: "right", displayNumber: 2, name: "Right", frame: CGRect(x: 1920, y: 0, width: 2560, height: 1440))
        let zones = HotZoneGeometry.zones(for: [left, tallRight], size: 40)
        XCTAssertEqual(HotZoneGeometry.zone(at: CGPoint(x: 1921, y: 1439), zones: zones)?.displayID, "right")
        XCTAssertNil(HotZoneGeometry.zone(at: CGPoint(x: 1919, y: 1439), zones: zones))
    }

    func testSizeIsClampedToSupportedRange() throws {
        let zones = HotZoneGeometry.zones(for: [left], size: 500)
        let zone = try XCTUnwrap(zones.first)
        XCTAssertEqual(zone.rect.width, 100)
        XCTAssertEqual(zone.rect.height, 100)
    }
}
