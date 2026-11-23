import CoreGraphics
import Foundation

/// Controls the optional "Speed Bump" (push-through) barrier behavior.
///
/// When enabled, the first collision at a junction stops the cursor just like
/// a hard barrier. If the user keeps pushing against the same junction
/// continuously (with no gap longer than `maxSampleGap`) for `holdDuration`,
/// the junction opens temporarily so the cursor can pass into the adjacent
/// display without pressing Option. Once the pointer moves away from the
/// junction by `releaseDistance`, the barrier automatically closes again.
struct SpeedBumpGate {
    enum Decision: Equatable {
        case block
        case allowPassage
    }

    private var pushingBarrier: CursorBarrier?
    private var pushStartedAt: TimeInterval?
    private var lastCollisionAt: TimeInterval?
    private var unlockedBarrier: CursorBarrier?

    private let maxSampleGap: TimeInterval
    private let releaseDistance: CGFloat

    init(maxSampleGap: TimeInterval = 0.25, releaseDistance: CGFloat = 16) {
        self.maxSampleGap = maxSampleGap
        self.releaseDistance = releaseDistance
    }

    mutating func evaluateCollision(
        barrier: CursorBarrier,
        now: TimeInterval,
        mode: BarrierPassThroughMode,
        holdDuration: TimeInterval
    ) -> Decision {
        guard mode == .speedBump else {
            reset()
            return .block
        }

        if let unlockedBarrier, CursorBarrierGeometry.sameJunction(unlockedBarrier, barrier) {
            if unlockedBarrier.id == barrier.id {
                return .allowPassage
            }
            // A junction has one directional barrier per owning display. If
            // the first sample after passage is already an opposite-direction
            // collision, re-lock immediately instead of requiring an
            // intermediate non-colliding sample.
            self.unlockedBarrier = nil
        }

        let effectiveHold = max(0.05, holdDuration)
        if let current = pushingBarrier,
           let started = pushStartedAt,
           let last = lastCollisionAt,
           CursorBarrierGeometry.sameJunction(current, barrier),
           now - last <= maxSampleGap {
            lastCollisionAt = now
            if now - started >= effectiveHold {
                unlockedBarrier = barrier
                pushingBarrier = nil
                pushStartedAt = nil
                lastCollisionAt = nil
                return .allowPassage
            }
            return .block
        }

        pushingBarrier = barrier
        pushStartedAt = now
        lastCollisionAt = now
        unlockedBarrier = nil
        return .block
    }

    mutating func observeNonCollidingMovement(at point: CGPoint, now: TimeInterval) {
        if let unlocked = unlockedBarrier {
            if CursorBarrierGeometry.shouldReleaseLatch(at: point, barrier: unlocked, distance: releaseDistance) {
                unlockedBarrier = nil
            }
        }
        if let pushing = pushingBarrier {
            let timedOut = lastCollisionAt.map { now - $0 > maxSampleGap } ?? true
            let retreated = CursorBarrierGeometry.shouldReleaseLatch(at: point, barrier: pushing, distance: releaseDistance)
            if timedOut || retreated {
                pushingBarrier = nil
                pushStartedAt = nil
                lastCollisionAt = nil
            }
        }
    }

    mutating func reset() {
        pushingBarrier = nil
        pushStartedAt = nil
        lastCollisionAt = nil
        unlockedBarrier = nil
    }
}
