import Carbon.HIToolbox

/// Global Option+Space hotkey. Uses Carbon's RegisterEventHotKey, which needs
/// no Accessibility permission. Reports both press and release so hold-to-talk
/// and press-to-toggle can share it later.
final class HotkeyManager {
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    @discardableResult
    func register() -> Bool {
        var specs = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
        ]

        let callback: EventHandlerUPP = { _, event, userData in
            guard let event, let userData else { return noErr }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            switch GetEventKind(event) {
            case UInt32(kEventHotKeyPressed): manager.onPress?()
            case UInt32(kEventHotKeyReleased): manager.onRelease?()
            default: break
            }
            return noErr
        }

        let installed = InstallEventHandler(GetApplicationEventTarget(), callback, UInt(specs.count), &specs,
                                            Unmanaged.passUnretained(self).toOpaque(), &handlerRef)
        guard installed == noErr else { return false }

        let id = EventHotKeyID(signature: OSType(0x4153_5354), id: 1) // 'ASST'
        let registered = RegisterEventHotKey(UInt32(kVK_Space), UInt32(optionKey), id,
                                             GetApplicationEventTarget(), 0, &hotKeyRef)
        return registered == noErr
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
        hotKeyRef = nil
        handlerRef = nil
    }

    deinit { unregister() }
}
