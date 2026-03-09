import SwiftUI

@main
struct OverHyperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate

    private let settingsStore = EffectSettingsStore.shared

    var body: some Scene {
        Settings {
            SettingsView(settingsStore: settingsStore)
        }
    }
}
