@preconcurrency import CoreGraphics
import Foundation
import OSLog

private let cursorBarrierCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let controller = Unmanaged<CursorBarrierController>.fromOpaque(userInfo).takeUnretainedValue()
    return MainActor.assumeIsolated {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            controller.reenableTap()
            return Unmanaged.passUnretained(event)
        }
        controller.filter(event: event, type: type)
        return Unmanaged.passUnretained(event)
    }
}

@MainActor
final class CursorBarrierController {
    private let logger = Logger(subsystem: "local.prototype.InnerCorners", category: "CursorBarrier")
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var displays: [QuartzDisplayDescriptor] = []
    private var barriers: [CursorBarrier] = []
    private var previousLocation: CGPoint?
    private var warpCount = 0
    private var latchedBarrier: CursorBarrier?
    private var cooldownBarrier: CursorBarrier?
    private var cooldownUntil: TimeInterval = 0
    private var approachDisplayID: UInt32?
    private var reactivationGate = CollisionReactivationGate()
    private var safetyGate = BarrierSafetyGate()
    private var safetyStatusMessage: String?
    private(set) var isEventTapActive = false
    private var language: AppLanguage = .japanese
    // The combined session source owns the suppression policy used by cursor
    // warps. Retain it for the lifetime of the controller.
    private let warpEventSource: CGEventSource?
    private let collisionCooldown: TimeInterval = 1.0
    private let wakeRearmDelay: TimeInterval = 5.0

    var onStatus: ((String) -> Void)?
    var onBarrierCount: ((Int) -> Void)?
    var onCollision: ((CursorBarrier, UInt32) -> Void)?
    var onSafetyEvent: ((String) -> Void)?
    var onEventTapStateChange: ((Bool) -> Void)?

    init() {
        let source = CGEventSource(stateID: .combinedSessionState)
        source?.localEventsSuppressionInterval = 0
        warpEventSource = source
    }

    isolated deinit {
        stop()
    }

    func update(
        enabled: Bool,
        length: CGFloat,
        displays: [QuartzDisplayDescriptor],
        language: AppLanguage
    ) {
        self.language = language
        if enabled {
            // Mission Control transitions can briefly report no active displays.
            // Keep the last valid wall set instead of dropping and rearming it.
            if !displays.isEmpty {
                self.displays = displays
                barriers = CursorBarrierGeometry.barriers(for: displays, length: length)
                if let id = approachDisplayID, !displays.contains(where: { $0.id == id }) {
                    approachDisplayID = nil
                }
            }
            synchronizePointerState()
            onBarrierCount?(barriers.count)
            start()
        } else {
            stop()
            onBarrierCount?(0)
            onStatus?(barrierStatus(L10n.text(language, ja: "停止中", en: "Stopped")))
        }
    }

    func stop(preservingSafetyState: Bool = false) {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap { CFMachPortInvalidate(tap) }
        source = nil
        tap = nil
        setEventTapActive(false)
        previousLocation = nil
        latchedBarrier = nil
        cooldownBarrier = nil
        cooldownUntil = 0
        approachDisplayID = nil
        reactivationGate.reset()
        if !preservingSafetyState {
            safetyGate.reset()
            safetyStatusMessage = nil
        }
    }

    /// Sleep/wake can place the pointer exactly on a rebuilt display junction.
    /// Do not restore walls until the delay has elapsed and the user has moved
    /// to an unambiguous point safely inside one display.
    func prepareForWake() {
        prepareForReconfiguration(reason: L10n.text(language, ja: "スリープ復帰", en: "wake"))
    }

    func prepareForDisplayChange() {
        prepareForReconfiguration(reason: L10n.text(language, ja: "画面構成変更", en: "display configuration change"))
    }

    func pauseForPotentialDisplayChange() {
        stop(preservingSafetyState: true)
        onStatus?(barrierStatus(L10n.text(language, ja: "画面構成を確認中", en: "Checking display configuration")))
    }

    private func prepareForReconfiguration(reason: String) {
        clearTransientBarrierState()
        safetyGate.requireSafeRearm(
            now: ProcessInfo.processInfo.systemUptime,
            delay: wakeRearmDelay
        )
        announceSafety(L10n.text(
            language,
            ja: "\(reason)後の安全確認中：画面内へ移動すると壁を再開します",
            en: "Safety check after \(reason): move inside a display to restore the barrier"
        ))
    }

    fileprivate func reenableTap() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: true)
            reportRunningStatus()
        }
    }

    fileprivate func filter(event: CGEvent, type: CGEventType) {
        guard type == .mouseMoved || type == .leftMouseDragged || type == .rightMouseDragged || type == .otherMouseDragged else { return }
        let proposed = event.location
        let now = ProcessInfo.processInfo.systemUptime

        // This is deliberately checked before every wall decision.  It is a
        // keyboard-only escape route that does not depend on cursor position.
        let globalFlags = CGEventSource.flagsState(.combinedSessionState)
        if event.flags.contains(.maskAlternate) || globalFlags.contains(.maskAlternate) {
            clearTransientBarrierState()
            previousLocation = proposed
            approachDisplayID = CursorBarrierGeometry.stableDisplayID(
                at: proposed, displays: displays, barriers: barriers
            )
            return
        }

        guard let previousLocation else {
            self.previousLocation = proposed
            updateApproachDisplay(at: proposed)
            return
        }
        let safePosition = CursorBarrierGeometry.isSafeRearmPosition(
            proposed, displays: displays, barriers: barriers
        )
        switch safetyGate.decision(now: now, isSafePosition: safePosition) {
        case .bypassing:
            self.previousLocation = proposed
            if safePosition {
                updateApproachDisplay(at: proposed)
            }
            return
        case .rearmed:
            self.previousLocation = proposed
            updateApproachDisplay(at: proposed)
            announceSafety(L10n.text(
                language,
                ja: "安全な画面内位置を確認：接合部バリアを再開しました",
                en: "Safe on-screen position confirmed: barrier restored"
            ))
            return
        case .active:
            break
        }
        if now >= cooldownUntil {
            cooldownBarrier = nil
        }
        guard let approachDisplayID else {
            self.previousLocation = proposed
            updateApproachDisplay(at: proposed)
            return
        }
        // Wall enforcement is independent from action latches and cooldowns.
        // While enabled, every collision is constrained.
        let ownedBarriers = barriers.filter { $0.displayID == approachDisplayID }
        let collision = CursorBarrierGeometry.collision(
            from: previousLocation,
            to: proposed,
            barriers: ownedBarriers
        ) ?? CursorBarrierGeometry.cornerContact(
            from: previousLocation,
            to: proposed,
            barriers: ownedBarriers
        )
        if let collision {
            let constrained = collision.point
            event.location = constrained
            let error = CGWarpMouseCursorPosition(constrained)
            if error != .success {
                onStatus?(barrierStatus(L10n.text(
                    language,
                    ja: "カーソル補正に失敗（\(error.rawValue)）",
                    en: "Cursor correction failed (\(error.rawValue))"
                )))
            } else {
                let associationError = CGAssociateMouseAndMouseCursorPosition(1)
                if associationError != .success {
                    logger.error("カーソル再関連付けに失敗：\(associationError.rawValue)")
                }
                warpCount += 1
                if ProcessInfo.processInfo.environment["INNERCORNERS_DIAGNOSTICS"] == "1", warpCount <= 100 {
                    let owner = String(approachDisplayID)
                    let line = "Soft barrier #\(warpCount): source=\(owner), wall=\(collision.barrier.displayID):\(collision.barrier.corner.rawValue), \(previousLocation) -> \(proposed), clamped to \(constrained)\n"
                    FileHandle.standardError.write(Data(line.utf8))
                }
            }
            let sameLatchedJunction = latchedBarrier.map {
                CursorBarrierGeometry.sameJunction($0, collision.barrier)
            } ?? false
            let sameCoolingJunction = now < cooldownUntil && (cooldownBarrier.map {
                CursorBarrierGeometry.sameJunction($0, collision.barrier)
            } ?? false)
            let intentionalReactivation = type == .mouseMoved
                && reactivationGate.consumeReactivation(for: collision.barrier)
            if !sameLatchedJunction {
                latchedBarrier = collision.barrier
            }
            if type == .mouseMoved && !sameLatchedJunction && (!sameCoolingJunction || intentionalReactivation) {
                cooldownBarrier = collision.barrier
                cooldownUntil = now + collisionCooldown
                reactivationGate.recordTrigger(collision.barrier)
                let barrier = collision.barrier
                let sourceDisplayID = approachDisplayID
                DispatchQueue.main.async { [weak self] in
                    self?.onCollision?(barrier, sourceDisplayID)
                }
            }
            self.previousLocation = constrained
        } else {
            releaseLatchIfNeeded(at: proposed)
            if type == .mouseMoved {
                reactivationGate.observeMovement(
                    at: proposed,
                    now: now,
                    stableDisplayID: CursorBarrierGeometry.stableDisplayID(
                        at: proposed, displays: displays, barriers: barriers
                    )
                )
            }
            if latchedBarrier == nil {
                updateApproachDisplay(at: proposed)
            }
            self.previousLocation = proposed
        }
    }

    private func updateApproachDisplay(at point: CGPoint) {
        if let id = CursorBarrierGeometry.stableDisplayID(at: point, displays: displays, barriers: barriers) {
            approachDisplayID = id
        }
    }

    private func synchronizePointerState() {
        guard let point = CGEvent(source: nil)?.location else {
            previousLocation = nil
            return
        }
        previousLocation = point
        updateApproachDisplay(at: point)
    }

    private func clearTransientBarrierState() {
        latchedBarrier = nil
        cooldownBarrier = nil
        cooldownUntil = 0
        approachDisplayID = nil
        reactivationGate.reset()
    }

    private func announceSafety(_ message: String) {
        safetyStatusMessage = message
        logger.notice("\(message, privacy: .public)")
        onStatus?(barrierStatus(message))
        DispatchQueue.main.async { [weak self] in
            self?.onSafetyEvent?(message)
        }
    }

    private func releaseLatchIfNeeded(at point: CGPoint) {
        guard let barrier = latchedBarrier else { return }
        if CursorBarrierGeometry.shouldReleaseLatch(at: point, barrier: barrier) {
            latchedBarrier = nil
        }
    }

    private func start() {
        guard tap == nil else {
            reportRunningStatus()
            return
        }
        let types: [CGEventType] = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: cursorBarrierCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            setEventTapActive(false)
            onStatus?(barrierStatus(L10n.text(language, ja: "イベントフィルタを作成できません（権限を確認）", en: "Could not create event filter (check permission)")))
            return
        }
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            setEventTapActive(false)
            onStatus?(barrierStatus(L10n.text(language, ja: "RunLoopソースを作成できません", en: "Could not create RunLoop source")))
            return
        }
        self.tap = tap
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        setEventTapActive(true)
        reportRunningStatus()
    }

    private func setEventTapActive(_ active: Bool) {
        guard isEventTapActive != active else { return }
        isEventTapActive = active
        onEventTapStateChange?(active)
    }

    private func reportRunningStatus() {
        if safetyGate.requiresSafeRearm {
            onStatus?(barrierStatus(safetyStatusMessage ?? L10n.text(language, ja: "安全確認中", en: "Safety check in progress")))
        } else {
            onStatus?(L10n.text(
                language,
                ja: "接合部ソフトバリア：有効（\(barriers.count)か所）",
                en: "Junction Barrier: Active (\(barriers.count) locations)"
            ))
        }
    }

    private func barrierStatus(_ message: String) -> String {
        L10n.text(language, ja: "接合部バリア：\(message)", en: "Junction Barrier: \(message)")
    }
}
