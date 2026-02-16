import Cocoa

final class OverlayWindowController {

    private var windows: [NSWindow] = []

    init() {
        createWindows()
        observeScreenChanges()
    }

    private func createWindows() {
        for screen in NSScreen.screens {
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
                .fullScreenAuxiliary
            ]

            window.makeKeyAndOrderFront(nil)

            windows.append(window)
        }
    }

    private func observeScreenChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(recreateWindows),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func recreateWindows() {
        windows.forEach { $0.close() }
        windows.removeAll()
        createWindows()
    }
}
