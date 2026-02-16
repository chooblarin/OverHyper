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

        for surface in surfaces {
            guard let layer = surface.hostView.layer else {
                logger.warning("Missing host layer for overlay window")
                continue
            }

            layer.frame = surface.hostView.bounds
            effect.fire(on: layer, settings: settings)
        }
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
            .ignoresCycle,
        ]
        window.contentView = hostView
        window.orderFront(nil)

        return OverlaySurface(window: window, hostView: hostView)
    }
}

private struct OverlaySurface {
    let window: NSWindow
    let hostView: OverlayHostView
}

private final class OverlayHostView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        return nil
    }

    override func layout() {
        super.layout()
        layer?.frame = bounds
    }
}
