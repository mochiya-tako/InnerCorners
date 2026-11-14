import CoreGraphics
import Foundation

enum HotZoneGeometry {
    static func sameDisplayConfiguration(
        _ lhs: [DisplayDescriptor],
        _ rhs: [DisplayDescriptor]
    ) -> Bool {
        guard lhs.count == rhs.count else { return false }
        return lhs.allSatisfy { display in
            rhs.contains { $0.id == display.id && $0.frame == display.frame }
        }
    }

    static func zoneIDsCoveredByBarriers(
        displays: [DisplayDescriptor],
        barriers: [CursorBarrier]
    ) -> Set<String> {
        let persistentIDByDisplayNumber = Dictionary(
            uniqueKeysWithValues: displays.map { ($0.displayNumber, $0.id) }
        )
        return Set(barriers.compactMap { barrier in
            persistentIDByDisplayNumber[barrier.displayID].map {
                "\($0):\(barrier.corner.rawValue)"
            }
        })
    }

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
