import CoreGraphics
import Foundation

struct BarrierPreviewSegment: Identifiable, Equatable {
    let id: String
    let displayPersistentID: String
    let displayNumber: UInt32
    let corner: Corner
    let axis: BarrierAxis
    let policy: CornerBarrierPolicy
    /// Segment rectangle in AppKit screen coordinates (`NSScreen.frame`).
    let rect: CGRect
}

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
            displays.map { ($0.displayNumber, $0.id) },
            uniquingKeysWith: { first, _ in first }
        )
        return Set(barriers.compactMap { barrier in
            persistentIDByDisplayNumber[barrier.displayID].map {
                "\($0):\(barrier.corner.rawValue)"
            }
        })
    }

    static func disabledQuartzCornerKeys(
        displays: [DisplayDescriptor],
        preferences: Preferences
    ) -> Set<String> {
        var result: Set<String> = []
        for display in displays {
            for corner in Corner.allCases {
                if preferences.barrierPolicy(displayID: display.id, corner: corner) == .disabled {
                    result.insert("\(display.displayNumber):\(corner.rawValue)")
                }
            }
        }
        return result
    }

    static func previewSegments(
        displays: [DisplayDescriptor],
        allBarriers: [CursorBarrier],
        length requestedLength: CGFloat,
        preferences: Preferences
    ) -> [BarrierPreviewSegment] {
        let displayByNumber = Dictionary(
            displays.map { ($0.displayNumber, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let length = min(max(requestedLength, 10), 100)
        let thickness: CGFloat = 14

        return allBarriers.compactMap { barrier in
            guard let display = displayByNumber[barrier.displayID] else { return nil }
            let f = display.frame
            let clampedLen = min(length, f.width / 2, f.height / 2)
            let policy = preferences.barrierPolicy(displayID: display.id, corner: barrier.corner)

            let rect: CGRect
            switch (barrier.corner, barrier.axis) {
            case (.topLeft, .vertical):
                rect = CGRect(x: f.minX, y: f.maxY - clampedLen, width: thickness, height: clampedLen)
            case (.topLeft, .horizontal):
                rect = CGRect(x: f.minX, y: f.maxY - thickness, width: clampedLen, height: thickness)
            case (.topRight, .vertical):
                rect = CGRect(x: f.maxX - thickness, y: f.maxY - clampedLen, width: thickness, height: clampedLen)
            case (.topRight, .horizontal):
                rect = CGRect(x: f.maxX - clampedLen, y: f.maxY - thickness, width: clampedLen, height: thickness)
            case (.bottomLeft, .vertical):
                rect = CGRect(x: f.minX, y: f.minY, width: thickness, height: clampedLen)
            case (.bottomLeft, .horizontal):
                rect = CGRect(x: f.minX, y: f.minY, width: clampedLen, height: thickness)
            case (.bottomRight, .vertical):
                rect = CGRect(x: f.maxX - thickness, y: f.minY, width: thickness, height: clampedLen)
            case (.bottomRight, .horizontal):
                rect = CGRect(x: f.maxX - clampedLen, y: f.minY, width: clampedLen, height: thickness)
            }
            return BarrierPreviewSegment(
                id: barrier.id,
                displayPersistentID: display.id,
                displayNumber: display.displayNumber,
                corner: barrier.corner,
                axis: barrier.axis,
                policy: policy,
                rect: rect
            )
        }
    }

    static func shouldExecuteCustomAction(
        _ action: CornerAction,
        zoneID: String,
        internalZoneIDs: Set<String>
    ) -> Bool {
        action != .systemHotCorner || internalZoneIDs.contains(zoneID)
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

    static func contains(_ point: CGPoint, in rect: CGRect) -> Bool {
        point.x >= rect.minX && point.x < rect.maxX && point.y >= rect.minY && point.y < rect.maxY
    }

    static func zone(at point: CGPoint, zones: [HotZone]) -> HotZone? {
        zones.first { contains(point, in: $0.rect) }
    }
}
