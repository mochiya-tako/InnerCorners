import CoreGraphics
import Foundation

enum HotZoneGeometry {
    static func zones(for displays: [DisplayDescriptor], size requestedSize: CGFloat) -> [HotZone] {
        displays.flatMap { display in
            let size = min(max(requestedSize, 10), 100, display.frame.width, display.frame.height)
            let f = display.frame
            return [
                HotZone(displayID: display.id, displayName: display.name, corner: .topLeft,
                        rect: CGRect(x: f.minX, y: f.maxY - size, width: size, height: size)),
                HotZone(displayID: display.id, displayName: display.name, corner: .topRight,
                        rect: CGRect(x: f.maxX - size, y: f.maxY - size, width: size, height: size)),
                HotZone(displayID: display.id, displayName: display.name, corner: .bottomLeft,
                        rect: CGRect(x: f.minX, y: f.minY, width: size, height: size)),
                HotZone(displayID: display.id, displayName: display.name, corner: .bottomRight,
                        rect: CGRect(x: f.maxX - size, y: f.minY, width: size, height: size))
            ]
        }
    }

    /// Half-open containment ([min, max)) makes two abutting displays deterministic.
    /// The seam belongs to the display whose minimum edge starts at that coordinate.
    static func contains(_ point: CGPoint, in rect: CGRect) -> Bool {
        point.x >= rect.minX && point.x < rect.maxX && point.y >= rect.minY && point.y < rect.maxY
    }

    static func zone(at point: CGPoint, zones: [HotZone]) -> HotZone? {
        zones.first { contains(point, in: $0.rect) }
    }
}
