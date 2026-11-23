import CoreGraphics
import Foundation

struct WorkspaceWindowDescriptor: Equatable {
    let owner: String
    let name: String
    let layer: Int
}

enum WorkspaceOverviewDetector {
    static func isOverviewWindow(_ window: WorkspaceWindowDescriptor) -> Bool {
        guard window.owner == "WindowManager" else { return false }
        switch window.name {
        case "ExposeShieldWindow":
            return window.layer >= 19
        case "ShowDesktopOverlay":
            return window.layer >= 18
        default:
            return false
        }
    }

    static func isActive() -> Bool {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return false
        }
        return windowList.contains { entry in
            let descriptor = WorkspaceWindowDescriptor(
                owner: entry[kCGWindowOwnerName as String] as? String ?? "",
                name: entry[kCGWindowName as String] as? String ?? "",
                layer: entry[kCGWindowLayer as String] as? Int ?? Int.min
            )
            return isOverviewWindow(descriptor)
        }
    }
}
