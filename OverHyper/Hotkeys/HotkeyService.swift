import AppKit
import OSLog

@MainActor
final class HotkeyService {
    private let settingsStore: EffectSettingsStore
    private let registrar: GlobalHotkeyRegistrar
    private let onTrigger: (EffectKind) -> Void
    private let logger = Logger(subsystem: "OverHyper", category: "Hotkey")
    private var registrationTokens: [HotkeySlotID: HotkeyRegistrationToken] = [:]

    init(
        settingsStore: EffectSettingsStore,
        registrar: GlobalHotkeyRegistrar,
        onTrigger: @escaping (EffectKind) -> Void
    ) {
        self.settingsStore = settingsStore
        self.registrar = registrar
        self.onTrigger = onTrigger
    }

    func start() {
        registerShortcuts()
        logger.info("Preset hotkey bindings active")
    }

    func stop() {
        for token in registrationTokens.values {
            registrar.unregister(token)
        }
        registrationTokens.removeAll()
    }

    private func registerShortcuts() {
        stop()

        for slotID in HotkeySlotID.allCases {
            let shortcut = slotID.shortcut
            guard let token = registrar.register(shortcut, action: { [weak self] in
                guard let self else {
                    return
                }

                guard let effect = self.settingsStore.assignedEffect(for: slotID) else {
                    return
                }

                self.onTrigger(effect)
            }) else {
                logger.error("Failed to register hotkey for \(slotID.rawValue, privacy: .public)")
                continue
            }

            registrationTokens[slotID] = token
        }
    }
}
