import Carbon.HIToolbox
import Foundation

final class GlobalHotkeyRegistrar {
    private struct Registration {
        let hotKeyRef: EventHotKeyRef
        let action: @MainActor () -> Void
    }

    private static let hotKeySignature: OSType = 0x4F764879

    private var nextIdentifier: UInt32 = 1
    private var eventHandlerRef: EventHandlerRef?
    private var registrations: [UInt32: Registration] = [:]

    deinit {
        removeAll()

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    func register(
        _ hotkey: Hotkey,
        action: @escaping @MainActor () -> Void
    ) -> HotkeyRegistrationToken? {
        guard installEventHandlerIfNeeded() == noErr else {
            return nil
        }

        let identifier = nextIdentifier
        nextIdentifier += 1

        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(
            signature: Self.hotKeySignature,
            id: identifier
        )
        let status = RegisterEventHotKey(
            hotkey.keyCode,
            hotkey.carbonModifierFlags,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr, let hotKeyRef else {
            return nil
        }

        registrations[identifier] = Registration(
            hotKeyRef: hotKeyRef,
            action: action
        )
        return HotkeyRegistrationToken(identifier: identifier)
    }

    func unregister(_ token: HotkeyRegistrationToken) {
        guard let registration = registrations.removeValue(forKey: token.identifier) else {
            return
        }

        UnregisterEventHotKey(registration.hotKeyRef)
    }

    func removeAll() {
        for registration in registrations.values {
            UnregisterEventHotKey(registration.hotKeyRef)
        }
        registrations.removeAll()
    }

    private func installEventHandlerIfNeeded() -> OSStatus {
        guard eventHandlerRef == nil else {
            return noErr
        }

        var hotKeyPressedSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        return InstallEventHandler(
            GetEventDispatcherTarget(),
            Self.carbonEventCallback,
            1,
            &hotKeyPressedSpec,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )
    }

    private func handleHotKeyEvent(_ event: EventRef?) -> OSStatus {
        guard let event else {
            return OSStatus(eventNotHandledErr)
        }

        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard status == noErr, hotKeyID.signature == Self.hotKeySignature else {
            return OSStatus(eventNotHandledErr)
        }

        guard let registration = registrations[hotKeyID.id] else {
            return OSStatus(eventNotHandledErr)
        }

        Task { @MainActor in
            registration.action()
        }

        return OSStatus(noErr)
    }

    private static let carbonEventCallback: EventHandlerUPP = { _, event, userData in
        guard let userData else {
            return OSStatus(eventNotHandledErr)
        }

        let registrar = Unmanaged<GlobalHotkeyRegistrar>
            .fromOpaque(userData)
            .takeUnretainedValue()
        return registrar.handleHotKeyEvent(event)
    }
}
