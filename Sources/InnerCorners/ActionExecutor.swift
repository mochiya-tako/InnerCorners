import AppKit
import ApplicationServices
import CoreGraphics

@MainActor
final class ActionExecutor {
    private enum VirtualKey {
        static let q: CGKeyCode = 12
        static let n: CGKeyCode = 45
    }

    enum Result {
        case performed
        case requested
        case permissionRequired
        case unsupported(String)
        case failed(String)
        case skipped(String)

        var diagnosticCode: String {
            switch self {
            case .performed: "performed"
            case .requested: "requested"
            case .permissionRequired: "permission-required"
            case .unsupported: "unsupported"
            case .failed: "failed"
            case .skipped: "skipped"
            }
        }
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
        let dockValue = dock?.integer(forKey: "wvous-\(suffix)-corner") ?? 0
        let action = SystemHotCornerAction(dockValue: dockValue).title(language: language)
        guard modifier != 0 else { return action }
        let requirement = SystemHotCornerModifier(dockValue: modifier)
        if requirement.usesEmergencyOptionKey {
            return L10n.text(
                language,
                ja: "\(action)（⌥は緊急通過を優先）",
                en: "\(action) (⌥ is reserved for emergency bypass)"
            )
        }
        return L10n.text(
            language,
            ja: "\(action)（必要キー：\(requirement.symbols(language: language))）",
            en: "\(action) (requires \(requirement.symbols(language: language)))"
        )
    }

    private func performSystemHotCorner(for corner: Corner, language: AppLanguage) -> Result {
        let suffix = preferenceSuffix(for: corner)
        let dock = UserDefaults(suiteName: "com.apple.dock")
        let modifier = dock?.integer(forKey: "wvous-\(suffix)-modifier") ?? 0
        let modifierRequirement = SystemHotCornerModifier(dockValue: modifier)
        if modifierRequirement.hasUnknownBits {
            return .unsupported(L10n.text(
                language,
                ja: "未対応の修飾キー設定です（値：\(modifier)）",
                en: "Unsupported modifier setting (value: \(modifier))"
            ))
        }
        if modifierRequirement.usesEmergencyOptionKey {
            return .unsupported(L10n.text(
                language,
                ja: "Optionキーは緊急通過を優先するため、アクション条件には使用できません",
                en: "The Option key is reserved for emergency bypass and cannot trigger an action"
            ))
        }
        let currentFlags = CGEventSource.flagsState(.combinedSessionState)
        guard modifierRequirement.matches(current: currentFlags) else {
            return .skipped(L10n.text(
                language,
                ja: "必要な修飾キー（\(modifierRequirement.symbols(language: language))）が押されていません",
                en: "Required modifier keys are not pressed (\(modifierRequirement.symbols(language: language)))"
            ))
        }
        let dockValue = dock?.integer(forKey: "wvous-\(suffix)-corner") ?? 0
        let action = SystemHotCornerAction(dockValue: dockValue)
        switch action {
        case .missionControl:
            return runMissionControlDocklet(argument: nil, language: language)
        case .applicationWindows:
            return runMissionControlDocklet(argument: "2", language: language)
        case .showDesktop:
            return runMissionControlDocklet(argument: "1", language: language)
        case .apps:
            return openLaunchpadApplication(language: language)
        case .none:
            return .skipped(L10n.text(language, ja: "macOS標準設定は「なし」です", en: "The macOS Hot Corner is set to None"))
        case .disableScreenSaver:
            return .unsupported(L10n.text(
                language,
                ja: "\(action.title(language: language))はまだ実装されていません",
                en: "\(action.title(language: language)) is not implemented yet"
            ))
        case .putDisplayToSleep:
            return runSystemCommand(
                at: "/usr/bin/pmset",
                arguments: ["displaysleepnow"],
                language: language
            )
        case .startScreenSaver:
            return openScreenSaverApplication(language: language)
        case .notificationCenter:
            return postKeyboardShortcut(
                keyCode: VirtualKey.n,
                flags: .maskSecondaryFn,
                language: language
            )
        case .lockScreen:
            return postKeyboardShortcut(
                keyCode: VirtualKey.q,
                flags: [.maskControl, .maskCommand],
                language: language
            )
        case .quickNote:
            return postKeyboardShortcut(
                keyCode: VirtualKey.q,
                flags: .maskSecondaryFn,
                language: language
            )
        case .unknown:
            return .unsupported(action.title(language: language))
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
            return .failed(L10n.text(
                language,
                ja: "macOS標準アプリを見つけられません",
                en: "The required macOS app was not found"
            ))
        }
        return openDockletApplication(at: path, arguments: [], language: language)
    }

    private func openScreenSaverApplication(language: AppLanguage) -> Result {
        let bundleIdentifier = "com.apple.ScreenSaver.Engine"
        let candidates = [
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier),
            URL(fileURLWithPath: "/System/Library/CoreServices/ScreenSaverEngine.app")
        ]
        guard let url = candidates.compactMap({ $0 }).first(where: {
            FileManager.default.fileExists(atPath: $0.path)
        }) else {
            return .failed(L10n.text(
                language,
                ja: "macOSのスクリーンセーバアプリを見つけられません",
                en: "The macOS screen saver application was not found"
            ))
        }
        return openApplication(at: url, arguments: [], language: language)
    }

    private func openDockletApplication(at path: String, arguments: [String], language: AppLanguage) -> Result {
        guard FileManager.default.fileExists(atPath: path) else {
            return .failed(L10n.text(language, ja: "macOS標準アプリを見つけられません", en: "The required macOS app was not found"))
        }
        return openApplication(
            at: URL(fileURLWithPath: path),
            arguments: arguments,
            language: language
        )
    }

    private func openApplication(at url: URL, arguments: [String], language: AppLanguage) -> Result {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.arguments = arguments
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(
            at: url,
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

    private func postKeyboardShortcut(
        keyCode: CGKeyCode,
        flags: CGEventFlags,
        language: AppLanguage
    ) -> Result {
        guard CGPreflightPostEventAccess() else {
            return .permissionRequired
        }
        let source = CGEventSource(stateID: .combinedSessionState)
        guard let keyDown = CGEvent(
            keyboardEventSource: source,
            virtualKey: keyCode,
            keyDown: true
        ), let keyUp = CGEvent(
            keyboardEventSource: source,
            virtualKey: keyCode,
            keyDown: false
        ) else {
            return .failed(L10n.text(
                language,
                ja: "キーボードイベントを作成できませんでした",
                en: "Could not create keyboard events"
            ))
        }
        keyDown.flags = flags
        keyUp.flags = flags
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        // CGEvent posting has no completion callback. The request was posted,
        // but only the target system feature can confirm the visible result.
        return .requested
    }

    private func runSystemCommand(
        at path: String,
        arguments: [String],
        language: AppLanguage
    ) -> Result {
        guard FileManager.default.isExecutableFile(atPath: path) else {
            return .failed(L10n.text(
                language,
                ja: "必要なmacOSコマンドを実行できません",
                en: "The required macOS command is not executable"
            ))
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            // Process launch is synchronous, but command completion is not.
            return .requested
        } catch {
            return .failed(L10n.text(
                language,
                ja: "macOSコマンドを起動できませんでした：\(error.localizedDescription)",
                en: "Could not launch the macOS command: \(error.localizedDescription)"
            ))
        }
    }

}
