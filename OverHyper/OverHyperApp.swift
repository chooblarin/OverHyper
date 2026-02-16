//
//  OverHyperApp.swift
//  OverHyper
//
//  Created by Sota Hatakeyama on 2026/02/16.
//

import SwiftUI

@main
struct OverHyperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
