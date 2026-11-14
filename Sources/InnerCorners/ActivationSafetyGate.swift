import Foundation

struct ActivationSafetyGate {
    enum Decision: Equatable {
        case active
        case bypassing
        case rearmed
    }

    private enum State: Equatable {
        case active
        case suspended
        case rearming(notBefore: TimeInterval)
    }

    private var state: State = .active

    mutating func suspend() {
        state = .suspended
    }

    mutating func prepareForRearm(now: TimeInterval, delay: TimeInterval) {
        let deadline = now + max(0, delay)
        if case .rearming(let existingDeadline) = state {
            state = .rearming(notBefore: max(existingDeadline, deadline))
        } else {
            state = .rearming(notBefore: deadline)
        }
    }

    mutating func decision(now: TimeInterval, isOutsideActivationZone: Bool) -> Decision {
        switch state {
        case .active:
            return .active
        case .suspended:
            return .bypassing
        case .rearming(let notBefore):
            guard now >= notBefore, isOutsideActivationZone else {
                return .bypassing
            }
            state = .active
            return .rearmed
        }
    }
}
