import AppKit
import Combine
import Foundation
import OSLog

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
            }
            refreshBarrier()
            save()
        }
    }
    @Published private(set) var displays: [DisplayDescriptor] = []
    @Published private(set) var status = "停止中"
    @Published private(set) var pointerStatus = "角の反応領域外"
    @Published private(set) var hoveredZoneID: String?
    @Published private(set) var accessibilityGranted = false
    @Published private(set) var cursorControlActive = false
    @Published private(set) var frontmostApplicationName = "不明"
    @Published private(set) var barrierStatus = "接合部バリア：停止中"
    @Published private(set) var barrierCount = 0
    @Published private(set) var emergencyHotKeyStatus = "緊急終了キー：未登録"
    @Published private(set) var recentEvents: [String] = []

    private let storageKey = "InnerCorners.preferences.v1"
    private let actionLogger = Logger(subsystem: "local.prototype.InnerCorners", category: "Action")
    private let executor = ActionExecutor()
    private let barrierController = CursorBarrierController()
    private let emergencyHotKeyController = EmergencyHotKeyController()
    private lazy var engine = HotCornerEngine(executor: executor)
    private var screenObserver: NSObjectProtocol?
    private var activeObserver: NSObjectProtocol?
    private var workspaceObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    private var screensWakeObserver: NSObjectProtocol?
    private var sleepObserver: NSObjectProtocol?
    private var screensSleepObserver: NSObjectProtocol?
    private var screenRefreshWorkItem: DispatchWorkItem?
    private var screenRefreshGeneration = 0
    private var pendingBarrierRefreshMode = BarrierRefreshMode.none
    private var isSleeping = false
    private var quartzDisplays: [QuartzDisplayDescriptor] = []
    private var emptyDisplayRetryCount = 0
    private var emergencyHotKeyRegistered = false

    var language: AppLanguage { preferences.appLanguage }

    func text(ja: String, en: String) -> String {
        L10n.text(language, ja: ja, en: en)
    }

    func cornerTitle(_ corner: Corner) -> String { corner.title(language: language) }
    func actionTitle(_ action: CornerAction) -> String { action.title(language: language) }

    func setLanguage(_ language: AppLanguage) {
        guard preferences.appLanguage != language else { return }
        preferences.appLanguage = language
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(Preferences.self, from: data) {
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
        barrierController.onCollision = { [weak self] barrier, sourceDisplayID in
            self?.performBarrierAction(barrier, sourceDisplayID: sourceDisplayID)
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
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshFrontmostApplication() }
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
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        if let activeObserver { NotificationCenter.default.removeObserver(activeObserver) }
        if let workspaceObserver { NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver) }
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

    func setSettingsVisible(_ visible: Bool) {
        engine.setSettingsVisible(visible)
    }

    func action(displayID: String, corner: Corner) -> CornerAction {
        preferences.action(displayID: displayID, corner: corner)
    }

    func barrierAction(displayID: String, corner: Corner) -> CornerAction {
        preferences.barrierAction(displayID: displayID, corner: corner)
    }

    func effectiveActionDescription(displayID: String, corner: Corner) -> String {
        let action = preferences.barrierAction(displayID: displayID, corner: corner)
        if action == .systemHotCorner {
            return "macOS: \(executor.systemHotCornerDescription(for: corner, language: language))"
        }
        return text(ja: "個別設定：\(actionTitle(action))", en: "Custom: \(actionTitle(action))")
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
            "InnerCorners \(versionDescription)",
            ProcessInfo.processInfo.operatingSystemVersionString,
            "accessibility=\(accessibilityGranted)",
            "eventTapActive=\(cursorControlActive)",
            "barrierEnabled=\(preferences.barrierEnabled) barrierCount=\(barrierCount) length=\(Int(preferences.barrierLength))",
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
        UserDefaults.standard.synchronize()
        barrierStatus = text(ja: "接合部バリア：緊急停止", en: "Junction Barrier: Emergency stop")
        NSApplication.shared.terminate(nil)
    }

    private func refreshDisplays(quartz: [QuartzDisplayDescriptor]? = nil) {
        displays = DisplayProvider.current()
        engine.displays = displays
        let resolvedQuartz = quartz ?? DisplayProvider.currentQuartz()
        if !resolvedQuartz.isEmpty {
            quartzDisplays = resolvedQuartz
        }
        refreshBarrier()
        status = preferences.isEnabled
            ? text(ja: "監視中（\(displays.count)画面）", en: "Monitoring (\(displays.count) displays)")
            : text(ja: "停止中", en: "Stopped")
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
                        self.barrierController.prepareForDisplayChange()
                        self.barrierController.stop(preservingSafetyState: true)
                    }
                case .none:
                    break
                }
                self.refreshDisplays(quartz: newQuartz)
            }
        }
        screenRefreshWorkItem = item
        // Mission Control can emit several transient screen-parameter states.
        // Apply only the settled layout so the wall set and latch do not flicker.
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func handleWake() {
        guard isSleeping else { return }
        isSleeping = false
        guard preferences.barrierEnabled else {
            scheduleDisplayRefresh(after: 1.0)
            return
        }
        // Apply the bypass immediately to the existing tap; the delayed refresh
        // then destroys and recreates the tap while preserving the safe rearm.
        barrierController.prepareForWake()
        scheduleDisplayRefresh(after: 1.0, mode: .forcedRestart)
    }

    private func handleApplicationActivation() {
        refreshPermissionStatus()
        if isSleeping {
            recordEvent(text(
                ja: "安全機構：アプリの前面化を確認し、スリープ状態から安全に復旧します",
                en: "Safety: App activation confirmed; safely recovering from the sleeping state"
            ))
            handleWake()
            return
        }
        if preferences.barrierEnabled && !cursorControlActive {
            refreshBarrier()
        }
    }

    private func handleDisplayChange() {
        guard !isSleeping else { return }
        guard preferences.barrierEnabled else {
            scheduleDisplayRefresh()
            return
        }
        // Mission Control and App Exposé temporarily report an empty or
        // transitional display list. Do not pause from the notification-time
        // snapshot: doing so opens a pass-through gap immediately after the
        // hot-corner action. The settled refresh compares the real ID/frame
        // configuration and enters the safe rearm only if it truly changed.
        scheduleDisplayRefresh(mode: .geometryChange)
    }

    private func handleSleep() {
        guard !isSleeping else { return }
        isSleeping = true
        screenRefreshWorkItem?.cancel()
        screenRefreshWorkItem = nil
        screenRefreshGeneration += 1
        pendingBarrierRefreshMode = .none
        barrierController.stop()
        barrierCount = 0
        barrierStatus = text(ja: "接合部バリア：画面スリープ中（安全停止）", en: "Junction Barrier: Displays asleep (safe stop)")
        recordEvent(text(ja: "安全機構：画面スリープ前にバリアを停止しました", en: "Safety: Barrier stopped before display sleep"))
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func refreshPermissionStatus() {
        accessibilityGranted = executor.isAccessibilityGranted
    }

    private func refreshFrontmostApplication() {
        frontmostApplicationName = NSWorkspace.shared.frontmostApplication?.localizedName ?? text(ja: "不明", en: "Unknown")
    }

    private func performBarrierAction(_ barrier: CursorBarrier, sourceDisplayID: UInt32) {
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
        let action = preferences.barrierAction(displayID: display.id, corner: barrier.corner)
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
        let executionResult = executor.perform(action, zone: zone, language: language)
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
        barrierController.update(
            enabled: preferences.barrierEnabled,
            length: preferences.barrierLength,
            displays: quartzDisplays.isEmpty ? DisplayProvider.currentQuartz() : quartzDisplays,
            language: language
        )
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
        status = preferences.isEnabled
            ? text(ja: "監視中（\(displays.count)画面）", en: "Monitoring (\(displays.count) displays)")
            : text(ja: "停止中", en: "Stopped")
    }
}
