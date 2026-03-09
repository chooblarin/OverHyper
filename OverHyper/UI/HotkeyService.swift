import AppKit
import MASShortcut
import OSLog

@MainActor
final class HotkeyService {
    private let settingsStore: EffectSettingsStore
    private let shortcutMonitor: MASShortcutMonitor
    private let onTrigger: (EffectKind) -> Void
    private let logger = Logger(subsystem: "OverHyper", category: "Hotkey")
    private var registeredShortcuts: [HotkeySlotID: MASShortcut] = [:]

    init(
        settingsStore: EffectSettingsStore,
        shortcutMonitor: MASShortcutMonitor = MASShortcutMonitor.shared(),
        onTrigger: @escaping (EffectKind) -> Void
    ) {
        self.settingsStore = settingsStore
        self.shortcutMonitor = shortcutMonitor
        self.onTrigger = onTrigger
    }

    func start() {
        registerShortcuts()
        logger.info("Preset hotkey bindings active")
    }

    func stop() {
        for shortcut in registeredShortcuts.values {
            shortcutMonitor.unregisterShortcut(shortcut)
        }
        registeredShortcuts.removeAll()
    }

    private func registerShortcuts() {
        stop()

        for slotID in HotkeySlotID.allCases {
            let shortcut = slotID.shortcut
            let didRegister = shortcutMonitor.register(shortcut) { [weak self] in
                guard let self else {
                    return
                }

                guard let effect = self.settingsStore.assignedEffect(for: slotID) else {
                    return
                }

                self.onTrigger(effect)
            }

            guard didRegister else {
                logger.error("Failed to register hotkey for \(slotID.rawValue, privacy: .public)")
                continue
            }

            registeredShortcuts[slotID] = shortcut
        }
    }
}
