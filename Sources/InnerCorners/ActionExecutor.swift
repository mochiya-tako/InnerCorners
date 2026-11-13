import AppKit
import ApplicationServices
import CoreGraphics

@MainActor
final class ActionExecutor {
    enum Result {
        case performed
        case requested
        case permissionRequired
        case skipped(String)
    }

    func perform(_ action: CornerAction, zone: HotZone, language: AppLanguage) -> Result {
        switch action {
        case .systemHotCorner:
            return performSystemHotCorner(for: zone.corner, language: language)
        case .none:
            return .skipped(L10n.text(language, ja: "アクション未設定", en: "No action assigned"))
        case .testNotification:
            NSSound.beep()
            return .performed
        case .missionControl:
            return runMissionControlDocklet(argument: nil, language: language)
        case .applicationWindows:
            // App Exposé acts on the frontmost application; do not steal focus first.
            guard NSWorkspace.shared.frontmostApplication?.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
                return .skipped(L10n.text(language, ja: "設定画面が前面のため抑制", en: "Suppressed while Settings is frontmost"))
            }
            return runMissionControlDocklet(argument: "2", language: language)
        case .showDesktop:
            return runMissionControlDocklet(argument: "1", language: language)
        case .launchpad:
            return openLaunchpadApplication(language: language)
        }
    }

    func requestAccessibilityPermission() {
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    var isAccessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    func systemHotCornerDescription(for corner: Corner, language: AppLanguage) -> String {
        let suffix = preferenceSuffix(for: corner)
        let dock = UserDefaults(suiteName: "com.apple.dock")
        let modifier = dock?.integer(forKey: "wvous-\(suffix)-modifier") ?? 0
        let action: String
        switch dock?.integer(forKey: "wvous-\(suffix)-corner") ?? 0 {
        case 2: action = "Mission Control"
        case 3: action = L10n.text(language, ja: "アプリケーションウインドウ", en: "Application Windows")
        case 4: action = L10n.text(language, ja: "デスクトップを表示", en: "Show Desktop")
        case 11: action = L10n.text(language, ja: "アプリ", en: "Apps")
        case 0: action = L10n.text(language, ja: "なし", en: "None")
        default: action = L10n.text(language, ja: "未対応の標準アクション", en: "Unsupported macOS action")
        }
        return modifier == 0 ? action : L10n.text(language, ja: "\(action)（修飾キーあり・未対応）", en: "\(action) (modifier unsupported)")
    }

    private func performSystemHotCorner(for corner: Corner, language: AppLanguage) -> Result {
        let suffix = preferenceSuffix(for: corner)
        let dock = UserDefaults(suiteName: "com.apple.dock")
        let modifier = dock?.integer(forKey: "wvous-\(suffix)-modifier") ?? 0
        guard modifier == 0 else {
            return .skipped(L10n.text(language, ja: "標準ホットコーナーに修飾キーが設定されています", en: "The macOS Hot Corner uses a modifier key"))
        }
        switch dock?.integer(forKey: "wvous-\(suffix)-corner") ?? 0 {
        case 2: return runMissionControlDocklet(argument: nil, language: language)
        case 3: return runMissionControlDocklet(argument: "2", language: language)
        case 4: return runMissionControlDocklet(argument: "1", language: language)
        case 11: return openLaunchpadApplication(language: language)
        case 0: return .skipped(L10n.text(language, ja: "macOS標準設定は「なし」です", en: "The macOS Hot Corner is set to None"))
        default: return .skipped(L10n.text(language, ja: "このmacOS標準アクションは試作品では未対応です", en: "This macOS Hot Corner action is not supported yet"))
        }
    }

    private func preferenceSuffix(for corner: Corner) -> String {
        switch corner {
        case .topLeft: "tl"
        case .topRight: "tr"
        case .bottomLeft: "bl"
        case .bottomRight: "br"
        }
    }

    private func runMissionControlDocklet(argument: String?, language: AppLanguage) -> Result {
        openDockletApplication(
            at: "/System/Applications/Mission Control.app",
            arguments: argument.map { [$0] } ?? [],
            language: language
        )
    }

    private func openLaunchpadApplication(language: AppLanguage) -> Result {
        let candidates = [
            "/System/Applications/Apps.app",
            "/System/Applications/Launchpad.app"
        ]
        guard let path = candidates.first(where: FileManager.default.fileExists(atPath:)) else {
            return .skipped(L10n.text(
                language,
                ja: "macOS標準アプリを見つけられません",
                en: "The required macOS app was not found"
            ))
        }
        return openDockletApplication(at: path, arguments: [], language: language)
    }

    private func openDockletApplication(at path: String, arguments: [String], language: AppLanguage) -> Result {
        guard FileManager.default.fileExists(atPath: path) else {
            return .skipped(L10n.text(language, ja: "macOS標準アプリを見つけられません", en: "The required macOS app was not found"))
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.arguments = arguments
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(
            at: URL(fileURLWithPath: path),
            configuration: configuration
        ) { _, error in
            if let error, ProcessInfo.processInfo.environment["INNERCORNERS_DIAGNOSTICS"] == "1" {
                FileHandle.standardError.write(Data("Docklet launch error: \(error)\n".utf8))
            }
        }
        // NSWorkspace completes asynchronously.  At this point the request was
        // accepted, but the target application has not yet reported success.
        return .requested
    }

}
