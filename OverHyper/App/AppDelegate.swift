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
            keyEquivalent: ""
        ))
        menu.addItem(makeMenuItem(
            title: "Fire Flash",
            action: #selector(fireFlash),
            keyEquivalent: ""
        ))
        menu.addItem(makeMenuItem(
            title: "Fire Glitch",
            action: #selector(fireGlitch),
            keyEquivalent: ""
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
        if !keyEquivalent.isEmpty {
            item.keyEquivalentModifierMask = [.command]
        }
        return item
    }

    func fire(_ effect: EffectKind) {
        runtime?.fire(effect)
    }

    @objc private func fireConfetti() {
        fire(.confetti)
    }

    @objc private func fireFlash() {
        fire(.flash)
    }

    @objc private func fireGlitch() {
        fire(.glitch)
    }

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async { [logger] in
            let didOpen = NSApp.sendAction(
                Selector(("showSettingsWindow:")),
                to: nil,
                from: nil
            )

            if !didOpen {
                logger.error("Failed to open settings window from status menu")
            }
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
