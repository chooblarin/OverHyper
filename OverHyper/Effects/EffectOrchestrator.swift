import Foundation
import OSLog

@MainActor
final class EffectOrchestrator {
    private let overlayController: OverlayWindowController
    private let settingsStore: EffectSettingsStore
    private let confettiEffect: OverlayEffect
    private let flashEffect: OverlayEffect
    private let glitchEffect: OverlayEffect
    private let crtBurstEffect: OverlayEffect
    private let shockwaveEffect: OverlayEffect
    private let crackedGlassEffect: OverlayEffect
    private let neonEdgeEffect: OverlayEffect
    private let rainGlassEffect: OverlayEffect
    private let logger = Logger(
        subsystem: "OverHyper",
        category: "EffectOrchestrator"
    )

    init(
        overlayController: OverlayWindowController,
        settingsStore: EffectSettingsStore,
        confettiEffect: OverlayEffect,
        flashEffect: OverlayEffect,
        glitchEffect: OverlayEffect,
        crtBurstEffect: OverlayEffect,
        shockwaveEffect: OverlayEffect,
        crackedGlassEffect: OverlayEffect,
        neonEdgeEffect: OverlayEffect,
        rainGlassEffect: OverlayEffect
    ) {
        self.overlayController = overlayController
        self.settingsStore = settingsStore
        self.confettiEffect = confettiEffect
        self.flashEffect = flashEffect
        self.glitchEffect = glitchEffect
        self.crtBurstEffect = crtBurstEffect
        self.shockwaveEffect = shockwaveEffect
        self.crackedGlassEffect = crackedGlassEffect
        self.neonEdgeEffect = neonEdgeEffect
        self.rainGlassEffect = rainGlassEffect
    }

    func fire(_ kind: EffectKind) {
        let effect: OverlayEffect
        switch kind {
        case .confetti:
            effect = confettiEffect
        case .flash:
            effect = flashEffect
        case .glitch:
            effect = glitchEffect
        case .crtBurst:
            effect = crtBurstEffect
        case .shockwave:
            effect = shockwaveEffect
        case .crackedGlass:
            effect = crackedGlassEffect
        case .neonEdge:
            effect = neonEdgeEffect
        case .rainGlass:
            effect = rainGlassEffect
        }

        overlayController.render(effect: effect, settings: settingsStore.settings)
        logger.debug("Effect fired: \(kind.rawValue, privacy: .public)")
    }
}
