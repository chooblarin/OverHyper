import AppKit
import OSLog

@MainActor
final class OverlayWindowController {
    private let surfaceManager: OverlaySurfaceManager
    private let logger = Logger(subsystem: "OverHyper", category: "Overlay")

    init() {
        surfaceManager = OverlaySurfaceManager()
        surfaceManager.ensureSurfacesMatchDisplays()
        observeEnvironmentChanges()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    func render(effect: OverlayEffect, settings: EffectSettings) {
        let syncedSurfaces = surfaceManager.ensureSurfacesMatchDisplays()
        let surfaceEntries = syncedSurfaces.compactMap { surface -> (
            surface: OverlaySurface,
            display: DisplaySnapshot
        )? in
            guard let display = DisplayCatalog.snapshot(for: surface.screen) else {
                logger.warning("Skipping overlay render surface with no display snapshot")
                return nil
            }

            return (surface: surface, display: display)
        }

        let resolution = PresentationTargetResolver.resolve(
            displays: surfaceEntries.map { $0.display },
            target: settings.presentationTarget
        )
        if let warning = resolution.warning {
            let message = warning.displayMessage
            logger.warning("Presentation target warning: \(message, privacy: .public)")
        }

        let contexts = surfaceEntries.compactMap { entry -> OverlayRenderContext? in
            guard resolution.displayIDs.contains(entry.display.id) else {
                return nil
            }

            let surface = entry.surface
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

        guard !contexts.isEmpty else {
            return
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
        surfaceManager.rebuildForCurrentScreens()
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
            selector: #selector(refreshWindowsForActiveSpace),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
    }

    @objc private func refreshWindowsForActiveSpace() {
        surfaceManager.refreshWindowPlacement()
    }
}
