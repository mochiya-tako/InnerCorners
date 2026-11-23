import Foundation

enum WorkspaceCancellationTarget: Equatable {
    case missionControl
    case applicationWindows
    case showDesktop
    case apps
}

struct WorkspaceCancellationGate {
    enum Decision: Equatable {
        case executeAndArm
        case cancelAndDisarm(WorkspaceCancellationTarget?)
    }

    private var armedUntil: TimeInterval = 0
    private var armedTarget: WorkspaceCancellationTarget?
    private let maximumLifetime: TimeInterval

    init(maximumLifetime: TimeInterval = 30) {
        self.maximumLifetime = maximumLifetime
    }

    mutating func decision(
        target: WorkspaceCancellationTarget,
        now: TimeInterval,
        overviewDetected: Bool
    ) -> Decision {
        if overviewDetected || now <= armedUntil {
            let cancellationTarget = armedTarget
            armedUntil = 0
            armedTarget = nil
            return .cancelAndDisarm(cancellationTarget)
        }
        armedUntil = now + maximumLifetime
        armedTarget = target
        return .executeAndArm
    }

    mutating func clear() {
        armedUntil = 0
        armedTarget = nil
    }
}
