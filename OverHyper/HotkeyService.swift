import AppKit
import Carbon.HIToolbox
import MASShortcut
import OSLog

@MainActor
final class HotkeyService {
    private let defaults: UserDefaults
    private let defaultsKey: String
    private let legacyDefaultsKey: String
    private let binder: MASShortcutBinder
    private let onTrigger: () -> Void
    private let logger = Logger(subsystem: "OverHyper", category: "Hotkey")

    init(
        defaults: UserDefaults = .standard,
        defaultsKey: String = EffectSettingsStore.hotkeyDefaultsKey,
        legacyDefaultsKey: String = EffectSettingsStore.legacyHotkeyDefaultsKey,
        binder: MASShortcutBinder = MASShortcutBinder.shared(),
        onTrigger: @escaping () -> Void
    ) {
        self.defaults = defaults
        self.defaultsKey = defaultsKey
        self.legacyDefaultsKey = legacyDefaultsKey
        self.binder = binder
        self.onTrigger = onTrigger
    }

    func start() {
        configureBindingOptions()
        migrateLegacyShortcutIfNeeded()
        registerDefaultIfNeeded()
        binder.bindShortcut(withDefaultsKey: defaultsKey, toAction: onTrigger)
        logger.info("Global hotkey binding active")
    }

    func stop() {
        binder.breakBinding(withDefaultsKey: defaultsKey)
    }

    private func registerDefaultIfNeeded() {
        guard defaults.object(forKey: defaultsKey) == nil else {
            return
        }

        let shortcut = MASShortcut(
            keyCode: Int(kVK_ANSI_G),
            modifierFlags: [.control, .option, .command]
        )

        let shortcuts: [String: MASShortcut] = [
            defaultsKey: shortcut,
        ]

        binder.registerDefaultShortcuts(shortcuts)
        logger.debug("Registered default hotkey: control+option+command+G")
    }

    private func configureBindingOptions() {
        binder.bindingOptions = [
            NSBindingOption.valueTransformerName: MASDictionaryTransformerName,
        ]
    }

    private func migrateLegacyShortcutIfNeeded() {
        guard defaults.object(forKey: defaultsKey) == nil else {
            return
        }

        guard let legacyValue = defaults.object(forKey: legacyDefaultsKey) else {
            return
        }

        defaults.set(legacyValue, forKey: defaultsKey)
        defaults.removeObject(forKey: legacyDefaultsKey)
        logger.debug("Migrated legacy hotkey key")
    }
}
