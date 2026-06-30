import AppKit
import OSLog

@MainActor
final class OverlaySurfaceManager {
    private(set) var surfaces: [OverlaySurface] = []
    private let logger = Logger(subsystem: "OverHyper", category: "OverlaySurface")

    @discardableResult
    func ensureSurfacesMatchDisplays() -> [OverlaySurface] {
        guard surfacesMatchCurrentDisplays() else {
            return rebuildForCurrentScreens()
        }

        return surfaces
    }

    @discardableResult
    func rebuildForCurrentScreens() -> [OverlaySurface] {
        closeAllWindows()
        surfaces = NSScreen.screens.compactMap(makeSurface(for:))
        refreshWindowPlacement()

        logger.debug("Overlay surfaces rebuilt: \(self.surfaces.count)")
        for surface in surfaces {
            log(surface: surface)
        }

        return surfaces
    }

    func refreshWindowPlacement() {
        for surface in surfaces {
            if surface.window.frame != surface.screen.frame {
                surface.window.setFrame(surface.screen.frame, display: true)
            }
            surface.window.orderFrontRegardless()
        }

        logger.debug("Overlay surfaces refreshed for active Space: \(self.surfaces.count)")
    }

    private func surfacesMatchCurrentDisplays() -> Bool {
        let currentDisplayIDs = Set(DisplayCatalog.snapshots().map(\.id))
        let surfaceDisplayIDs = Set(surfaces.compactMap { surface in
            DisplayCatalog.displayID(for: surface.screen)
        })

        return currentDisplayIDs == surfaceDisplayIDs
    }

    private func closeAllWindows() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            context.allowsImplicitAnimation = false

            surfaces.forEach { surface in
                surface.window.contentView = nil
                surface.window.orderOut(nil)
                surface.window.close()
            }
        }

        surfaces.removeAll()
    }

    private func makeSurface(for screen: NSScreen) -> OverlaySurface? {
        guard DisplayCatalog.displayID(for: screen) != nil else {
            logger.warning("Skipping overlay surface with no display ID")
            return nil
        }

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
        window.animationBehavior = .none
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

        return OverlaySurface(
            screen: screen,
            window: window,
            hostView: hostView
        )
    }

    private func log(surface: OverlaySurface) {
        guard let display = DisplayCatalog.snapshot(for: surface.screen) else {
            logger.warning("Overlay surface has no display snapshot")
            return
        }

        logger.debug("""
        Overlay surface displayID=\(display.id) \
        external=\(display.isExternal) \
        frame=\(String(describing: display.frame), privacy: .public)
        """)
    }
}

struct OverlaySurface {
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
