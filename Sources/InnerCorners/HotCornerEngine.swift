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
        didSet {
            guard !HotZoneGeometry.sameDisplayConfiguration(oldValue, displays) else { return }
            rebuildZones()
        }
    }
    var suppressedZoneIDs: Set<String> = [] {
        didSet {
            guard oldValue != suppressedZoneIDs else { return }
            activationGate.reset()
        }
    }
    var isSuppressedByContext = false {
        didSet {
            guard oldValue != isSuppressedByContext else { return }
            activationGate.reset()
        }
    }
    var internalZoneIDs: Set<String> = []
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
        let timer = Timer(timeInterval: 0.02, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sample() }
        }
        timer.tolerance = 0.005
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

        let actionableCurrent = current.flatMap { suppressedZoneIDs.contains($0.id) ? nil : $0 }

        switch safetyGate.decision(now: now, isOutsideActivationZone: actionableCurrent == nil) {
        case .active:
            break
        case .bypassing, .rearmed:
            activationGate.reset()
            return
        }
        guard preferences.isEnabled, !isSuppressedByContext else {
            activationGate.reset()
            return
        }

        guard !CGEventSource.flagsState(.combinedSessionState).contains(.maskAlternate) else {
            activationGate.reset()
            return
        }

        guard NSEvent.pressedMouseButtons == 0 else {
            activationGate.reset()
            return
        }

        let dwell = preferences.dwellMilliseconds / 1_000
        guard let firedID = activationGate.update(zoneID: actionableCurrent?.id, now: now, dwell: dwell),
              let current = actionableCurrent, current.id == firedID else { return }
        let assignment = preferences.assignment(displayID: current.displayID, corner: current.corner)
        guard assignment.barrierPolicy != .disabled else { return }
        let action = assignment.action
        guard HotZoneGeometry.shouldExecuteCustomAction(
            action,
            zoneID: current.id,
            internalZoneIDs: internalZoneIDs
        ) else { return }
        let language = preferences.appLanguage
        let executionResult = executor.perform(action, assignment: assignment, zone: current, language: language)
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
