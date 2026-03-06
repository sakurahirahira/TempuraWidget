// AppDelegate.swift
// Manages the always-on-desktop overlay panel

import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: NSPanel?
    private let store = TemperatureStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupPanel()
    }

    private func setupPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 20, y: 100, width: 300, height: 250),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)))
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]

        let contentView = OverlayWindowView()
            .environmentObject(store)

        panel.contentView = DraggableHostingView(rootView: contentView)
        panel.orderFrontRegardless()
        self.panel = panel
    }
}
