import CoreGraphics
import Foundation

struct QuartzDisplayDescriptor: Identifiable, Hashable {
    let id: UInt32
    let name: String
    let frame: CGRect
}

enum BarrierAxis: Hashable {
    case vertical
    case horizontal
}

enum BarrierOwnerSide: Hashable {
    case lowerCoordinate
    case higherCoordinate
}

struct CursorBarrier: Identifiable, Hashable {
    let id: String
    let displayID: UInt32
    let corner: Corner
    let axis: BarrierAxis
    let coordinate: CGFloat
    let span: ClosedRange<CGFloat>
    let ownerSide: BarrierOwnerSide
    let ownerFrame: CGRect
}

struct CursorBarrierCollision: Equatable {
    let point: CGPoint
    let barrier: CursorBarrier
}

enum CursorBarrierGeometry {
    static func sameDisplayConfiguration(
        _ lhs: [QuartzDisplayDescriptor],
        _ rhs: [QuartzDisplayDescriptor],
        tolerance: CGFloat = 0.5
    ) -> Bool {
        guard lhs.count == rhs.count else { return false }
        let left = lhs.sorted { $0.id < $1.id }
        let right = rhs.sorted { $0.id < $1.id }
        return zip(left, right).allSatisfy { a, b in
            a.id == b.id &&
            abs(a.frame.minX - b.frame.minX) <= tolerance &&
            abs(a.frame.minY - b.frame.minY) <= tolerance &&
            abs(a.frame.width - b.frame.width) <= tolerance &&
            abs(a.frame.height - b.frame.height) <= tolerance
        }
    }

    static func isSafeRearmPosition(
        _ point: CGPoint,
        displays: [QuartzDisplayDescriptor],
        barriers: [CursorBarrier],
        margin: CGFloat = 12
    ) -> Bool {
        guard stableDisplayID(at: point, displays: displays, barriers: barriers, clearance: margin) != nil else {
            return false
        }
        return barriers.allSatisfy { barrier in
            shouldReleaseLatch(at: point, barrier: barrier, distance: margin)
        }
    }

    static func stableDisplayID(
        at point: CGPoint,
        displays: [QuartzDisplayDescriptor],
        barriers: [CursorBarrier],
        clearance: CGFloat = 4
    ) -> UInt32? {
        guard let display = displays.first(where: { containsHalfOpen($0.frame, point) }) else { return nil }
        let nearSharedEdge = barriers.contains { barrier in
            switch barrier.axis {
            case .vertical:
                return abs(point.x - barrier.coordinate) <= clearance && barrier.span.contains(point.y)
            case .horizontal:
                return abs(point.y - barrier.coordinate) <= clearance && barrier.span.contains(point.x)
            }
        }
        return nearSharedEdge ? nil : display.id
    }

    static func shouldReleaseLatch(at point: CGPoint, barrier: CursorBarrier, distance: CGFloat = 8) -> Bool {
        let junction = junctionPoint(of: barrier)
        // Action re-arming and physical wall length are separate concepts.
        // Requiring a retreat by the full 10...100 pt wall length makes a
        // quick leave-and-return remain latched even though the pointer has
        // clearly left the corner.  The wall stays active over its configured
        // span; only the action latch uses this small junction distance.
        return abs(point.x - junction.x) > distance || abs(point.y - junction.y) > distance
    }

    static func barriers(for displays: [QuartzDisplayDescriptor], length requestedLength: CGFloat) -> [CursorBarrier] {
        let length = min(max(requestedLength, 10), 100)
        var result: [CursorBarrier] = []

        for display in displays {
            let f = display.frame
            let probe: CGFloat = 1

            if hasNeighbor(displays, excluding: display.id, acrossX: f.minX, y: f.minY + probe, onLowerSide: true) {
                result.append(vertical(display, .topLeft, x: f.minX, span: (f.minY - length)...(f.minY + length), owner: .higherCoordinate, edge: "left"))
            }
            if hasNeighbor(displays, excluding: display.id, acrossX: f.minX, y: f.maxY - probe, onLowerSide: true) {
                result.append(vertical(display, .bottomLeft, x: f.minX, span: (f.maxY - length)...(f.maxY + length), owner: .higherCoordinate, edge: "left"))
            }
            if hasNeighbor(displays, excluding: display.id, acrossX: f.maxX, y: f.minY + probe, onLowerSide: false) {
                result.append(vertical(display, .topRight, x: f.maxX, span: (f.minY - length)...(f.minY + length), owner: .lowerCoordinate, edge: "right"))
            }
            if hasNeighbor(displays, excluding: display.id, acrossX: f.maxX, y: f.maxY - probe, onLowerSide: false) {
                result.append(vertical(display, .bottomRight, x: f.maxX, span: (f.maxY - length)...(f.maxY + length), owner: .lowerCoordinate, edge: "right"))
            }

            if hasNeighbor(displays, excluding: display.id, acrossY: f.minY, x: f.minX + probe, onLowerSide: true) {
                result.append(horizontal(display, .topLeft, y: f.minY, span: (f.minX - length)...(f.minX + length), owner: .higherCoordinate, edge: "top"))
            }
            if hasNeighbor(displays, excluding: display.id, acrossY: f.minY, x: f.maxX - probe, onLowerSide: true) {
                result.append(horizontal(display, .topRight, y: f.minY, span: (f.maxX - length)...(f.maxX + length), owner: .higherCoordinate, edge: "top"))
            }
            if hasNeighbor(displays, excluding: display.id, acrossY: f.maxY, x: f.minX + probe, onLowerSide: false) {
                result.append(horizontal(display, .bottomLeft, y: f.maxY, span: (f.minX - length)...(f.minX + length), owner: .lowerCoordinate, edge: "bottom"))
            }
            if hasNeighbor(displays, excluding: display.id, acrossY: f.maxY, x: f.maxX - probe, onLowerSide: false) {
                result.append(horizontal(display, .bottomRight, y: f.maxY, span: (f.maxX - length)...(f.maxX + length), owner: .lowerCoordinate, edge: "bottom"))
            }
        }
        return result
    }

    static func constrain(from previous: CGPoint, to proposed: CGPoint, barriers: [CursorBarrier], inset: CGFloat = 0.5) -> CGPoint {
        collision(from: previous, to: proposed, barriers: barriers, inset: inset)?.point ?? proposed
    }

    static func collision(from previous: CGPoint, to proposed: CGPoint, barriers: [CursorBarrier], inset: CGFloat = 0.5) -> CursorBarrierCollision? {
        // Mouse hardware can report a fast diagonal gesture as a handful of
        // coarse samples.  Without a small velocity-dependent allowance, one
        // sample can cross the seam just beyond the configured span and the
        // next sample can already be inside the adjacent display's corner.
        // Cap the allowance so it only closes that sampling gap; it must not
        // turn a short corner wall into a large section of the shared edge.
        let sampleDistance = hypot(proposed.x - previous.x, proposed.y - previous.y)
        let samplingPadding = min(12, max(0.5, sampleDistance * 0.1))
        for barrier in barriers {
            switch barrier.axis {
            case .vertical:
                guard crosses(previous.x, proposed.x, coordinate: barrier.coordinate, owner: barrier.ownerSide) else { continue }
                let intersection = interpolatedCoordinate(
                    startPrimary: previous.x, endPrimary: proposed.x,
                    startSecondary: previous.y, endSecondary: proposed.y,
                    boundary: barrier.coordinate
                )
                let collisionCoordinate: CGFloat
                if barrier.span.contains(intersection) {
                    collisionCoordinate = intersection
                } else if barrier.span.contains(proposed.y) {
                    collisionCoordinate = proposed.y
                } else if contains(intersection, in: barrier.span, padding: samplingPadding) {
                    collisionCoordinate = clamped(intersection, to: barrier.span)
                } else if contains(proposed.y, in: barrier.span, padding: samplingPadding) {
                    collisionCoordinate = clamped(proposed.y, to: barrier.span)
                } else {
                    continue
                }
                return CursorBarrierCollision(
                    point: clampToOwnerDisplay(
                        CGPoint(
                            x: barrier.coordinate + (barrier.ownerSide == .higherCoordinate ? 0 : -inset),
                            y: collisionCoordinate
                        ),
                        barrier: barrier,
                        inset: inset
                    ),
                    barrier: barrier
                )
            case .horizontal:
                guard crosses(previous.y, proposed.y, coordinate: barrier.coordinate, owner: barrier.ownerSide) else { continue }
                let intersection = interpolatedCoordinate(
                    startPrimary: previous.y, endPrimary: proposed.y,
                    startSecondary: previous.x, endSecondary: proposed.x,
                    boundary: barrier.coordinate
                )
                let collisionCoordinate: CGFloat
                if barrier.span.contains(intersection) {
                    collisionCoordinate = intersection
                } else if barrier.span.contains(proposed.x) {
                    collisionCoordinate = proposed.x
                } else if contains(intersection, in: barrier.span, padding: samplingPadding) {
                    collisionCoordinate = clamped(intersection, to: barrier.span)
                } else if contains(proposed.x, in: barrier.span, padding: samplingPadding) {
                    collisionCoordinate = clamped(proposed.x, to: barrier.span)
                } else {
                    continue
                }
                return CursorBarrierCollision(
                    point: clampToOwnerDisplay(
                        CGPoint(
                            x: collisionCoordinate,
                            y: barrier.coordinate + (barrier.ownerSide == .higherCoordinate ? 0 : -inset)
                        ),
                        barrier: barrier,
                        inset: inset
                    ),
                    barrier: barrier
                )
            }
        }
        return nil
    }

    /// Detect arrival at the physical junction when WindowServer clamps the
    /// pointer to an outer display edge. At an exact outer corner there may be
    /// no coordinate beyond the seam, so the normal crossing test never sees
    /// a crossing even though the user has deliberately hit the corner.
    static func cornerContact(
        from previous: CGPoint,
        to proposed: CGPoint,
        barriers: [CursorBarrier],
        tolerance: CGFloat = 1,
        inset: CGFloat = 0.5
    ) -> CursorBarrierCollision? {
        for barrier in barriers {
            let junction = junctionPoint(of: barrier)
            let proposedAtJunction = abs(proposed.x - junction.x) <= tolerance
                && abs(proposed.y - junction.y) <= tolerance
            guard proposedAtJunction else { continue }

            let previousAtJunction = abs(previous.x - junction.x) <= tolerance
                && abs(previous.y - junction.y) <= tolerance
            guard !previousAtJunction else { continue }

            // The caller already filters by approach display. This additional
            // frame check prevents a nearby point on another display from
            // manufacturing a contact for the wrong owner.
            guard containsClosed(barrier.ownerFrame, previous) else { continue }
            guard approachesBoundary(from: previous, to: proposed, barrier: barrier) else { continue }
            return CursorBarrierCollision(
                point: clampToOwnerDisplay(junction, barrier: barrier, inset: inset),
                barrier: barrier
            )
        }
        return nil
    }

    private static func approachesBoundary(
        from previous: CGPoint,
        to proposed: CGPoint,
        barrier: CursorBarrier
    ) -> Bool {
        let start: CGFloat
        let end: CGFloat
        switch barrier.axis {
        case .vertical:
            start = previous.x
            end = proposed.x
        case .horizontal:
            start = previous.y
            end = proposed.y
        }
        switch barrier.ownerSide {
        case .higherCoordinate:
            return end <= start
        case .lowerCoordinate:
            return end >= start
        }
    }

    private static func contains(_ value: CGFloat, in span: ClosedRange<CGFloat>, padding: CGFloat) -> Bool {
        value >= span.lowerBound - padding && value <= span.upperBound + padding
    }

    private static func clamped(_ value: CGFloat, to span: ClosedRange<CGFloat>) -> CGFloat {
        min(max(value, span.lowerBound), span.upperBound)
    }

    private static func crosses(_ start: CGFloat, _ end: CGFloat, coordinate: CGFloat, owner: BarrierOwnerSide) -> Bool {
        switch owner {
        case .higherCoordinate: start >= coordinate && end < coordinate
        case .lowerCoordinate: start <= coordinate && end > coordinate
        }
    }

    private static func containsHalfOpen(_ frame: CGRect, _ point: CGPoint) -> Bool {
        point.x >= frame.minX && point.x < frame.maxX && point.y >= frame.minY && point.y < frame.maxY
    }

    private static func containsClosed(_ frame: CGRect, _ point: CGPoint) -> Bool {
        point.x >= frame.minX && point.x <= frame.maxX && point.y >= frame.minY && point.y <= frame.maxY
    }

    static func sameJunction(_ lhs: CursorBarrier, _ rhs: CursorBarrier) -> Bool {
        let a = junctionPoint(of: lhs)
        let b = junctionPoint(of: rhs)
        return abs(a.x - b.x) < 0.5 && abs(a.y - b.y) < 0.5
    }

    private static func junctionPoint(of barrier: CursorBarrier) -> CGPoint {
        let frame = barrier.ownerFrame
        switch barrier.corner {
        case .topLeft: return CGPoint(x: frame.minX, y: frame.minY)
        case .topRight: return CGPoint(x: frame.maxX, y: frame.minY)
        case .bottomLeft: return CGPoint(x: frame.minX, y: frame.maxY)
        case .bottomRight: return CGPoint(x: frame.maxX, y: frame.maxY)
        }
    }

    private static func interpolatedCoordinate(
        startPrimary: CGFloat, endPrimary: CGFloat,
        startSecondary: CGFloat, endSecondary: CGFloat,
        boundary: CGFloat
    ) -> CGFloat {
        let delta = endPrimary - startPrimary
        guard delta != 0 else { return startSecondary }
        let fraction = (boundary - startPrimary) / delta
        return startSecondary + (endSecondary - startSecondary) * fraction
    }

    /// Keep the collision strictly inside the owning display. Landing on an
    /// exact shared/outer coordinate such as (0, 0) is ambiguous to
    /// WindowServer, and a following high-speed hardware sample can be
    /// attributed directly to the adjacent display. A half-point inset is
    /// visually imperceptible but preserves an unambiguous owner.
    private static func clampToOwnerDisplay(_ point: CGPoint, barrier: CursorBarrier, inset: CGFloat) -> CGPoint {
        let f = barrier.ownerFrame
        return CGPoint(
            x: min(max(point.x, f.minX + inset), f.maxX - inset),
            y: min(max(point.y, f.minY + inset), f.maxY - inset)
        )
    }

    private static func hasNeighbor(
        _ displays: [QuartzDisplayDescriptor], excluding id: UInt32,
        acrossX x: CGFloat, y: CGFloat, onLowerSide: Bool
    ) -> Bool {
        displays.contains { other in
            guard other.id != id, y >= other.frame.minY, y < other.frame.maxY else { return false }
            return abs((onLowerSide ? other.frame.maxX : other.frame.minX) - x) < 0.5
        }
    }

    private static func hasNeighbor(
        _ displays: [QuartzDisplayDescriptor], excluding id: UInt32,
        acrossY y: CGFloat, x: CGFloat, onLowerSide: Bool
    ) -> Bool {
        displays.contains { other in
            guard other.id != id, x >= other.frame.minX, x < other.frame.maxX else { return false }
            return abs((onLowerSide ? other.frame.maxY : other.frame.minY) - y) < 0.5
        }
    }

    private static func vertical(
        _ display: QuartzDisplayDescriptor, _ corner: Corner, x: CGFloat,
        span: ClosedRange<CGFloat>, owner: BarrierOwnerSide, edge: String
    ) -> CursorBarrier {
        CursorBarrier(id: "\(display.id):\(corner.rawValue):\(edge)", displayID: display.id, corner: corner,
                      axis: .vertical, coordinate: x, span: span, ownerSide: owner, ownerFrame: display.frame)
    }

    private static func horizontal(
        _ display: QuartzDisplayDescriptor, _ corner: Corner, y: CGFloat,
        span: ClosedRange<CGFloat>, owner: BarrierOwnerSide, edge: String
    ) -> CursorBarrier {
        CursorBarrier(id: "\(display.id):\(corner.rawValue):\(edge)", displayID: display.id, corner: corner,
                      axis: .horizontal, coordinate: y, span: span, ownerSide: owner, ownerFrame: display.frame)
    }
}
