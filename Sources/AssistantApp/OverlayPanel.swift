import AppKit
import SwiftUI

/// Small always-on-top panel. It can take keyboard focus (needed for the
/// temporary text field) but does not appear in Mission Control or the Dock.
final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }

    init(model: AskViewModel, onClose: @escaping () -> Void) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 460, height: 120),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)
        level = .floating
        isFloatingPanel = true
        hasShadow = false
        backgroundColor = .clear
        isOpaque = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        let host = NSHostingView(rootView: OverlayView(model: model, onClose: onClose))
        host.autoresizingMask = [.width, .height]
        contentView = host
        setContentSize(host.fittingSize)
    }

    /// Shows on the display the mouse is on, upper-middle of that screen.
    func present() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        if let frame = screen?.visibleFrame {
            let size = contentView?.fittingSize ?? frame.size
            setFrameOrigin(NSPoint(x: frame.midX - size.width / 2, y: frame.maxY - size.height - 120))
        }
        makeKeyAndOrderFront(nil)
    }
}
