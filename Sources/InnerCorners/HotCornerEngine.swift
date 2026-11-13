import AppKit
import Foundation

@MainActor
final class HotCornerEngine {
    private let executor: ActionExecutor
    private var timer: Timer?
    private var zones: [HotZone] = []
    private var activationGate = ActivationGate()
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
        guard preferences.isEnabled else {
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
        switch executor.perform(action, zone: current, language: language) {
        case .performed:
            onStatus?("\(current.displayName) · \(current.corner.title(language: language)): \(action.title(language: language))")
        case .requested:
            onStatus?(L10n.text(
                language,
                ja: "\(current.displayName)・\(current.corner.title(language: language))：\(action.title(language: language))の起動を要求",
                en: "\(current.displayName) · \(current.corner.title(language: language)): Requested \(action.title(language: language))"
            ))
        case .permissionRequired:
            onStatus?(L10n.text(language, ja: "アクセシビリティ権限が必要です", en: "Accessibility permission is required"))
        case .skipped(let reason):
            onStatus?(reason)
        }
    }
}
