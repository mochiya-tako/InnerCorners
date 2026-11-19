import AppKit
import ApplicationServices
import CoreGraphics

@MainActor
final class ActionExecutor {
    private enum VirtualKey {
        static let q: CGKeyCode = 12
        static let n: CGKeyCode = 45
        static let escape: CGKeyCode = 53
    }

    enum Result {
        case performed
        case requested
        case cancelledActiveWorkspace
        case permissionRequired
        case unsupported(String)
        case failed(String)
        case skipped(String)

        var diagnosticCode: String {
            switch self {
            case .performed: "performed"
            case .requested: "requested"
            case .cancelledActiveWorkspace: "workspace-cancel-requested"
            case .permissionRequired: "permission-required"
            case .unsupported: "unsupported"
            case .failed: "failed"
            case .skipped: "skipped"
            }
        }
    }

    struct PermissionCapabilities: Equatable {
        let accessibilityAPI: Bool
        let eventPosting: Bool
    }

    struct AsyncCompletion: Equatable {
        enum Operation: String {
            case applicationLaunch = "application-launch"
            case systemCommand = "system-command"
        }

        let operation: Operation
        let succeeded: Bool
        let diagnosticCode: String
    }

    var onAsyncCompletion: ((AsyncCompletion) -> Void)?
    private var workspaceCancellationGate = WorkspaceCancellationGate()

    nonisolated static func shouldSuppressApplicationWindows(
        frontmostProcessIdentifier: pid_t?,
        currentProcessIdentifier: pid_t
    ) -> Bool {
        frontmostProcessIdentifier == currentProcessIdentifier
    }

    nonisolated static func resolvedModifierFlags(
        observedAtTrigger: CGEventFlags?,
        current: CGEventFlags
    ) -> CGEventFlags {
        observedAtTrigger ?? current
    }

    func perform(
        _ action: CornerAction,
        assignment: CornerAssignment? = nil,
        zone: HotZone,
        modifierFlagsAtTrigger: CGEventFlags? = nil,
        language: AppLanguage
    ) -> Result {
        let effectiveAssignment = assignment ?? CornerAssignment(
            displayID: zone.displayID,
            corner: zone.corner,
            action: action
        )
        if effectiveAssignment.barrierPolicy == .stopperOnly {
            return .skipped(L10n.text(
                language,
                ja: "ストッパー専用コーナー（アクションなし）",
                en: "Stopper-only corner (no action)"
            ))
        }
        if effectiveAssignment.modifierRequirement != .none {
            let currentFlags = Self.resolvedModifierFlags(
                observedAtTrigger: modifierFlagsAtTrigger,
                current: CGEventSource.flagsState(.combinedSessionState)
            )
            guard effectiveAssignment.modifierRequirement.matches(current: currentFlags) else {
                let symbols = effectiveAssignment.modifierRequirement.symbols
                return .skipped(L10n.text(
                    language,
                    ja: "必要な修飾キー（\(symbols)）が押されていません（壁のみ作動）",
                    en: "Required modifier (\(symbols)) not pressed (barrier only)"
                ))
            }
        }

        if let cancellationTarget = workspaceCancellationTarget(for: action, zone: zone) {
            let decision = workspaceCancellationGate.decision(
                target: cancellationTarget,
                now: ProcessInfo.processInfo.systemUptime,
                overviewDetected: WorkspaceOverviewDetector.isActive()
            )
            if case .cancelAndDisarm(let previousTarget) = decision {
                return cancelActiveWorkspaceOverview(
                    target: previousTarget,
                    language: language
                )
            }
        }

        switch action {
        case .systemHotCorner:
            return performSystemHotCorner(
                for: zone.corner,
                ignoreDockModifiers: effectiveAssignment.modifierRequirement != .none,
                modifierFlagsAtTrigger: modifierFlagsAtTrigger,
                language: language
            )
        case .none:
            return .skipped(L10n.text(language, ja: "アクション未設定", en: "No action assigned"))
        case .testNotification:
            NSSound.beep()
            return .performed
        case .missionControl:
            return runMissionControlDocklet(argument: nil, language: language)
        case .applicationWindows:
            guard !Self.shouldSuppressApplicationWindows(
                frontmostProcessIdentifier: NSWorkspace.shared.frontmostApplication?.processIdentifier,
                currentProcessIdentifier: ProcessInfo.processInfo.processIdentifier
            ) else {
                return applicationWindowsSelfSuppressed(language: language)
            }
            return runMissionControlDocklet(argument: "2", language: language)
        case .showDesktop:
            return runMissionControlDocklet(argument: "1", language: language)
        case .launchpad:
            return openLaunchpadApplication(language: language)
        case .quickNote:
            return postKeyboardShortcut(
                keyCode: VirtualKey.q,
                flags: .maskSecondaryFn,
                language: language
            )
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
        case .startScreenSaver:
            return openScreenSaverApplication(language: language)
        case .putDisplayToSleep:
            return runSystemCommand(
                at: "/usr/bin/pmset",
                arguments: ["displaysleepnow"],
                language: language
            )
        case .screenshotSelection:
            return runSystemCommand(
                at: "/usr/sbin/screencapture",
                arguments: ["-i"],
                language: language
            )
        case .screenshotPanel:
            return runSystemCommand(
                at: "/usr/sbin/screencapture",
                arguments: ["-i", "-U"],
                language: language
            )
        case .openApplication:
            return openCustomApplication(
                path: effectiveAssignment.customApplicationPath,
                language: language
            )
        case .runShortcut:
            return runCustomShortcut(
                name: effectiveAssignment.customShortcutName,
                language: language
            )
        }
    }

    func requestAccessibilityPermission() {
        _ = CGRequestPostEventAccess()
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    var permissionCapabilities: PermissionCapabilities {
        PermissionCapabilities(
            accessibilityAPI: AXIsProcessTrusted(),
            eventPosting: CGPreflightPostEventAccess()
        )
    }

    var isAccessibilityGranted: Bool {
        permissionCapabilities.accessibilityAPI
    }

    var canPostEvents: Bool {
        permissionCapabilities.eventPosting
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

    private func performSystemHotCorner(
        for corner: Corner,
        ignoreDockModifiers: Bool,
        modifierFlagsAtTrigger: CGEventFlags?,
        language: AppLanguage
    ) -> Result {
        let suffix = preferenceSuffix(for: corner)
        let dock = UserDefaults(suiteName: "com.apple.dock")
        let modifier = dock?.integer(forKey: "wvous-\(suffix)-modifier") ?? 0
        if !ignoreDockModifiers {
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
            let currentFlags = Self.resolvedModifierFlags(
                observedAtTrigger: modifierFlagsAtTrigger,
                current: CGEventSource.flagsState(.combinedSessionState)
            )
            guard modifierRequirement.matches(current: currentFlags) else {
                return .skipped(L10n.text(
                    language,
                    ja: "必要な修飾キー（\(modifierRequirement.symbols(language: language))）が押されていません",
                    en: "Required modifier keys are not pressed (\(modifierRequirement.symbols(language: language)))"
                ))
            }
        }
        let dockValue = dock?.integer(forKey: "wvous-\(suffix)-corner") ?? 0
        let action = SystemHotCornerAction(dockValue: dockValue)
        switch action {
        case .missionControl:
            return runMissionControlDocklet(argument: nil, language: language)
        case .applicationWindows:
            guard !Self.shouldSuppressApplicationWindows(
                frontmostProcessIdentifier: NSWorkspace.shared.frontmostApplication?.processIdentifier,
                currentProcessIdentifier: ProcessInfo.processInfo.processIdentifier
            ) else {
                return applicationWindowsSelfSuppressed(language: language)
            }
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

    private func applicationWindowsSelfSuppressed(language: AppLanguage) -> Result {
        .skipped(L10n.text(
            language,
            ja: "設定画面が前面のため抑制",
            en: "Suppressed while Settings is frontmost"
        ))
    }

    private func workspaceCancellationTarget(
        for action: CornerAction,
        zone: HotZone
    ) -> WorkspaceCancellationTarget? {
        switch action {
        case .systemHotCorner:
            let suffix = preferenceSuffix(for: zone.corner)
            let dockValue = UserDefaults(suiteName: "com.apple.dock")?
                .integer(forKey: "wvous-\(suffix)-corner") ?? 0
            switch SystemHotCornerAction(dockValue: dockValue) {
            case .missionControl:
                return WorkspaceCancellationTarget.missionControl
            case .applicationWindows:
                return WorkspaceCancellationTarget.applicationWindows
            case .showDesktop:
                return WorkspaceCancellationTarget.showDesktop
            case .apps:
                return WorkspaceCancellationTarget.apps
            default:
                return nil
            }
        case .missionControl:
            return WorkspaceCancellationTarget.missionControl
        case .applicationWindows:
            return WorkspaceCancellationTarget.applicationWindows
        case .showDesktop:
            return WorkspaceCancellationTarget.showDesktop
        case .launchpad:
            return WorkspaceCancellationTarget.apps
        default:
            return nil
        }
    }

    func clearWorkspaceCancellationState() {
        workspaceCancellationGate.clear()
    }

    private func cancelActiveWorkspaceOverview(
        target: WorkspaceCancellationTarget?,
        language: AppLanguage
    ) -> Result {
        // Repeating the action which opened the active workspace view uses the
        // same toggle path as a second macOS Hot Corner collision. This avoids
        // racing an Escape event against an asynchronously opening Apps view.
        let result: Result
        switch target {
        case .missionControl:
            result = runMissionControlDocklet(argument: nil, language: language)
        case .applicationWindows:
            result = runMissionControlDocklet(argument: "2", language: language)
        case .showDesktop:
            result = runMissionControlDocklet(argument: "1", language: language)
        case .apps:
            result = openLaunchpadApplication(language: language)
        case nil:
            return postEscapeForDetectedWorkspace(language: language)
        }
        switch result {
        case .requested, .performed:
            return .cancelledActiveWorkspace
        default:
            return result
        }
    }

    private func postEscapeForDetectedWorkspace(language: AppLanguage) -> Result {
        guard canPostEvents else { return .permissionRequired }
        let source = CGEventSource(stateID: .combinedSessionState)
        guard let keyDown = CGEvent(
            keyboardEventSource: source,
            virtualKey: VirtualKey.escape,
            keyDown: true
        ), let keyUp = CGEvent(
            keyboardEventSource: source,
            virtualKey: VirtualKey.escape,
            keyDown: false
        ) else {
            return .failed(L10n.text(
                language,
                ja: "キャンセル用キーイベントを作成できませんでした",
                en: "Could not create the cancellation key event"
            ))
        }
        keyDown.flags = []
        keyUp.flags = []
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return .cancelledActiveWorkspace
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
        return openApplication(at: url, arguments: [], createsNewInstance: true, language: language)
    }

    private func openCustomApplication(path: String?, language: AppLanguage) -> Result {
        guard let path = path?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty else {
            return .skipped(L10n.text(
                language,
                ja: "起動するアプリが選択されていません",
                en: "No application selected to open"
            ))
        }
        guard FileManager.default.fileExists(atPath: path) else {
            return .failed(L10n.text(
                language,
                ja: "指定されたアプリが見つかりません",
                en: "The selected application was not found"
            ))
        }
        return openApplication(
            at: URL(fileURLWithPath: path),
            arguments: [],
            createsNewInstance: false,
            language: language
        )
    }

    private func runCustomShortcut(name: String?, language: AppLanguage) -> Result {
        guard let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return .skipped(L10n.text(
                language,
                ja: "ショートカット名が指定されていません",
                en: "No Shortcut name specified"
            ))
        }
        return runSystemCommand(
            at: "/usr/bin/shortcuts",
            arguments: ["run", trimmed],
            language: language
        )
    }

    private func openDockletApplication(at path: String, arguments: [String], language: AppLanguage) -> Result {
        guard FileManager.default.fileExists(atPath: path) else {
            return .failed(L10n.text(language, ja: "macOS標準アプリを見つけられません", en: "The required macOS app was not found"))
        }
        return openApplication(
            at: URL(fileURLWithPath: path),
            arguments: arguments,
            createsNewInstance: true,
            language: language
        )
    }

    private func openApplication(
        at url: URL,
        arguments: [String],
        createsNewInstance: Bool,
        language: AppLanguage
    ) -> Result {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.arguments = arguments
        configuration.createsNewApplicationInstance = createsNewInstance
        configuration.activates = true
        NSWorkspace.shared.openApplication(
            at: url,
            configuration: configuration
        ) { [weak self] _, error in
            if let error, ProcessInfo.processInfo.environment["INNERCORNERS_DIAGNOSTICS"] == "1" {
                FileHandle.standardError.write(Data("Docklet launch error: \(error)\n".utf8))
            }
            let completion = AsyncCompletion(
                operation: .applicationLaunch,
                succeeded: error == nil,
                diagnosticCode: error == nil ? "completed" : "failed"
            )
            Task { @MainActor [weak self] in
                self?.onAsyncCompletion?(completion)
            }
        }
        return .requested
    }

    private func postKeyboardShortcut(
        keyCode: CGKeyCode,
        flags: CGEventFlags,
        language: AppLanguage
    ) -> Result {
        guard canPostEvents else {
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
        process.terminationHandler = { [weak self] completedProcess in
            let succeeded = completedProcess.terminationReason == .exit && completedProcess.terminationStatus == 0
            let completion = AsyncCompletion(
                operation: .systemCommand,
                succeeded: succeeded,
                diagnosticCode: succeeded ? "completed" : "exit-nonzero"
            )
            Task { @MainActor [weak self] in
                self?.onAsyncCompletion?(completion)
            }
        }
        do {
            try process.run()
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
