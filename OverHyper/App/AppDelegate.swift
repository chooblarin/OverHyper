import Cocoa
import OSLog
#if DEBUG
import SwiftUI
#endif

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var runtime: AppRuntime?
    private var openSettingsAction: (@MainActor () -> Void)?
    #if DEBUG
    private var shaderLabWindow: NSWindow?
    #endif

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
        let effectItems: [(title: String, action: Selector)] = [
            ("Fire Confetti", #selector(fireConfetti)),
            ("Fire Flash", #selector(fireFlash)),
            ("Fire Glitch", #selector(fireGlitch)),
            ("Fire CRT Burst", #selector(fireCRTBurst)),
            ("Fire Shockwave", #selector(fireShockwave)),
            ("Fire Cracked Glass", #selector(fireCrackedGlass)),
            ("Fire Neon Edge", #selector(fireNeonEdge)),
            ("Fire Rain Glass", #selector(fireRainGlass))
        ]

        for item in effectItems {
            menu.addItem(makeMenuItem(
                title: item.title,
                action: item.action,
                keyEquivalent: ""
            ))
        }

        menu.addItem(NSMenuItem.separator())
        menu.addItem(makeMenuItem(
            title: "Settings...",
            action: #selector(openSettings),
            keyEquivalent: ","
        ))
        #if DEBUG
        menu.addItem(makeMenuItem(
            title: "Shader Lab...",
            action: #selector(openShaderLab),
            keyEquivalent: ""
        ))
        #endif
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

    func setOpenSettingsAction(_ action: @escaping @MainActor () -> Void) {
        openSettingsAction = action
    }

    func showSettingsWindow() {
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async { [logger, openSettingsAction] in
            guard let openSettingsAction else {
                logger.error("Failed to open settings window")
                return
            }

            openSettingsAction()
        }
    }

    #if DEBUG
    func showShaderLabWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let shaderLabWindow {
            shaderLabWindow.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Shader Lab"
        window.contentViewController = NSHostingController(rootView: ShaderLabView())
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        shaderLabWindow = window
    }
    #endif

    @objc private func fireConfetti() {
        fire(.confetti)
    }

    @objc private func fireFlash() {
        fire(.flash)
    }

    @objc private func fireGlitch() {
        fire(.glitch)
    }

    @objc private func fireCRTBurst() {
        fire(.crtBurst)
    }

    @objc private func fireShockwave() {
        fire(.shockwave)
    }

    @objc private func fireCrackedGlass() {
        fire(.crackedGlass)
    }

    @objc private func fireNeonEdge() {
        fire(.neonEdge)
    }

    @objc private func fireRainGlass() {
        fire(.rainGlass)
    }

    @objc private func openSettings() {
        showSettingsWindow()
    }

    #if DEBUG
    @objc private func openShaderLab() {
        showShaderLabWindow()
    }
    #endif

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
