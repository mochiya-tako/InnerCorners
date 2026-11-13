import Foundation

/// Safe rearm state used only for sleep/wake and real display reconfiguration.
/// Normal corner collisions are intended behavior and never open the wall.
struct BarrierSafetyGate {
    enum Decision: Equatable {
        case active
        case bypassing
        case rearmed
    }

    private(set) var rearmNotBefore: TimeInterval = 0
    private(set) var requiresSafeRearm = false

    mutating func reset() {
        rearmNotBefore = 0
        requiresSafeRearm = false
    }

    mutating func requireSafeRearm(now: TimeInterval, delay: TimeInterval) {
        rearmNotBefore = max(rearmNotBefore, now + delay)
        requiresSafeRearm = true
    }

    mutating func decision(now: TimeInterval, isSafePosition: Bool) -> Decision {
        guard requiresSafeRearm else { return .active }
        guard now >= rearmNotBefore, isSafePosition else { return .bypassing }
        reset()
        return .rearmed
    }
}
