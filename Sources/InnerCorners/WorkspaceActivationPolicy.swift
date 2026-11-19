import Foundation

enum WorkspaceActivationPolicy {
    private static let workspaceBundleIdentifiers: Set<String> = [
        "com.apple.apps.launcher",
        "com.apple.launchpad.launcher",
        "com.apple.exposelauncher",
        "com.apple.dock"
    ]

    static func shouldClearCancellationState(activatedBundleIdentifier: String?) -> Bool {
        guard let activatedBundleIdentifier else { return true }
        return !workspaceBundleIdentifiers.contains(activatedBundleIdentifier)
    }
}
