import AppKit
import SwiftUI

/// Presents completion feedback above the current workspace without activating
/// Codex Notch or consuming any input from the app underneath it.
@MainActor
final class CompletionOverlayCoordinator {
    static let displayDuration: Duration = .milliseconds(2_400)

    private var panel: CompletionOverlayPanel?

    func present(_ event: CompletionCelebrationEvent) {
        guard let screen = resolvedScreen() else { return }

        let panel = panel ?? CompletionOverlayPanel()
        let hostingView = NSHostingView(
            rootView: AnyView(
                FullScreenCompletionCelebrationView(event: event)
                    .id(event.id)
            )
        )
        hostingView.sizingOptions = []
        hostingView.frame = NSRect(origin: .zero, size: screen.frame.size)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor

        panel.contentView = hostingView
        panel.setFrame(screen.frame, display: true, animate: false)
        panel.orderFrontRegardless()
        self.panel = panel
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel?.contentView = nil
    }

    private func resolvedScreen() -> NSScreen? {
        let pointerLocation = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(pointerLocation) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }
}

@MainActor
private final class CompletionOverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar
        collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .transient,
            .ignoresCycle
        ]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovable = false
        isMovableByWindowBackground = false
        isExcludedFromWindowsMenu = true
        tabbingMode = .disallowed
        animationBehavior = .none
        worksWhenModal = false
        acceptsMouseMovedEvents = false
        ignoresMouseEvents = true
        isRestorable = false
    }
}
