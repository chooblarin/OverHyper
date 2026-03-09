import AppKit
import MASShortcut
import SwiftUI

struct MASShortcutRecorderField: NSViewRepresentable {
    let defaultsKey: String

    func makeNSView(context: Context) -> MASShortcutView {
        let shortcutView = MASShortcutView(frame: NSRect(x: 0, y: 0, width: 180, height: 25))
        shortcutView.style = .regularSquare
        shortcutView.setAssociatedUserDefaultsKey(
            defaultsKey,
            withTransformerName: MASDictionaryTransformerName
        )
        return shortcutView
    }

    func updateNSView(_ nsView: MASShortcutView, context: Context) {
        if nsView.associatedUserDefaultsKey != defaultsKey {
            nsView.setAssociatedUserDefaultsKey(
                defaultsKey,
                withTransformerName: MASDictionaryTransformerName
            )
        }
    }
}
