import AppKit
import CoreGraphics
import QuartzCore

final class ConfettiEffect: OverlayEffect {
    private static let particleImage = ConfettiEffect.makeParticleImage()
    private enum Constants {
        static let duration: TimeInterval = 1.6
        static let birthRate: Float = 108
        static let velocity: CGFloat = 420
        static let spinRange: CGFloat = 2.2
    }

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
        emitterLayer.emitterCells = makeCells()

        layer.addSublayer(emitterLayer)

        let stopDelay = Constants.duration
        DispatchQueue.main.asyncAfter(deadline: .now() + stopDelay) {
            emitterLayer.birthRate = 0
        }

        let removeDelay = stopDelay + 5.6
        DispatchQueue.main.asyncAfter(deadline: .now() + removeDelay) {
            emitterLayer.removeFromSuperlayer()
        }
    }

    private func makeCells() -> [CAEmitterCell] {
        Colors.palette.enumerated().map { index, color in
            let cell = CAEmitterCell()
            cell.contents = Self.particleImage
            cell.birthRate = Constants.birthRate
            cell.lifetime = Float(Constants.duration + 4.2)
            cell.lifetimeRange = 1.0
            cell.velocity = Constants.velocity * 1.15
            cell.velocityRange = Constants.velocity * 0.18
            cell.emissionLongitude = Double.pi / 2
            cell.emissionRange = Double.pi / 4
            cell.yAcceleration = -150
            cell.xAcceleration = Drift.horizontalAcceleration(for: index)
            cell.spin = 2.5
            cell.spinRange = Constants.spinRange
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
        NSColor.systemBlue
    ]
}

private enum Drift {
    private static let values: [CGFloat] = [-20, -12, -6, 6, 12, 20]

    static func horizontalAcceleration(for index: Int) -> CGFloat {
        values[index % values.count]
    }
}
