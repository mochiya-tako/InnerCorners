import Foundation

struct FrontmostApplicationSnapshot: Equatable, Sendable {
    let localizedName: String?
    let bundleIdentifier: String?
    let processIdentifier: pid_t

    static func resolved(
        activationNotification: FrontmostApplicationSnapshot?,
        currentQuery: @autoclosure () -> FrontmostApplicationSnapshot?
    ) -> FrontmostApplicationSnapshot? {
        activationNotification ?? currentQuery()
    }
}
