import AppKit
import QuartzCore

struct OverlayRenderContext {
    let screen: NSScreen
    let hostView: OverlayHostView
    let layer: CALayer
}

protocol OverlayEffect {
    func prepareForRender(settings: EffectSettings) -> Bool
    func fire(in context: OverlayRenderContext, settings: EffectSettings)
    func finishRender(settings: EffectSettings)
}

extension OverlayEffect {
    func prepareForRender(settings: EffectSettings) -> Bool {
        true
    }

    func finishRender(settings: EffectSettings) {}
}
