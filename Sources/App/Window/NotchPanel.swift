import AppKit
import CodexNotchCore

/// The small amount of AppKit needed for a top-center SwiftUI surface.
///
/// The panel stays nonactivating so opening it does not pull the user out of the
/// application they are supervising. It becomes eligible for key status only
/// while expanded, which keeps compact clicks lightweight while still allowing
/// keyboard traversal and Escape in the expanded dashboard.
@MainActor
final class NotchPanel: NSPanel {
    var onRequestCollapse: (() -> Void)?

    private(set) var presentation: PanelPresentation = .compact

    override var canBecomeKey: Bool {
        presentation == .expanded
    }

    override var canBecomeMain: Bool {
        false
    }

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
        becomesKeyOnlyIfNeeded = true
        worksWhenModal = false
        acceptsMouseMovedEvents = true
        ignoresMouseEvents = false
        isRestorable = false
    }

    func setPresentation(
        _ presentation: PanelPresentation,
        orderFront: Bool = true
    ) {
        self.presentation = presentation
        becomesKeyOnlyIfNeeded = presentation == .compact

        switch presentation {
        case .compact:
            if isKeyWindow {
                resignKey()
            }
            if orderFront {
                orderFrontRegardless()
            }
        case .expanded:
            if orderFront {
                makeKeyAndOrderFront(nil)
            }
        }
    }

    override func cancelOperation(_ sender: Any?) {
        guard presentation == .expanded else {
            super.cancelOperation(sender)
            return
        }

        onRequestCollapse?()
    }

    override func keyDown(with event: NSEvent) {
        if presentation == .expanded, event.keyCode == 53 {
            onRequestCollapse?()
            return
        }

        super.keyDown(with: event)
    }
}
