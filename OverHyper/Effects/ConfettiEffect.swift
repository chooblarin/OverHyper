import AppKit
import QuartzCore

final class ConfettiEffect: OverlayEffect {
    private static let particleImage = ConfettiEffect.makeParticleImage()

    func fire(in context: OverlayRenderContext, settings: EffectSettings) {
        let layer = context.layer
        guard layer.bounds.width > 0, layer.bounds.height > 0 else {
            return
        }

        let emitterLayer = CAEmitterLayer()
        emitterLayer.frame = layer.bounds
        emitterLayer.emitterShape = .point
        emitterLayer.emitterPosition = CGPoint(
            x: layer.bounds.midX,
            y: layer.bounds.midY - 24
        )
        emitterLayer.emitterSize = CGSize(width: 8, height: 8)
        emitterLayer.renderMode = .oldestFirst
        emitterLayer.birthRate = 1
        emitterLayer.emitterCells = makeCells(settings: settings)

        layer.addSublayer(emitterLayer)

        let stopDelay = settings.confettiDuration
        DispatchQueue.main.asyncAfter(deadline: .now() + stopDelay) {
            emitterLayer.birthRate = 0
        }

        let removeDelay = stopDelay + 5.6
        DispatchQueue.main.asyncAfter(deadline: .now() + removeDelay) {
            emitterLayer.removeFromSuperlayer()
        }
    }

    private func makeCells(settings: EffectSettings) -> [CAEmitterCell] {
        Colors.palette.enumerated().map { index, color in
            let cell = CAEmitterCell()
            cell.contents = Self.particleImage
            cell.birthRate = settings.intensityPreset.confettiBirthRate
            cell.lifetime = Float(settings.confettiDuration + 4.2)
            cell.lifetimeRange = 1.0
            cell.velocity = settings.intensityPreset.confettiVelocity * 1.15
            cell.velocityRange = settings.intensityPreset.confettiVelocity * 0.18
            cell.emissionLongitude = Double.pi / 2
            cell.emissionRange = Double.pi / 4
            cell.yAcceleration = -150
            cell.xAcceleration = Drift.horizontalAcceleration(for: index)
            cell.spin = 2.5
            cell.spinRange = settings.intensityPreset.confettiSpinRange
            cell.scale = 0.58
            cell.scaleRange = 0.24
            cell.color = color.cgColor
            return cell
        }
    }

    private static func makeParticleImage() -> CGImage? {
        let size = NSSize(width: 12, height: 8)
        let image = NSImage(size: size)

        image.lockFocus()
        NSColor.white.setFill()
        let path = NSBezierPath(
            roundedRect: NSRect(origin: .zero, size: size),
            xRadius: 1.8,
            yRadius: 1.8
        )
        path.fill()
        image.unlockFocus()

        return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
}

private enum Colors {
    static let palette: [NSColor] = [
        NSColor.systemPink,
        NSColor.systemYellow,
        NSColor.systemTeal,
        NSColor.systemOrange,
        NSColor.systemMint,
        NSColor.systemBlue,
    ]
}

private enum Drift {
    private static let values: [CGFloat] = [-20, -12, -6, 6, 12, 20]

    static func horizontalAcceleration(for index: Int) -> CGFloat {
        values[index % values.count]
    }
}
