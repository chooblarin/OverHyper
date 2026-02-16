import Foundation
import OSLog

@MainActor
final class EffectOrchestrator {
    private let overlayController: OverlayWindowController
    private let settingsStore: EffectSettingsStore
    private let confettiEffect: OverlayEffect
    private let flashEffect: OverlayEffect
    private let logger = Logger(
        subsystem: "OverHyper",
        category: "EffectOrchestrator"
    )

    init(
        overlayController: OverlayWindowController,
        settingsStore: EffectSettingsStore,
        confettiEffect: OverlayEffect,
        flashEffect: OverlayEffect
    ) {
        self.overlayController = overlayController
        self.settingsStore = settingsStore
        self.confettiEffect = confettiEffect
        self.flashEffect = flashEffect
    }

    func fire(_ kind: EffectKind) {
        let effect: OverlayEffect
        switch kind {
        case .confetti:
            effect = confettiEffect
        case .flash:
            effect = flashEffect
        }

        overlayController.render(effect: effect, settings: settingsStore.settings)
        logger.debug("Effect fired: \(kind.rawValue, privacy: .public)")
    }
}
