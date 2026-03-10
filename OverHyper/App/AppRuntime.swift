import Foundation
import OSLog

@MainActor
final class AppRuntime {
    private let effectOrchestrator: EffectOrchestrator
    private let hotkeyService: HotkeyService
    private let logger = Logger(subsystem: "OverHyper", category: "AppRuntime")

    init(settingsStore: EffectSettingsStore) {
        let overlayController = OverlayWindowController()
        let screenCaptureService = ScreenCaptureService()
        let orchestrator = EffectOrchestrator(
            overlayController: overlayController,
            settingsStore: settingsStore,
            confettiEffect: ConfettiEffect(),
            flashEffect: FlashEffect(),
            glitchEffect: GlitchEffect(screenCaptureService: screenCaptureService),
            crtBurstEffect: CRTBurstEffect(screenCaptureService: screenCaptureService),
            shockwaveEffect: ShockwaveEffect(screenCaptureService: screenCaptureService),
            crackedGlassEffect: CrackedGlassEffect(screenCaptureService: screenCaptureService),
            neonEdgeEffect: NeonEdgeEffect(screenCaptureService: screenCaptureService)
        )

        effectOrchestrator = orchestrator
        hotkeyService = HotkeyService(
            settingsStore: settingsStore,
            registrar: GlobalHotkeyRegistrar()
        ) { [weak orchestrator] effect in
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
