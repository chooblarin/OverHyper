import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {

    var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.title = "⚡️"
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Fire Confetti", action: #selector(fire), keyEquivalent: "f"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit OverHyper", action: #selector(quit), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    @objc private func fire() {
        print("🔥 OverHyper!")
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
