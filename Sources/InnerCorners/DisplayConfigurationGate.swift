import Foundation

/// Prevents preference or UI refreshes from reviving barriers backed by stale
/// display geometry after Quartz temporarily returns no active displays.
struct DisplayConfigurationGate {
    private(set) var isValid = false

    mutating func acceptUsableConfiguration() {
        isValid = true
    }

    mutating func invalidate() {
        isValid = false
    }
}
