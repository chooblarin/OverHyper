import AppKit
import MetalKit

@MainActor
final class MetalOverlayView: MTKView {
    private let renderer: MetalRenderer

    override var isOpaque: Bool {
        false
    }

    init?(
        frame frameRect: NSRect,
        image: CGImage,
        style: ShaderEffectStyle,
        duration: TimeInterval
    ) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return nil
        }

        guard let renderer = MetalRenderer(
            device: device,
            image: image,
            style: style,
            duration: duration
        ) else {
            return nil
        }

        self.renderer = renderer

        super.init(frame: frameRect, device: device)

        autoresizingMask = [.width, .height]
        clearColor = MTLClearColorMake(0, 0, 0, 0)
        colorPixelFormat = .bgra8Unorm
        framebufferOnly = false
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
