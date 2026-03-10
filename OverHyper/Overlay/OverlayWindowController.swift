import AppKit
import OSLog

@MainActor
final class OverlayWindowController {
    private var surfaces: [OverlaySurface] = []
    private let logger = Logger(subsystem: "OverHyper", category: "Overlay")

    init() {
        recreateWindows()
        observeEnvironmentChanges()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    func render(effect: OverlayEffect, settings: EffectSettings) {
        if surfaces.isEmpty {
            recreateWindows()
        }

        let contexts = surfaces.compactMap { surface -> OverlayRenderContext? in
            guard let layer = surface.hostView.layer else {
                logger.warning("Missing host layer for overlay window")
                return nil
            }

            layer.frame = surface.hostView.bounds
            return OverlayRenderContext(
                screen: surface.screen,
                hostView: surface.hostView,
                layer: layer
            )
        }

        guard effect.prepareForRender(settings: settings) else {
            return
        }

        for context in contexts {
            effect.fire(in: context, settings: settings)
        }

        effect.finishRender(settings: settings)
    }

    @objc private func recreateWindows() {
        closeAllWindows()
        surfaces = NSScreen.screens.map(makeSurface(for:))

        logger.debug("Overlay surfaces rebuilt: \(self.surfaces.count)")
    }

    private func observeEnvironmentChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(recreateWindows),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(recreateWindows),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
    }

    private func closeAllWindows() {
        surfaces.forEach { $0.window.close() }
        surfaces.removeAll()
    }

    private func makeSurface(for screen: NSScreen) -> OverlaySurface {
        let hostView = OverlayHostView(
            frame: NSRect(origin: .zero, size: screen.frame.size)
        )

        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )

        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        window.contentView = hostView
        window.orderFront(nil)

        return OverlaySurface(screen: screen, window: window, hostView: hostView)
    }
}

private struct OverlaySurface {
    let screen: NSScreen
    let window: NSWindow
    let hostView: OverlayHostView
}

final class OverlayHostView: NSView {
    private weak var shaderSubview: NSView?
    private var shaderRequestID: UInt64 = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        return nil
    }

    func beginShaderRequest() -> UInt64 {
        shaderRequestID += 1
        clearShaderSubview()
        return shaderRequestID
    }

    func isCurrentShaderRequest(_ requestID: UInt64) -> Bool {
        shaderRequestID == requestID
    }

    func installShaderSubview(_ view: NSView, requestID: UInt64) {
        guard isCurrentShaderRequest(requestID) else {
            return
        }

        view.frame = bounds
        view.autoresizingMask = [.width, .height]
        addSubview(view)
        shaderSubview = view
    }

    func clearShaderSubview() {
        shaderSubview?.removeFromSuperview()
        shaderSubview = nil
    }

    func clearShaderSubview(ifMatching view: NSView) {
        guard shaderSubview === view else {
            return
        }

        clearShaderSubview()
    }

    func clearShaderSubview(ifMatching view: NSView, requestID: UInt64) {
        guard isCurrentShaderRequest(requestID) else {
            return
        }

        clearShaderSubview(ifMatching: view)
    }

    override func layout() {
        super.layout()
        layer?.frame = bounds
        shaderSubview?.frame = bounds
    }
}
