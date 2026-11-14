import AppKit
import CoreGraphics
import Foundation
import OSLog

@MainActor
final class HotCornerEngine {
    private let actionLogger = Logger(subsystem: "local.prototype.InnerCorners", category: "Action")
    private let executor: ActionExecutor
    private var timer: Timer?
    private var zones: [HotZone] = []
    private var activationGate = ActivationGate()
    private var safetyGate = ActivationSafetyGate()
    private var lastHoverZoneID: String?
    private var isSettingsVisible = false

    var preferences: Preferences = .init() {
        didSet {
            rebuildZones()
            reconcilePollingState()
        }
    }
    var displays: [DisplayDescriptor] = [] {
        didSet { rebuildZones() }
    }
    var onStatus: ((String) -> Void)?
    var onHover: ((HotZone?) -> Void)?

    init(executor: ActionExecutor) {
        self.executor = executor
    }

    func setSettingsVisible(_ visible: Bool) {
        isSettingsVisible = visible
        reconcilePollingState()
    }

    func suspendForSleep() {
        safetyGate.suspend()
        activationGate.reset()
    }

    func prepareForWake(delay: TimeInterval = 5) {
        safetyGate.prepareForRearm(now: ProcessInfo.processInfo.systemUptime, delay: delay)
        activationGate.reset()
    }

    func prepareForDisplayChange(delay: TimeInterval = 5) {
        safetyGate.prepareForRearm(now: ProcessInfo.processInfo.systemUptime, delay: delay)
        activationGate.reset()
    }

    private func reconcilePollingState() {
        if preferences.isEnabled || isSettingsVisible {
            start()
        } else {
            stop()
        }
    }

    private func start() {
        guard timer == nil else { return }
        // 50 Hz is responsive for a 0–500 ms dwell while remaining trivial work per tick.
        let timer = Timer(timeInterval: 0.02, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sample() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
        reset()
        if lastHoverZoneID != nil {
            lastHoverZoneID = nil
            onHover?(nil)
        }
    }

    private func rebuildZones() {
        zones = HotZoneGeometry.zones(for: displays, size: preferences.zoneSize)
        reset()
    }

    private func reset() {
        activationGate.reset()
    }

    private func sample(now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        let current = HotZoneGeometry.zone(at: NSEvent.mouseLocation, zones: zones)
        if current?.id != lastHoverZoneID {
            lastHoverZoneID = current?.id
            onHover?(current)
        }

        switch safetyGate.decision(now: now, isOutsideActivationZone: current == nil) {
        case .active:
            break
        case .bypassing, .rearmed:
            activationGate.reset()
            return
        }
        guard preferences.isEnabled else {
            activationGate.reset()
            return
        }

        // Option is the emergency escape for the cursor barrier. Suppress the
        // companion action too, so bypassing a corner never launches anything.
        guard !CGEventSource.flagsState(.combinedSessionState).contains(.maskAlternate) else {
            activationGate.reset()
            return
        }

        // Dragging a window or file into a corner is common and should never trigger an action.
        guard NSEvent.pressedMouseButtons == 0 else {
            activationGate.reset()
            return
        }

        let dwell = preferences.dwellMilliseconds / 1_000
        guard let firedID = activationGate.update(zoneID: current?.id, now: now, dwell: dwell),
              let current, current.id == firedID else { return }
        let action = preferences.action(displayID: current.displayID, corner: current.corner)
        let language = preferences.appLanguage
        let executionResult = executor.perform(action, zone: current, language: language)
        switch executionResult {
        case .performed:
            onStatus?("\(current.displayName) · \(current.corner.title(language: language)): \(action.title(language: language))")
        case .requested:
            onStatus?(L10n.text(
                language,
                ja: "\(current.displayName)・\(current.corner.title(language: language))：\(action.title(language: language))の実行を要求",
                en: "\(current.displayName) · \(current.corner.title(language: language)): Requested \(action.title(language: language))"
            ))
        case .permissionRequired:
            onStatus?(L10n.text(language, ja: "アクセシビリティ権限が必要です", en: "Accessibility permission is required"))
        case .unsupported(let reason):
            onStatus?(reason)
        case .failed(let reason):
            onStatus?(L10n.text(language, ja: "実行失敗：\(reason)", en: "Action failed: \(reason)"))
        case .skipped(let reason):
            onStatus?(reason)
        }
        let displayNumber = displays.first(where: { $0.id == current.displayID })?.displayNumber ?? 0
        let loggedAction = action == .systemHotCorner
            ? executor.systemHotCornerDescription(for: current.corner, language: .english)
            : action.rawValue
        actionLogger.notice(
            "trigger=zone sourceDisplay=\(displayNumber) targetDisplay=\(displayNumber) corner=\(current.corner.rawValue, privacy: .public) action=\(loggedAction, privacy: .public) result=\(executionResult.diagnosticCode, privacy: .public)"
        )
    }
}
