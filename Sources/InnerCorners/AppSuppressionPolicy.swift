import CoreGraphics
import Foundation

struct AppSuppressionState: Equatable {
    var isPausedByTimer: Bool
    var isExcludedAppFrontmost: Bool
    var isFullscreenAppFrontmost: Bool
    var scope: SuppressionScope

    var shouldSuppressActions: Bool {
        isPausedByTimer || isExcludedAppFrontmost || isFullscreenAppFrontmost
    }

    var shouldSuppressBarriers: Bool {
        if isPausedByTimer {
            return true
        }
        guard scope == .barriersAndActions else {
            return false
        }
        return isExcludedAppFrontmost || isFullscreenAppFrontmost
    }
}

enum AppSuppressionPolicy {
    static func evaluate(
        now: Date,
        pausedUntil: Date?,
        frontmostBundleID: String?,
        isFrontmostFullscreen: Bool,
        preferences: Preferences
    ) -> AppSuppressionState {
        let timerActive = pausedUntil.map { $0 > now } ?? false
        let excludedActive: Bool
        if let bundleID = frontmostBundleID, !bundleID.isEmpty {
            excludedActive = preferences.excludedBundleIdentifiers.contains {
                $0.caseInsensitiveCompare(bundleID) == .orderedSame
            }
        } else {
            excludedActive = false
        }
        let fullscreenActive = preferences.pauseInFullscreenApps && isFrontmostFullscreen
        return AppSuppressionState(
            isPausedByTimer: timerActive,
            isExcludedAppFrontmost: excludedActive,
            isFullscreenAppFrontmost: fullscreenActive,
            scope: preferences.suppressionScope
        )
    }

    static func hasFullscreenWindow(
        windowBounds: [CGRect],
        displays: [QuartzDisplayDescriptor],
        tolerance: CGFloat = 2.0
    ) -> Bool {
        guard !windowBounds.isEmpty, !displays.isEmpty else { return false }
        return windowBounds.contains { window in
            displays.contains { display in
                abs(window.minX - display.frame.minX) <= tolerance &&
                abs(window.minY - display.frame.minY) <= tolerance &&
                abs(window.width - display.frame.width) <= tolerance &&
                abs(window.height - display.frame.height) <= tolerance
            }
        }
    }

    static func isProcessFullscreen(
        pid: pid_t,
        displays: [QuartzDisplayDescriptor]
    ) -> Bool {
        guard pid > 0, !displays.isEmpty else { return false }
        guard let infoList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return false
        }
        var matchingBounds: [CGRect] = []
        for entry in infoList {
            guard let ownerPID = entry[kCGWindowOwnerPID as String] as? Int32,
                  ownerPID == pid else { continue }
            let layer = (entry[kCGWindowLayer as String] as? Int) ?? 0
            guard layer == 0 else { continue }
            if let boundsDict = entry[kCGWindowBounds as String] as? NSDictionary,
               let rect = CGRect(dictionaryRepresentation: boundsDict) {
                matchingBounds.append(rect)
            }
        }
        return hasFullscreenWindow(windowBounds: matchingBounds, displays: displays)
    }
}
