// DraggableHostingView.swift
// NSHostingView subclass that forwards mouseDown to window drag

import AppKit
import SwiftUI

final class DraggableHostingView<Content: View>: NSHostingView<Content> {
    private var dragStartLocation: NSPoint?
    private var dragStartFrame: NSRect?

    override func mouseDown(with event: NSEvent) {
        dragStartLocation = NSEvent.mouseLocation
        dragStartFrame = window?.frame
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStartLocation,
              let startFrame = dragStartFrame,
              let window = window else { return }
        let current = NSEvent.mouseLocation
        let dx = current.x - start.x
        let dy = current.y - start.y
        window.setFrameOrigin(NSPoint(x: startFrame.origin.x + dx,
                                     y: startFrame.origin.y + dy))
    }
}
