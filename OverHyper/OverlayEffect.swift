import Foundation
import QuartzCore

protocol OverlayEffect {
    func fire(on layer: CALayer, settings: EffectSettings)
}
