// AppDelegate.swift
// Manages the always-on-desktop overlay panel

import AppKit
import SwiftUI

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: NSPanel?
    private let store = TemperatureStore()
    private var dragStartMouse: NSPoint = .zero
    private var dragStartOrigin: NSPoint = .zero
    private var mouseDownMonitor: Any?
    private var mouseDragMonitor: Any?
    private var mouseUpMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupPanel()
        setupDragMonitors()
    }

    private func setupPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 20, y: 100, width: 300, height: 250),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        // normal レベル：デスクトップより上、他のアプリウィンドウより背面に回れる
        panel.level = .normal
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]

        let contentView = OverlayWindowView()
            .environmentObject(store)

        panel.contentView = NSHostingView(rootView: contentView)
        panel.orderFrontRegardless()
        self.panel = panel
    }

    private func setupDragMonitors() {
        mouseDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self, let panel = self.panel else { return event }
            if panel.frame.contains(NSEvent.mouseLocation) {
                self.dragStartMouse = NSEvent.mouseLocation
                self.dragStartOrigin = panel.frame.origin
            }
            return event
        }
        mouseDragMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDragged) { [weak self] event in
            guard let self, let panel = self.panel,
                  self.dragStartMouse != .zero else { return event }
            let loc = NSEvent.mouseLocation
            panel.setFrameOrigin(NSPoint(
                x: self.dragStartOrigin.x + loc.x - self.dragStartMouse.x,
                y: self.dragStartOrigin.y + loc.y - self.dragStartMouse.y
            ))
            return event
        }
        mouseUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
            self?.dragStartMouse = .zero
            return event
        }
    }
}
