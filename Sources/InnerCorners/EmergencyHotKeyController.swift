import Carbon
import Foundation
import OSLog

private let emergencyHotKeyCallback: EventHandlerUPP = { _, _, userData in
    guard let userData else { return OSStatus(eventNotHandledErr) }
    let controller = Unmanaged<EmergencyHotKeyController>
        .fromOpaque(userData)
        .takeUnretainedValue()
    return MainActor.assumeIsolated {
        controller.handlePress()
        return noErr
    }
}

/// A Carbon hot key is intentionally independent from the cursor event tap.
/// It remains a keyboard-only exit path even if mouse processing misbehaves.
@MainActor
final class EmergencyHotKeyController {
    private let logger = Logger(subsystem: "local.prototype.InnerCorners", category: "EmergencyHotKey")
    private var eventHandler: EventHandlerRef?
    private var hotKey: EventHotKeyRef?

    var onTrigger: (() -> Void)?

    func start() -> Bool {
        guard hotKey == nil else { return true }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            emergencyHotKeyCallback,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
        guard handlerStatus == noErr else {
            logger.error("緊急キーのイベントハンドラ登録に失敗：\(handlerStatus)")
            return false
        }

        let identifier = EventHotKeyID(
            signature: OSType(0x49434F52), // "ICOR"
            id: 1
        )
        let modifiers = UInt32(controlKey | optionKey | cmdKey)
        let hotKeyStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_Q),
            modifiers,
            identifier,
            GetApplicationEventTarget(),
            0,
            &hotKey
        )
        guard hotKeyStatus == noErr else {
            logger.error("緊急キー ⌃⌥⌘Q の登録に失敗：\(hotKeyStatus)")
            if let eventHandler {
                RemoveEventHandler(eventHandler)
                self.eventHandler = nil
            }
            return false
        }
        logger.notice("緊急キー ⌃⌥⌘Q を登録しました")
        return true
    }

    func stop() {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
            self.hotKey = nil
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    fileprivate func handlePress() {
        logger.fault("緊急キーが押されました。バリアを停止して終了します")
        onTrigger?()
    }

    isolated deinit {
        stop()
    }
}
