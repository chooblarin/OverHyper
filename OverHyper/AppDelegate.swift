import Cocoa
import OSLog

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var runtime: AppRuntime?

    private let logger = Logger(subsystem: "OverHyper", category: "AppDelegate")

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()

        let appRuntime = AppRuntime(settingsStore: .shared)
        runtime = appRuntime
        appRuntime.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        runtime?.stop()
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem?.button else {
            logger.error("Failed to initialize status item button")
            return
        }

        button.title = "⚡️"
        button.toolTip = "OverHyper"
        statusItem?.menu = makeStatusMenu()
    }

    private func makeStatusMenu() -> NSMenu {
        let menu = NSMenu()

        menu.addItem(makeMenuItem(
            title: "Fire Confetti",
            action: #selector(fireConfetti),
            keyEquivalent: "f"
        ))
        menu.addItem(makeMenuItem(
            title: "Fire Flash",
            action: #selector(fireFlash),
            keyEquivalent: "l"
        ))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(makeMenuItem(
            title: "Settings...",
            action: #selector(openSettings),
            keyEquivalent: ","
        ))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(makeMenuItem(
            title: "Quit OverHyper",
            action: #selector(quit),
            keyEquivalent: "q"
        ))

        return menu
    }

    private func makeMenuItem(
        title: String,
        action: Selector,
        keyEquivalent: String
    ) -> NSMenuItem {
        let item = NSMenuItem(
            title: title,
            action: action,
            keyEquivalent: keyEquivalent
        )
        item.target = self
        item.keyEquivalentModifierMask = [.command]
        return item
    }

    @objc private func fireConfetti() {
        runtime?.fire(.confetti)
    }

    @objc private func fireFlash() {
        runtime?.fire(.flash)
    }

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
