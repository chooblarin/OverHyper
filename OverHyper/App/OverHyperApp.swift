import SwiftUI

@main
struct OverHyperApp: App {
    private static let settingsWindowID = "settings"

    @NSApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate

    @Environment(\.openWindow)
    private var openWindow

    private let settingsStore = EffectSettingsStore.shared

    var body: some Scene {
        let openSettingsWindow = { @MainActor in
            openWindow(id: Self.settingsWindowID)
        }
        appDelegate.setOpenSettingsAction(openSettingsWindow)

        return Window("Settings", id: Self.settingsWindowID) {
            SettingsView(settingsStore: settingsStore) { effect in
                appDelegate.fire(effect)
            }
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    appDelegate.showSettingsWindow()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
