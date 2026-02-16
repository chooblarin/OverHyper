import AppKit
import QuartzCore

final class FlashEffect: OverlayEffect {
    func fire(on layer: CALayer, settings: EffectSettings) {
        guard settings.flashEnabled else {
            return
        }

        let flashLayer = CALayer()
        flashLayer.frame = layer.bounds
        flashLayer.backgroundColor = NSColor.white.cgColor
        flashLayer.opacity = 0

        layer.addSublayer(flashLayer)

        let animation = CAKeyframeAnimation(keyPath: "opacity")
        animation.values = [0.0, settings.intensityPreset.flashOpacity, 0.0]
        animation.keyTimes = [0.0, 0.35, 1.0]
        animation.duration = 0.34
        animation.timingFunctions = [
            CAMediaTimingFunction(name: .easeOut),
            CAMediaTimingFunction(name: .easeIn),
        ]

        flashLayer.add(animation, forKey: "overhyper.flash.opacity")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
            flashLayer.removeFromSuperlayer()
        }
    }
}
