import Foundation

/// Pure state machine for dwell timing and reactivation suppression.
/// Keeping this separate from AppKit makes the behavior deterministic and testable.
struct ActivationGate {
    private(set) var candidateID: String?
    private(set) var candidateSince: TimeInterval?
    private(set) var firedZoneID: String?

    mutating func update(zoneID: String?, now: TimeInterval, dwell: TimeInterval) -> String? {
        guard let zoneID else {
            reset()
            return nil
        }
        guard firedZoneID != zoneID else { return nil }

        if candidateID != zoneID {
            candidateID = zoneID
            candidateSince = now
        }

        guard now - (candidateSince ?? now) >= max(0, dwell) else { return nil }
        firedZoneID = zoneID
        candidateID = nil
        candidateSince = nil
        return zoneID
    }

    mutating func reset() {
        candidateID = nil
        candidateSince = nil
        firedZoneID = nil
    }
}
