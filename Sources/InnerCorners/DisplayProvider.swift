import AppKit
import ColorSync
import CoreGraphics

enum DisplayProvider {
    @MainActor
    static func current() -> [DisplayDescriptor] {
        NSScreen.screens.compactMap { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return nil
            }
            let displayID = number.uint32Value
            guard let uuidRef = CGDisplayCreateUUIDFromDisplayID(displayID) else { return nil }
            let uuid = uuidRef.takeRetainedValue()
            let persistentID = CFUUIDCreateString(nil, uuid) as String
            return DisplayDescriptor(
                id: persistentID,
                displayNumber: displayID,
                name: screen.localizedName,
                frame: screen.frame
            )
        }
    }

    @MainActor
    static func currentQuartz() -> [QuartzDisplayDescriptor] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var ids = Array(repeating: CGDirectDisplayID(), count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else { return [] }

        let names: [UInt32: String] = Dictionary(NSScreen.screens.compactMap { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
            return (number.uint32Value, screen.localizedName)
        }, uniquingKeysWith: { first, _ in first })
        return ids.prefix(Int(count)).map { id in
            QuartzDisplayDescriptor(id: id, name: names[id] ?? "Display \(id)", frame: CGDisplayBounds(id))
        }
    }
}
