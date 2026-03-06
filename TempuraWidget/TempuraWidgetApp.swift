// TempuraWidgetApp.swift
import SwiftUI

@main
struct TempuraWidgetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No default window — AppDelegate manages the overlay panel
        Settings { EmptyView() }
    }
}
