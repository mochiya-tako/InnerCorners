import Foundation

struct WorkspaceCancellationGate {
    enum Decision: Equatable {
        case executeAndArm
        case cancelAndDisarm
    }

    private var armedUntil: TimeInterval = 0
    private let maximumLifetime: TimeInterval

    init(maximumLifetime: TimeInterval = 30) {
        self.maximumLifetime = maximumLifetime
    }

    mutating func decision(now: TimeInterval, overviewDetected: Bool) -> Decision {
        if overviewDetected || now <= armedUntil {
            armedUntil = 0
            return .cancelAndDisarm
        }
        armedUntil = now + maximumLifetime
        return .executeAndArm
    }

    mutating func clear() {
        armedUntil = 0
    }
}
