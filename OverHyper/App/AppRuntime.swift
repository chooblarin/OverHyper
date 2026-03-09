import Foundation
import OSLog

@MainActor
final class AppRuntime {
    private let effectOrchestrator: EffectOrchestrator
    private let hotkeyService: HotkeyService
    private let logger = Logger(subsystem: "OverHyper", category: "AppRuntime")

    init(settingsStore: EffectSettingsStore) {
        let overlayController = OverlayWindowController()
        let orchestrator = EffectOrchestrator(
            overlayController: overlayController,
            settingsStore: settingsStore,
            confettiEffect: ConfettiEffect(),
            flashEffect: FlashEffect(),
            glitchEffect: GlitchEffect()
        )

        effectOrchestrator = orchestrator
        hotkeyService = HotkeyService(settingsStore: settingsStore) { [weak orchestrator] effect in
            orchestrator?.fire(effect)
        }
    }

    func start() {
        hotkeyService.start()
        logger.info("App runtime started")
    }

    func stop() {
        hotkeyService.stop()
    }

    func fire(_ effect: EffectKind) {
        effectOrchestrator.fire(effect)
    }
}
