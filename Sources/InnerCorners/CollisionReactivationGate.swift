import CoreGraphics
import Foundation

/// Distinguishes an intentional leave-and-return gesture from the transient
/// pointer jumps that Mission Control can produce immediately after launch.
///
/// A second collision may bypass the ordinary one-second duplicate guard only
/// after the pointer has been observed safely back inside the owning display
/// on at least two movement samples. This keeps fast, deliberate cancellation
/// responsive without restoring the old transition-time double firing.
struct CollisionReactivationGate {
    private var triggeredBarrier: CursorBarrier?
    private var exitCandidateSince: TimeInterval?
    private var exitSampleCount = 0
    private var isReady = false

    private let minimumExitDuration: TimeInterval
    private let requiredExitSamples: Int

    init(minimumExitDuration: TimeInterval = 0.04, requiredExitSamples: Int = 2) {
        self.minimumExitDuration = minimumExitDuration
        self.requiredExitSamples = requiredExitSamples
    }

    mutating func recordTrigger(_ barrier: CursorBarrier) {
        triggeredBarrier = barrier
        exitCandidateSince = nil
        exitSampleCount = 0
        isReady = false
    }

    mutating func observeMovement(
        at point: CGPoint,
        now: TimeInterval,
        stableDisplayID: UInt32?
    ) {
        guard let triggeredBarrier else { return }

        // Once a deliberate retreat has been established, keep it armed while
        // the pointer approaches the same junction again. The approach itself
        // naturally re-enters the wall radius before the collision occurs.
        if isReady {
            if let stableDisplayID, stableDisplayID != triggeredBarrier.displayID {
                reset()
            }
            return
        }

        guard stableDisplayID == triggeredBarrier.displayID,
              CursorBarrierGeometry.shouldReleaseLatch(at: point, barrier: triggeredBarrier) else {
            exitCandidateSince = nil
            exitSampleCount = 0
            return
        }

        if exitCandidateSince == nil {
            exitCandidateSince = now
        }
        exitSampleCount += 1
        let duration = now - (exitCandidateSince ?? now)
        if exitSampleCount >= requiredExitSamples && duration >= minimumExitDuration {
            isReady = true
        }
    }

    mutating func consumeReactivation(for barrier: CursorBarrier) -> Bool {
        guard isReady,
              let triggeredBarrier,
              CursorBarrierGeometry.sameJunction(triggeredBarrier, barrier) else {
            return false
        }
        reset()
        return true
    }

    mutating func reset() {
        triggeredBarrier = nil
        exitCandidateSince = nil
        exitSampleCount = 0
        isReady = false
    }
}
