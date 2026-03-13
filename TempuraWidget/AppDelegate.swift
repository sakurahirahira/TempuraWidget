// AppDelegate.swift
// Manages the always-on-desktop overlay panel

import AppKit
import SwiftUI
import ServiceManagement

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: NSPanel?
    private let store = TemperatureStore()
    private var dragStartMouse: NSPoint = .zero
    private var dragStartOrigin: NSPoint = .zero
    private var mouseDownMonitor: Any?
    private var mouseDragMonitor: Any?
    private var mouseUpMonitor: Any?
    private var statusItem: NSStatusItem?
    private var isHiddenByFullscreen = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupPanel()
        setupDragMonitors()
        setupStatusItem()
        setupFullscreenObserver()
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "thermometer.medium", accessibilityDescription: "TempuraWidget")
        }
        statusItem?.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let versionItem = NSMenuItem(title: "TempuraWidget 1.0", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)

        menu.addItem(.separator())

        let showItem = NSMenuItem(title: "ウィジェットを表示", action: #selector(toggleWidget), keyEquivalent: "")
        showItem.target = self
        showItem.state = (panel?.isVisible == true) ? .on : .off
        menu.addItem(showItem)

        menu.addItem(.separator())

        let loginItem = NSMenuItem(title: "ログイン時に自動起動", action: #selector(toggleLoginItem), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = isLoginItemEnabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        return menu
    }

    @objc private func toggleWidget() {
        guard let panel else { return }
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.orderFrontRegardless()
        }
        isHiddenByFullscreen = false  // 手動操作でフルスクリーン状態をリセット
        statusItem?.menu = buildMenu()
    }

    // MARK: - Login Item

    private var isLoginItemEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @objc private func toggleLoginItem() {
        do {
            if isLoginItemEnabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("LoginItem toggle failed: %@", error.localizedDescription)
        }
        statusItem?.menu = buildMenu()
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
        panel.collectionBehavior = [.stationary]

        let contentView = OverlayWindowView()
            .environmentObject(store)

        panel.contentView = NSHostingView(rootView: contentView)
        panel.orderFrontRegardless()
        self.panel = panel
    }

    // MARK: - Fullscreen Detection

    private func setupFullscreenObserver() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(spaceChanged),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
    }

    @objc private func spaceChanged() {
        // スペース切り替えアニメーション完了を待ってから判定
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.updatePanelForCurrentSpace()
        }
    }

    private func updatePanelForCurrentSpace() {
        guard let panel else { return }
        let fullscreen = isCurrentSpaceFullscreen()

        if fullscreen && !isHiddenByFullscreen {
            panel.orderOut(nil)
            isHiddenByFullscreen = true
            statusItem?.menu = buildMenu()
        } else if !fullscreen && isHiddenByFullscreen {
            panel.orderFrontRegardless()
            isHiddenByFullscreen = false
            statusItem?.menu = buildMenu()
        }
    }

    /// メニューバーが表示されていない = フルスクリーンスペースと判定
    private func isCurrentSpaceFullscreen() -> Bool {
        guard let screen = NSScreen.main else { return false }
        return screen.visibleFrame.maxY >= screen.frame.maxY
            && abs(screen.visibleFrame.height - screen.frame.height) < 10
    }

    // MARK: - Drag

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
