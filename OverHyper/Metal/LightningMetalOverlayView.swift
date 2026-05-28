import AppKit
import MetalKit

@MainActor
final class LightningMetalOverlayView: MTKView {
    private let renderer: LightningMetalRenderer

    override var isOpaque: Bool {
        false
    }

    init?(frame frameRect: NSRect, duration: TimeInterval) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return nil
        }

        guard let renderer = LightningMetalRenderer(device: device, duration: duration) else {
            return nil
        }

        self.renderer = renderer

        super.init(frame: frameRect, device: device)

        autoresizingMask = [.width, .height]
        clearColor = MTLClearColorMake(0, 0, 0, 0)
        colorPixelFormat = .bgra8Unorm
        layer?.isOpaque = false
        layer?.backgroundColor = NSColor.clear.cgColor
        (layer as? CAMetalLayer)?.isOpaque = false
        framebufferOnly = true
        enableSetNeedsDisplay = false
        isPaused = false
        preferredFramesPerSecond = 60
        autoResizeDrawable = true

        delegate = renderer
        renderer.attach(to: self)
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
