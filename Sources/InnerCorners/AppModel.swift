import AppKit
import Combine
import Foundation
import OSLog
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
    private enum BarrierRefreshMode: Int {
        case none = 0
        case geometryChange = 1
        case forcedRestart = 2
    }

    @Published var preferences: Preferences {
        didSet {
            engine.preferences = preferences
            if oldValue.appLanguage != preferences.appLanguage {
                relocalizeState()
            } else if oldValue.isEnabled != preferences.isEnabled {
                updateMonitoringStatus()
            }
            refreshFrontmostSuppressionState()
            refreshBarrier()
            scheduleSave()
        }
    }
    @Published private(set) var displays: [DisplayDescriptor] = []
    @Published var selectedSettingsTab: SettingsTab = .cornersAndLayout
    @Published var selectedDisplayID: String?
    @Published var selectedCorner: Corner = .topLeft
    @Published private(set) var previewBarrierSegments: [BarrierPreviewSegment] = []
    @Published private(set) var lastHitBarrierID: String?
    @Published private(set) var status = "停止中"
    @Published private(set) var pointerStatus = "角の反応領域外"
    @Published private(set) var hoveredZoneID: String?
    @Published private(set) var accessibilityGranted = false
    @Published private(set) var eventPostingGranted = false
    @Published private(set) var cursorControlActive = false
    @Published private(set) var frontmostApplicationName = "不明"
    @Published private(set) var frontmostApplicationBundleID: String?
    @Published private(set) var isFrontmostAppFullscreen = false
    @Published private(set) var isCompanionAppRunning = false
    @Published private(set) var pausedUntil: Date?
    @Published private(set) var barrierStatus = "接合部バリア：停止中"
    @Published private(set) var barrierCount = 0
    @Published private(set) var emergencyHotKeyStatus = "緊急終了キー：未登録"
    @Published private(set) var recentEvents: [String] = []

    private let storageKey = "InnerCorners.preferences.v1"
    private let companionBundleIdentifier = "local.prototype.InnerCorners"
    private let actionLogger = Logger(subsystem: "local.prototype.InnerCorners", category: "Action")
    private let executor = ActionExecutor()
    private let barrierController = CursorBarrierController()
    private let emergencyHotKeyController = EmergencyHotKeyController()
    private lazy var engine = HotCornerEngine(executor: executor)
    private var screenObserver: NSObjectProtocol?
    private var activeObserver: NSObjectProtocol?
    private var terminateObserver: NSObjectProtocol?
    private var workspaceObserver: NSObjectProtocol?
    private var spaceObserver: NSObjectProtocol?
    private var appLaunchObserver: NSObjectProtocol?
    private var appTerminateObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    private var screensWakeObserver: NSObjectProtocol?
    private var sleepObserver: NSObjectProtocol?
    private var screensSleepObserver: NSObjectProtocol?
    private var screenRefreshWorkItem: DispatchWorkItem?
    private var saveWorkItem: DispatchWorkItem?
    private var pauseTimerWorkItem: DispatchWorkItem?
    private var hitHighlightWorkItem: DispatchWorkItem?
    private var screenRefreshGeneration = 0
    private var pendingBarrierRefreshMode = BarrierRefreshMode.none
    private var isSleeping = false
    private var displayConfigurationGate = DisplayConfigurationGate()
    private var isSettingsWindowVisible = false
    private var quartzDisplays: [QuartzDisplayDescriptor] = []
    private var emptyDisplayRetryCount = 0
    private var emergencyHotKeyRegistered = false

    var language: AppLanguage { preferences.appLanguage }

    var suppressionState: AppSuppressionState {
        AppSuppressionPolicy.evaluate(
            now: Date(),
            pausedUntil: pausedUntil,
            frontmostBundleID: frontmostApplicationBundleID,
            isFrontmostFullscreen: isFrontmostAppFullscreen,
            isCompanionAppRunning: isCompanionAppRunning,
            preferences: preferences
        )
    }

    var isTemporarilyPaused: Bool {
        pausedUntil.map { $0 > Date() } ?? false
    }

    var isFrontmostAppExcluded: Bool {
        guard let bundleID = frontmostApplicationBundleID, !bundleID.isEmpty else { return false }
        return preferences.excludedBundleIdentifiers.contains {
            $0.caseInsensitiveCompare(bundleID) == .orderedSame
        }
    }

    func text(ja: String, en: String) -> String {
        L10n.text(language, ja: ja, en: en)
    }

    func cornerTitle(_ corner: Corner) -> String { corner.title(language: language) }
    func actionTitle(_ action: CornerAction) -> String { action.title(language: language) }

    func setLanguage(_ language: AppLanguage) {
        guard preferences.appLanguage != language else { return }
        preferences.appLanguage = language
    }

    func selectCorner(displayID: String, corner: Corner) {
        selectedDisplayID = displayID
        selectedCorner = corner
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(Preferences.self, from: data) {
            preferences = decoded
        } else if let legacyData = UserDefaults(suiteName: "local.prototype.InnerCorners")?.data(forKey: storageKey),
                  let decoded = try? JSONDecoder().decode(Preferences.self, from: legacyData) {
            preferences = decoded
        } else {
            preferences = Preferences()
        }

        engine.onStatus = { [weak self] in self?.status = $0 }
        barrierController.onStatus = { [weak self] message in
            self?.barrierStatus = message
            if ProcessInfo.processInfo.environment["INNERCORNERS_DIAGNOSTICS"] == "1" {
                FileHandle.standardError.write(Data("\(message)\n".utf8))
            }
        }
        barrierController.onBarrierCount = { [weak self] count in
            self?.barrierCount = count
        }
        barrierController.onBarrierHit = { [weak self] barrier in
            guard let self, self.isSettingsWindowVisible else { return }
            if self.lastHitBarrierID != barrier.id {
                self.lastHitBarrierID = barrier.id
            }
            self.hitHighlightWorkItem?.cancel()
            let item = DispatchWorkItem { [weak self] in
                MainActor.assumeIsolated {
                    if self?.lastHitBarrierID == barrier.id {
                        self?.lastHitBarrierID = nil
                    }
                }
            }
            self.hitHighlightWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: item)
        }
        barrierController.onCollision = { [weak self] barrier, sourceDisplayID, modifierFlags in
            self?.performBarrierAction(
                barrier,
                sourceDisplayID: sourceDisplayID,
                modifierFlagsAtCollision: modifierFlags
            )
        }
        barrierController.onSafetyEvent = { [weak self] message in
            guard let self else { return }
            self.recordEvent(self.text(ja: "安全機構：\(message)", en: "Safety: \(message)"))
        }
        barrierController.onEventTapStateChange = { [weak self] active in
            self?.cursorControlActive = active
        }
        engine.onHover = { [weak self] zone in
            self?.hoveredZoneID = zone?.id
            guard let self else { return }
            self.pointerStatus = zone.map {
                self.text(
                    ja: "\($0.displayName)・\($0.corner.title(language: self.language))（キー送信なし）",
                    en: "\($0.displayName) · \($0.corner.title(language: self.language)) (no keystrokes)"
                )
            } ?? self.text(ja: "角の反応領域外", en: "Outside corner activation zones")
        }
        engine.preferences = preferences
        emergencyHotKeyController.onTrigger = { [weak self] in
            self?.performEmergencyQuit()
        }
        emergencyHotKeyRegistered = emergencyHotKeyController.start()
        updateEmergencyHotKeyStatus()
        relocalizeState()
        // Detect the stable RC app before display refresh can create an event
        // tap. Two cursor controllers must never be active at the same time.
        refreshCompanionAppStatus()
        refreshDisplays()
        refreshPermissionStatus()
        refreshFrontmostApplication()
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.handleDisplayChange() }
        }
        activeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.handleApplicationActivation() }
        }
        terminateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.flushSave() }
        }
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshFrontmostApplication() }
        }
        spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshFrontmostApplication() }
        }
        appLaunchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshCompanionAppStatus() }
        }
        appTerminateObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshCompanionAppStatus() }
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleWake()
            }
        }
        screensWakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.handleWake() }
        }
        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.handleSleep() }
        }
        screensSleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.handleSleep() }
        }
    }

    isolated deinit {
        screenRefreshWorkItem?.cancel()
        saveWorkItem?.cancel()
        pauseTimerWorkItem?.cancel()
        hitHighlightWorkItem?.cancel()
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        if let activeObserver { NotificationCenter.default.removeObserver(activeObserver) }
        if let terminateObserver { NotificationCenter.default.removeObserver(terminateObserver) }
        if let workspaceObserver { NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver) }
        if let spaceObserver { NSWorkspace.shared.notificationCenter.removeObserver(spaceObserver) }
        if let appLaunchObserver { NSWorkspace.shared.notificationCenter.removeObserver(appLaunchObserver) }
        if let appTerminateObserver { NSWorkspace.shared.notificationCenter.removeObserver(appTerminateObserver) }
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
        if let screensWakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(screensWakeObserver) }
        if let sleepObserver { NSWorkspace.shared.notificationCenter.removeObserver(sleepObserver) }
        if let screensSleepObserver { NSWorkspace.shared.notificationCenter.removeObserver(screensSleepObserver) }
        barrierController.stop()
        emergencyHotKeyController.stop()
    }

    func setAction(_ action: CornerAction, displayID: String, corner: Corner) {
        preferences.setAction(action, displayID: displayID, corner: corner)
    }

    func setBarrierPolicy(_ policy: CornerBarrierPolicy, displayID: String, corner: Corner) {
        preferences.setBarrierPolicy(policy, displayID: displayID, corner: corner)
    }

    func setModifierRequirement(_ requirement: CornerModifierRequirement, displayID: String, corner: Corner) {
        preferences.setModifierRequirement(requirement, displayID: displayID, corner: corner)
    }

    func setCustomApplicationPath(_ path: String?, displayID: String, corner: Corner) {
        preferences.setCustomApplicationPath(path, displayID: displayID, corner: corner)
    }

    func setCustomShortcutName(_ name: String?, displayID: String, corner: Corner) {
        preferences.setCustomShortcutName(name, displayID: displayID, corner: corner)
    }

    func chooseCustomApplication(displayID: String, corner: Corner) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = text(ja: "選択", en: "Choose")
        if panel.runModal() == .OK, let url = panel.url {
            preferences.setCustomApplicationPath(url.path, displayID: displayID, corner: corner)
        }
    }

    func chooseExcludedApplication() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = text(ja: "除外に追加", en: "Add to Excluded")
        if panel.runModal() == .OK,
           let url = panel.url,
           let bundleID = Bundle(url: url)?.bundleIdentifier {
            addExcludedBundleIdentifier(bundleID)
        }
    }

    func toggleFrontmostAppExclusion() {
        guard let bundleID = frontmostApplicationBundleID, !bundleID.isEmpty else { return }
        if isFrontmostAppExcluded {
            removeExcludedBundleIdentifier(bundleID)
        } else {
            addExcludedBundleIdentifier(bundleID)
        }
    }

    func addExcludedBundleIdentifier(_ bundleID: String) {
        let trimmed = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !preferences.excludedBundleIdentifiers.contains(where: {
            $0.caseInsensitiveCompare(trimmed) == .orderedSame
        }) else { return }
        preferences.excludedBundleIdentifiers.append(trimmed)
    }

    func removeExcludedBundleIdentifier(_ bundleID: String) {
        preferences.excludedBundleIdentifiers.removeAll {
            $0.caseInsensitiveCompare(bundleID) == .orderedSame
        }
    }

    func pauseForMinutes(_ minutes: Double = 5) {
        pauseTimerWorkItem?.cancel()
        let deadline = Date().addingTimeInterval(max(10, minutes * 60))
        pausedUntil = deadline
        refreshFrontmostSuppressionState()
        refreshBarrier()
        recordEvent(text(
            ja: "一時停止：\(Int(minutes))分間バリアとアクションを一時停止しました",
            en: "Temporary pause: paused barriers and actions for \(Int(minutes)) minutes"
        ))
        let item = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                self?.resumeFromTemporaryPause()
            }
        }
        pauseTimerWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + max(10, minutes * 60), execute: item)
    }

    func resumeFromTemporaryPause() {
        pauseTimerWorkItem?.cancel()
        pauseTimerWorkItem = nil
        guard pausedUntil != nil else { return }
        pausedUntil = nil
        refreshFrontmostSuppressionState()
        refreshBarrier()
        recordEvent(text(
            ja: "一時停止を解除しました",
            en: "Resumed from temporary pause"
        ))
    }

    func setSettingsVisible(_ visible: Bool) {
        isSettingsWindowVisible = visible
        engine.setSettingsVisible(visible)
        if visible {
            refreshCompanionAppStatus()
            refreshFrontmostApplication()
        } else {
            hitHighlightWorkItem?.cancel()
            hitHighlightWorkItem = nil
            if lastHitBarrierID != nil {
                lastHitBarrierID = nil
            }
        }
    }

    func terminateCompanionApp() {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: companionBundleIdentifier)
            .filter { $0.processIdentifier != currentPID && !$0.isTerminated }
        for app in apps {
            app.terminate()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            MainActor.assumeIsolated {
                self?.refreshCompanionAppStatus()
            }
        }
        recordEvent(text(
            ja: "競合防止：同時起動していた ChatGPT版 InnerCorners.app に終了を要求しました",
            en: "Conflict prevention: requested termination of concurrently running ChatGPT InnerCorners.app"
        ))
    }

    private func refreshCompanionAppStatus() {
        guard Bundle.main.bundleIdentifier != companionBundleIdentifier else {
            isCompanionAppRunning = false
            return
        }
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: companionBundleIdentifier)
            .contains { $0.processIdentifier != currentPID && !$0.isTerminated }
        if isCompanionAppRunning != running {
            isCompanionAppRunning = running
            refreshFrontmostSuppressionState()
            refreshBarrier()
        }
    }

    func action(displayID: String, corner: Corner) -> CornerAction {
        preferences.action(displayID: displayID, corner: corner)
    }

    func barrierAction(displayID: String, corner: Corner) -> CornerAction {
        preferences.barrierAction(displayID: displayID, corner: corner)
    }

    func barrierPolicy(displayID: String, corner: Corner) -> CornerBarrierPolicy {
        preferences.barrierPolicy(displayID: displayID, corner: corner)
    }

    func modifierRequirement(displayID: String, corner: Corner) -> CornerModifierRequirement {
        preferences.modifierRequirement(displayID: displayID, corner: corner)
    }

    func customApplicationPath(displayID: String, corner: Corner) -> String? {
        preferences.customApplicationPath(displayID: displayID, corner: corner)
    }

    func customShortcutName(displayID: String, corner: Corner) -> String? {
        preferences.customShortcutName(displayID: displayID, corner: corner)
    }

    func effectiveActionDescription(displayID: String, corner: Corner) -> String {
        let assignment = preferences.assignment(displayID: displayID, corner: corner)
        switch assignment.barrierPolicy {
        case .disabled:
            return text(ja: "壁なし（この角は自由に通過できます）", en: "No barrier (pointer passes freely through this corner)")
        case .stopperOnly:
            return text(ja: "ストッパー専用（壁で止まりますがアクションは発火しません）", en: "Stopper only (stops pointer without firing an action)")
        case .enabled:
            break
        }
        let modSuffix = assignment.modifierRequirement == .none
            ? ""
            : text(ja: "（必要キー：\(assignment.modifierRequirement.symbols)）", en: " (requires \(assignment.modifierRequirement.symbols))")
        let action = assignment.action
        if action == .systemHotCorner {
            return "macOS: \(executor.systemHotCornerDescription(for: corner, language: language))\(modSuffix)"
        }
        if action == .openApplication {
            let appName = assignment.customApplicationPath.map { URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent }
                ?? text(ja: "未選択", en: "Not selected")
            return text(ja: "アプリ起動：\(appName)\(modSuffix)", en: "Open App: \(appName)\(modSuffix)")
        }
        if action == .runShortcut {
            let name = (assignment.customShortcutName?.isEmpty == false)
                ? assignment.customShortcutName!
                : text(ja: "未指定", en: "Not specified")
            return text(ja: "ショートカット：\(name)\(modSuffix)", en: "Shortcut: \(name)\(modSuffix)")
        }
        return text(ja: "個別設定：\(actionTitle(action))\(modSuffix)", en: "Custom: \(actionTitle(action))\(modSuffix)")
    }

    func shortCornerBadge(displayID: String, corner: Corner) -> String {
        let assignment = preferences.assignment(displayID: displayID, corner: corner)
        switch assignment.barrierPolicy {
        case .disabled:
            return text(ja: "通過", en: "Pass")
        case .stopperOnly:
            return text(ja: "壁のみ", en: "Stop")
        case .enabled:
            let prefix = assignment.modifierRequirement == .none ? "" : "\(assignment.modifierRequirement.symbols)"
            let action = assignment.action
            if action == .systemHotCorner {
                return "\(prefix)\(executor.systemHotCornerDescription(for: corner, language: language))"
            }
            return "\(prefix)\(actionTitle(action))"
        }
    }

    var versionDescription: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? text(ja: "不明", en: "Unknown")
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? text(ja: "不明", en: "Unknown")
        return "\(version) (\(build))"
    }

    func clearDiagnostics() {
        recentEvents.removeAll()
        status = text(ja: "診断履歴を消去しました", en: "Diagnostic history cleared")
    }

    func copyDiagnostics() {
        var lines = [
            "InnerCorners Gemini Edition \(versionDescription)",
            ProcessInfo.processInfo.operatingSystemVersionString,
            "accessibility=\(accessibilityGranted)",
            "eventPosting=\(eventPostingGranted)",
            "eventTapActive=\(cursorControlActive)",
            "displayConfigurationValid=\(displayConfigurationGate.isValid)",
            "barrierEnabled=\(preferences.barrierEnabled) barrierCount=\(barrierCount) length=\(Int(preferences.barrierLength)) mode=\(preferences.passThroughMode.rawValue)",
            "paused=\(isTemporarilyPaused) fullscreenApp=\(isFrontmostAppFullscreen) excludedApp=\(isFrontmostAppExcluded)",
            "displays=\(displays.count)"
        ]
        lines.append(contentsOf: displays.map {
            "display \($0.displayNumber) \($0.name) id=\($0.id) frame=\($0.frame)"
        })
        lines.append("recent events:")
        lines.append(contentsOf: recentEvents)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lines.joined(separator: "\n"), forType: .string)
        status = text(ja: "診断情報をクリップボードへコピーしました", en: "Diagnostics copied to the clipboard")
    }

    func requestAccessibilityPermission() {
        executor.requestAccessibilityPermission()
        refreshPermissionStatus()
    }

    func runTestSound() {
        guard let display = displays.first else {
            status = text(ja: "画面を取得できないためテストできません", en: "Cannot test because no display is available")
            return
        }
        let zone = HotZone(
            displayID: display.id,
            displayName: display.name,
            corner: .topLeft,
            rect: .zero
        )
        switch executor.perform(.testNotification, zone: zone, language: language) {
        case .performed:
            status = text(ja: "テスト音を実行しました（キー送信なし）", en: "Test sound played (no keystrokes)")
        case .requested:
            status = text(ja: "予期せず非同期の実行要求になりました", en: "The test unexpectedly returned an asynchronous action request")
        case .permissionRequired:
            status = text(ja: "予期せず権限が必要と判定されました", en: "Permission was unexpectedly reported as required")
        case .unsupported(let reason):
            status = text(ja: "予期せず未対応と判定されました：\(reason)", en: "The test unexpectedly reported an unsupported action: \(reason)")
        case .failed(let reason):
            status = text(ja: "テストの実行に失敗しました：\(reason)", en: "The test failed: \(reason)")
        case .skipped(let reason):
            status = reason
        }
    }

    private func performEmergencyQuit() {
        preferences.barrierEnabled = false
        flushSave()
        UserDefaults.standard.synchronize()
        barrierStatus = text(ja: "接合部バリア：緊急停止", en: "Junction Barrier: Emergency stop")
        NSApplication.shared.terminate(nil)
    }

    private func refreshDisplays(quartz: [QuartzDisplayDescriptor]? = nil) {
        displays = DisplayProvider.current()
        if selectedDisplayID == nil || !displays.contains(where: { $0.id == selectedDisplayID }) {
            selectedDisplayID = displays.first?.id
        }
        engine.displays = displays
        let resolvedQuartz = quartz ?? DisplayProvider.currentQuartz()
        if !resolvedQuartz.isEmpty {
            quartzDisplays = resolvedQuartz
            displayConfigurationGate.acceptUsableConfiguration()
        } else if quartzDisplays.isEmpty {
            displayConfigurationGate.invalidate()
        }
        refreshFrontmostSuppressionState()
        refreshBarrier()
        updateMonitoringStatus()
    }

    private func scheduleDisplayRefresh(
        after delay: TimeInterval = 0.35,
        mode: BarrierRefreshMode = .none
    ) {
        if mode.rawValue > pendingBarrierRefreshMode.rawValue {
            pendingBarrierRefreshMode = mode
        }
        screenRefreshWorkItem?.cancel()
        screenRefreshGeneration += 1
        let generation = screenRefreshGeneration
        let item = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                guard self.screenRefreshGeneration == generation, !self.isSleeping else { return }
                self.screenRefreshWorkItem = nil
                let refreshMode = self.pendingBarrierRefreshMode
                self.pendingBarrierRefreshMode = .none
                let newQuartz = DisplayProvider.currentQuartz()
                guard !newQuartz.isEmpty else {
                    self.displayConfigurationGate.invalidate()
                    self.barrierController.stop(preservingSafetyState: true)
                    self.barrierCount = 0
                    self.barrierStatus = self.text(ja: "接合部バリア：画面構成の取得待ち（安全停止）", en: "Junction Barrier: Waiting for display configuration (safe stop)")
                    if self.emptyDisplayRetryCount < 10 {
                        self.emptyDisplayRetryCount += 1
                        self.scheduleDisplayRefresh(after: 0.5, mode: refreshMode)
                    }
                    return
                }
                self.emptyDisplayRetryCount = 0
                switch refreshMode {
                case .forcedRestart:
                    self.barrierController.stop(preservingSafetyState: true)
                case .geometryChange:
                    if !CursorBarrierGeometry.sameDisplayConfiguration(self.quartzDisplays, newQuartz) {
                        self.engine.prepareForDisplayChange()
                        if self.preferences.barrierEnabled {
                            self.barrierController.prepareForDisplayChange()
                            self.barrierController.stop(preservingSafetyState: true)
                        }
                    }
                case .none:
                    break
                }
                self.refreshDisplays(quartz: newQuartz)
            }
        }
        screenRefreshWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func handleWake() {
        guard isSleeping else { return }
        isSleeping = false
        engine.prepareForWake()
        guard preferences.barrierEnabled else {
            scheduleDisplayRefresh(after: 1.0)
            return
        }
        barrierController.prepareForWake()
        scheduleDisplayRefresh(after: 1.0, mode: .forcedRestart)
    }

    private func handleApplicationActivation() {
        refreshPermissionStatus()
        refreshCompanionAppStatus()
        if isSleeping {
            recordEvent(text(
                ja: "安全機構：アプリの前面化を確認し、スリープ状態から安全に復旧します",
                en: "Safety: App activation confirmed; safely recovering from the sleeping state"
            ))
            handleWake()
            return
        }
        if preferences.barrierEnabled && !cursorControlActive && !suppressionState.shouldSuppressBarriers {
            refreshBarrier()
        }
    }

    private func handleDisplayChange() {
        guard !isSleeping else { return }
        scheduleDisplayRefresh(mode: .geometryChange)
    }

    private func handleSleep() {
        guard !isSleeping else { return }
        isSleeping = true
        screenRefreshWorkItem?.cancel()
        screenRefreshWorkItem = nil
        screenRefreshGeneration += 1
        pendingBarrierRefreshMode = .none
        flushSave()
        engine.suspendForSleep()
        barrierController.stop()
        barrierCount = 0
        barrierStatus = text(ja: "接合部バリア：画面スリープ中（安全停止）", en: "Junction Barrier: Displays asleep (safe stop)")
        recordEvent(text(ja: "安全機構：画面スリープ前にバリアを停止しました", en: "Safety: Barrier stopped before display sleep"))
    }

    private func scheduleSave() {
        saveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                self?.flushSave()
            }
        }
        saveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: item)
    }

    private func flushSave() {
        saveWorkItem?.cancel()
        saveWorkItem = nil
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func refreshPermissionStatus() {
        let capabilities = executor.permissionCapabilities
        accessibilityGranted = capabilities.accessibilityAPI
        eventPostingGranted = capabilities.eventPosting
    }

    private func refreshFrontmostApplication() {
        let app = NSWorkspace.shared.frontmostApplication
        frontmostApplicationName = app?.localizedName ?? text(ja: "不明", en: "Unknown")
        frontmostApplicationBundleID = app?.bundleIdentifier
        if (preferences.pauseInFullscreenApps || isSettingsWindowVisible), let pid = app?.processIdentifier {
            let activeQuartz = quartzDisplays.isEmpty ? DisplayProvider.currentQuartz() : quartzDisplays
            isFrontmostAppFullscreen = AppSuppressionPolicy.isProcessFullscreen(pid: pid, displays: activeQuartz)
        } else if !preferences.pauseInFullscreenApps {
            isFrontmostAppFullscreen = false
        }
        let previousBarrierSuppression = engine.isSuppressedByContext
        refreshFrontmostSuppressionState()
        if previousBarrierSuppression != engine.isSuppressedByContext || preferences.suppressionScope == .barriersAndActions {
            refreshBarrier()
        }
    }

    private func refreshFrontmostSuppressionState() {
        let state = suppressionState
        engine.isSuppressedByContext = state.shouldSuppressActions
    }

    private func performBarrierAction(
        _ barrier: CursorBarrier,
        sourceDisplayID: UInt32,
        modifierFlagsAtCollision: CGEventFlags
    ) {
        if suppressionState.shouldSuppressActions {
            status = text(
                ja: "一時停止または除外条件によりアクションを抑制しました",
                en: "Action suppressed by temporary pause or active app rule"
            )
            return
        }
        guard let display = displays.first(where: { $0.displayNumber == barrier.displayID }) else {
            status = text(ja: "壁に対応する画面設定を取得できません", en: "Could not find display settings for the barrier")
            logBarrierAction(
                sourceDisplayID: sourceDisplayID,
                targetDisplayID: barrier.displayID,
                corner: barrier.corner,
                action: "unresolved",
                result: "display-not-found"
            )
            diagnostic("Barrier action: display \(barrier.displayID) not found")
            recordEvent(text(ja: "画面\(sourceDisplayID) → 不明な壁\(barrier.displayID)", en: "Display \(sourceDisplayID) → unknown barrier \(barrier.displayID)"))
            return
        }
        let sourceName = displays.first(where: { $0.displayNumber == sourceDisplayID })?.name
            ?? text(ja: "画面\(sourceDisplayID)", en: "Display \(sourceDisplayID)")
        let assignment = preferences.assignment(displayID: display.id, corner: barrier.corner)
        let action = assignment.action
        diagnostic("Barrier action: \(display.name) \(barrier.corner.rawValue) -> \(action.rawValue)")
        let zone = HotZone(
            displayID: display.id,
            displayName: display.name,
            corner: barrier.corner,
            rect: .zero
        )
        let corner = cornerTitle(barrier.corner)
        let actionName = actionTitle(action)
        let loggedAction = action == .systemHotCorner
            ? executor.systemHotCornerDescription(for: barrier.corner, language: .english)
            : action.rawValue
        let executionResult = executor.perform(
            action,
            assignment: assignment,
            zone: zone,
            modifierFlagsAtTrigger: modifierFlagsAtCollision,
            language: language
        )
        switch executionResult {
        case .performed:
            status = text(ja: "\(display.name)・\(corner)：\(actionName)を実行", en: "\(display.name) · \(corner): Ran \(actionName)")
            recordEvent("\(sourceName) → \(display.name) · \(corner): \(actionName)")
            diagnostic("Barrier action result: performed")
        case .requested:
            status = text(ja: "\(display.name)・\(corner)：\(actionName)の実行を要求", en: "\(display.name) · \(corner): Requested \(actionName)")
            recordEvent(text(
                ja: "\(sourceName) → \(display.name)・\(corner)：\(actionName)（実行要求）",
                en: "\(sourceName) → \(display.name) · \(corner): \(actionName) (action requested)"
            ))
            diagnostic("Barrier action result: action requested")
        case .permissionRequired:
            status = text(ja: "アクセシビリティ権限が必要です", en: "Accessibility permission is required")
            recordEvent(text(ja: "\(sourceName) → \(display.name)・\(corner)：権限不足", en: "\(sourceName) → \(display.name) · \(corner): Permission required"))
            diagnostic("Barrier action result: permission required")
        case .unsupported(let reason):
            status = "\(display.name) · \(corner): \(reason)"
            recordEvent(text(
                ja: "\(sourceName) → \(display.name)・\(corner)：未対応（\(reason)）",
                en: "\(sourceName) → \(display.name) · \(corner): Unsupported (\(reason))"
            ))
            diagnostic("Barrier action result: unsupported - \(reason)")
        case .failed(let reason):
            status = text(
                ja: "\(display.name)・\(corner)：実行失敗（\(reason)）",
                en: "\(display.name) · \(corner): Action failed (\(reason))"
            )
            recordEvent(text(
                ja: "\(sourceName) → \(display.name)・\(corner)：実行失敗（\(reason)）",
                en: "\(sourceName) → \(display.name) · \(corner): Action failed (\(reason))"
            ))
            diagnostic("Barrier action result: failed - \(reason)")
        case .skipped(let reason):
            status = "\(display.name) · \(corner): \(reason)"
            recordEvent("\(sourceName) → \(display.name) · \(corner): \(reason)")
            diagnostic("Barrier action result: skipped - \(reason)")
        }
        logBarrierAction(
            sourceDisplayID: sourceDisplayID,
            targetDisplayID: barrier.displayID,
            corner: barrier.corner,
            action: loggedAction,
            result: executionResult.diagnosticCode
        )
    }

    private func logBarrierAction(
        sourceDisplayID: UInt32,
        targetDisplayID: UInt32,
        corner: Corner,
        action: String,
        result: String
    ) {
        actionLogger.notice(
            "trigger=barrier sourceDisplay=\(sourceDisplayID) targetDisplay=\(targetDisplayID) corner=\(corner.rawValue, privacy: .public) action=\(action, privacy: .public) result=\(result, privacy: .public)"
        )
    }

    private func recordEvent(_ message: String) {
        let time = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        recentEvents.insert("[\(time)] \(message)", at: 0)
        if recentEvents.count > 20 {
            recentEvents.removeLast(recentEvents.count - 20)
        }
    }

    private func diagnostic(_ message: String) {
        guard ProcessInfo.processInfo.environment["INNERCORNERS_DIAGNOSTICS"] == "1" else { return }
        FileHandle.standardError.write(Data("\(message)\n".utf8))
    }

    private func refreshBarrier() {
        guard !isSleeping else { return }
        guard displayConfigurationGate.isValid, !quartzDisplays.isEmpty else {
            engine.suppressedZoneIDs = []
            barrierController.stop(preservingSafetyState: true)
            barrierCount = 0
            barrierStatus = text(
                ja: "接合部バリア：画面構成の取得待ち（安全停止）",
                en: "Junction Barrier: Waiting for display configuration (safe stop)"
            )
            return
        }
        let activeQuartzDisplays = quartzDisplays
        let allStructuralBarriers = CursorBarrierGeometry.barriers(
            for: activeQuartzDisplays,
            length: preferences.barrierLength
        )
        previewBarrierSegments = HotZoneGeometry.previewSegments(
            displays: displays,
            allBarriers: allStructuralBarriers,
            length: preferences.barrierLength,
            preferences: preferences
        )
        let disabledCornerKeys = HotZoneGeometry.disabledQuartzCornerKeys(
            displays: displays,
            preferences: preferences
        )
        let activeBarriers = allStructuralBarriers.filter { !disabledCornerKeys.contains($0.cornerKey) }
        let internalZoneIDs = HotZoneGeometry.zoneIDsCoveredByBarriers(
            displays: displays,
            barriers: activeBarriers
        )
        let state = suppressionState
        let effectiveBarrierEnabled = preferences.barrierEnabled && !state.shouldSuppressBarriers
        engine.internalZoneIDs = internalZoneIDs
        engine.suppressedZoneIDs = effectiveBarrierEnabled ? internalZoneIDs : []
        barrierController.update(
            enabled: effectiveBarrierEnabled,
            length: preferences.barrierLength,
            displays: activeQuartzDisplays,
            disabledCornerKeys: disabledCornerKeys,
            passThroughMode: preferences.passThroughMode,
            speedBumpHoldMilliseconds: preferences.speedBumpHoldMilliseconds,
            preserveSafetyStateWhenDisabled: state.shouldPreserveBarrierSafetyState(
                whenBarrierIsEnabled: preferences.barrierEnabled
            ),
            language: language
        )
        if preferences.barrierEnabled && state.shouldSuppressBarriers {
            if state.isCompanionAppRunning {
                barrierStatus = text(
                    ja: "接合部バリア：別バージョンの起動中（競合防止停止）",
                    en: "Junction Barrier: Another version is running (conflict-safe stop)"
                )
            } else if state.isPausedByTimer {
                barrierStatus = text(
                    ja: "接合部バリア：一時停止中",
                    en: "Junction Barrier: Temporarily paused"
                )
            } else {
                barrierStatus = text(
                    ja: "接合部バリア：除外/フルスクリーン条件により一時停止中",
                    en: "Junction Barrier: Paused for excluded/fullscreen app"
                )
            }
        }
    }

    private func updateEmergencyHotKeyStatus() {
        emergencyHotKeyStatus = emergencyHotKeyRegistered
            ? text(ja: "緊急終了キー：⌃⌥⌘Q（登録済み）", en: "Emergency Quit: ⌃⌥⌘Q (registered)")
            : text(ja: "緊急終了キー：登録失敗（⌘Tab → ⌘Qを使用）", en: "Emergency Quit: Registration failed (use ⌘Tab → ⌘Q)")
    }

    private func relocalizeState() {
        updateEmergencyHotKeyStatus()
        pointerStatus = text(ja: "角の反応領域外", en: "Outside corner activation zones")
        if frontmostApplicationName == "不明" || frontmostApplicationName == "Unknown" {
            frontmostApplicationName = text(ja: "不明", en: "Unknown")
        }
        updateMonitoringStatus()
    }

    private func updateMonitoringStatus() {
        status = preferences.isEnabled
            ? text(ja: "監視中（\(displays.count)画面）", en: "Monitoring (\(displays.count) displays)")
            : text(ja: "停止中", en: "Stopped")
    }
}
