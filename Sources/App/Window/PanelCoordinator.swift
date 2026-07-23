import AppKit
import CodexNotchCore
import SwiftUI

/// Owns the AppKit window lifecycle while allowing the visible dashboard to stay
/// entirely in SwiftUI.
@MainActor
final class PanelCoordinator: NSObject {
    typealias ContentFactory = (NotchDisplayState) -> AnyView

    private let geometry: PanelGeometry
    private let contentFactory: ContentFactory
    private let neckPanel: NSPanel
    private let panel: NotchPanel
    private let hostingView: NSHostingView<AnyView>

    private var targetScreen: NSScreen?
    private var compactClickRecognizer: NSClickGestureRecognizer?
    private var globalMouseMonitor: EventMonitorToken?
    private var localMouseMonitor: EventMonitorToken?
    private var compactBodyHeight: CGFloat
    private var expandedBodyHeight: CGFloat?

    private(set) var presentation: PanelPresentation = .compact
    let displayState: NotchDisplayState
    var onPresentationChange: ((PanelPresentation) -> Void)?
    var onRequestCollapse: (() -> Void)?

    var window: NSWindow {
        panel
    }

    var isVisible: Bool {
        panel.isVisible
    }

    init(
        geometry: PanelGeometry = PanelGeometry(),
        displayState: NotchDisplayState = NotchDisplayState(),
        content: @escaping ContentFactory
    ) {
        self.geometry = geometry
        self.displayState = displayState
        self.contentFactory = content
        self.neckPanel = Self.makeNeckPanel()
        self.panel = NotchPanel()
        self.hostingView = NSHostingView(rootView: content(displayState))
        self.compactBodyHeight = geometry.resolvedCompactBodyHeight(
            geometry.metrics.compactSize.height
        )
        super.init()

        configureHostedContent()
        configurePanelCallbacks()
        observeDisplayChanges()
    }

    convenience init<Content: View>(
        geometry: PanelGeometry = PanelGeometry(),
        displayState: NotchDisplayState = NotchDisplayState(),
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(geometry: geometry, displayState: displayState) { _ in
            AnyView(content())
        }
    }

    convenience init<Content: View>(
        geometry: PanelGeometry = PanelGeometry(),
        displayState: NotchDisplayState = NotchDisplayState(),
        @ViewBuilder content: @escaping (NotchDisplayState) -> Content
    ) {
        self.init(geometry: geometry, displayState: displayState) { state in
            AnyView(content(state))
        }
    }

    deinit {
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor.value)
        }
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor.value)
        }
        NotificationCenter.default.removeObserver(self)
    }

    /// Rebuilds the hosted root. Most callers can rely on observable SwiftUI state;
    /// this is available for integrations that need to swap the root hierarchy.
    func refreshContent() {
        hostingView.rootView = contentFactory(displayState)
    }

    func showCompact(on screen: NSScreen? = nil, animated: Bool = true) {
        guard let resolvedScreen = resolvedScreen(
            preferred: screen ?? targetScreen
        ) else {
            return
        }
        guard geometry.notchMetrics(
            on: resolvedScreen.panelScreenGeometry
        ).hasHardwareNotch else {
            concealCompact(on: resolvedScreen)
            return
        }
        present(.compact, on: resolvedScreen, animated: animated)
    }

    func showExpanded(on screen: NSScreen? = nil, animated: Bool = true) {
        present(.expanded, on: screen, animated: animated)
    }

    func toggle(on screen: NSScreen? = nil, animated: Bool = true) {
        switch presentation {
        case .compact:
            showExpanded(on: screen, animated: animated)
        case .expanded:
            collapse(animated: animated)
        }
    }

    func collapse(animated: Bool = true) {
        guard presentation == .expanded else { return }
        if let onRequestCollapse {
            onRequestCollapse()
        } else {
            showCompact(animated: animated)
        }
    }

    /// Enters logical compact mode without drawing anything below the physical
    /// notch. The native menu-bar item remains the dormant access point.
    func concealCompact(on preferredScreen: NSScreen? = nil) {
        guard let screen = resolvedScreen(preferred: preferredScreen ?? targetScreen) else {
            return
        }

        targetScreen = screen
        presentation = .compact
        compactClickRecognizer?.isEnabled = true
        removeOutsideClickMonitors()

        neckPanel.orderOut(nil)
        panel.orderOut(nil)
        panel.alphaValue = 1
        panel.setPresentation(.compact, orderFront: false)
        applyFrame(for: .compact, on: screen, animated: false)
        onPresentationChange?(.compact)
    }

    /// Applies the expanded surface's measured body height while keeping the
    /// physical neck window fixed. Invalid/transient zero measurements are
    /// ignored to avoid a disappear-time resize.
    func updateExpandedBodyHeight(_ height: CGFloat, animated: Bool = true) {
        guard height.isFinite, height > 0 else { return }

        let resolvedHeight = geometry.resolvedExpandedBodyHeight(height)
        if let expandedBodyHeight,
           abs(expandedBodyHeight - resolvedHeight) < 1 {
            return
        }

        expandedBodyHeight = resolvedHeight
        guard presentation == .expanded,
              let screen = resolvedScreen(preferred: targetScreen) else {
            return
        }

        targetScreen = screen
        applyFrame(for: .expanded, on: screen, animated: animated)
    }

    func updateCompactBodyHeight(_ height: CGFloat, animated: Bool = true) {
        let resolvedHeight = geometry.resolvedCompactBodyHeight(height)
        guard abs(compactBodyHeight - resolvedHeight) >= 1 else { return }

        compactBodyHeight = resolvedHeight
        guard presentation == .compact,
              panel.isVisible,
              let screen = resolvedScreen(preferred: targetScreen) else {
            return
        }

        targetScreen = screen
        applyFrame(for: .compact, on: screen, animated: animated)
    }

    func hide() {
        removeOutsideClickMonitors()
        neckPanel.orderOut(nil)
        panel.orderOut(nil)
        panel.alphaValue = 1
    }

    func reanchor(animated: Bool = false) {
        guard let screen = resolvedScreen(preferred: targetScreen) else { return }
        targetScreen = screen
        applyFrame(for: presentation, on: screen, animated: animated)
        updateNeckVisibility()
    }

    private func configureHostedContent() {
        let containerView = NSView(frame: .zero)
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.clear.cgColor

        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.sizingOptions = []
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        containerView.addSubview(hostingView)

        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: containerView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        panel.contentView = containerView

        let recognizer = NSClickGestureRecognizer(
            target: self,
            action: #selector(compactSurfaceClicked(_:))
        )
        hostingView.addGestureRecognizer(recognizer)
        compactClickRecognizer = recognizer
    }

    private func configurePanelCallbacks() {
        panel.onRequestCollapse = { [weak self] in
            self?.collapse()
        }
    }

    private func observeDisplayChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    private func present(
        _ presentation: PanelPresentation,
        on preferredScreen: NSScreen?,
        animated: Bool
    ) {
        guard let screen = resolvedScreen(preferred: preferredScreen ?? targetScreen) else {
            return
        }

        targetScreen = screen
        self.presentation = presentation
        compactClickRecognizer?.isEnabled = presentation == .compact

        let shouldFadeInCompact = presentation == .compact
            && !panel.isVisible
            && animated
            && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        panel.alphaValue = shouldFadeInCompact ? 0 : 1

        applyFrame(for: presentation, on: screen, animated: animated)
        panel.setPresentation(presentation)
        updateNeckVisibility()

        if shouldFadeInCompact {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.14
                panel.animator().alphaValue = 1
            }
        }

        switch presentation {
        case .compact:
            removeOutsideClickMonitors()
        case .expanded:
            installOutsideClickMonitors()
        }

        onPresentationChange?(presentation)
    }

    private func applyFrame(
        for presentation: PanelPresentation,
        on screen: NSScreen,
        animated: Bool
    ) {
        let screenGeometry = screen.panelScreenGeometry
        displayState.update(with: geometry.notchMetrics(on: screenGeometry))
        let targetFrames = geometry.windowFrames(
            for: presentation,
            on: screenGeometry,
            compactBodyHeight: presentation == .compact
                ? compactBodyHeight
                : nil,
            expandedBodyHeight: presentation == .expanded
                ? expandedBodyHeight
                : nil
        )
        let shouldAnimate = animated
            && panel.isVisible
            && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        if let neckFrame = targetFrames.neckFrame {
            neckPanel.setFrame(neckFrame, display: true, animate: false)
        } else {
            neckPanel.orderOut(nil)
        }
        panel.setFrame(targetFrames.bodyFrame, display: true, animate: shouldAnimate)
    }

    private func updateNeckVisibility() {
        if panel.isVisible, displayState.hasHardwareNotch {
            neckPanel.orderFrontRegardless()
        } else {
            neckPanel.orderOut(nil)
        }
    }

    private func resolvedScreen(preferred: NSScreen?) -> NSScreen? {
        if let preferred,
           NSScreen.screens.contains(where: { $0 === preferred }) {
            return preferred
        }

        let pointerLocation = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(pointerLocation) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }

    private func installOutsideClickMonitors() {
        guard globalMouseMonitor == nil, localMouseMonitor == nil else { return }

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.collapse()
            }
        }.map(EventMonitorToken.init)

        localMouseMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            let clickedWindowNumber = event.windowNumber
            Task { @MainActor [weak self] in
                guard let self,
                      clickedWindowNumber != self.panel.windowNumber else {
                    return
                }
                self.collapse()
            }
            return event
        }.map(EventMonitorToken.init)
    }

    private func removeOutsideClickMonitors() {
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor.value)
            self.globalMouseMonitor = nil
        }
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor.value)
            self.localMouseMonitor = nil
        }
    }

    @objc
    private func compactSurfaceClicked(_ recognizer: NSClickGestureRecognizer) {
        guard recognizer.state == .ended, presentation == .compact else { return }
        showExpanded()
    }

    @objc
    private func screenParametersDidChange(_ notification: Notification) {
        reanchor()
    }

    private static func makeNeckPanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = true
        panel.backgroundColor = .black
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .transient,
            .ignoresCycle
        ]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.isExcludedFromWindowsMenu = true
        panel.tabbingMode = .disallowed
        panel.animationBehavior = .none
        panel.ignoresMouseEvents = true
        panel.isRestorable = false

        let fillView = NSView(frame: .zero)
        fillView.wantsLayer = true
        fillView.layer?.backgroundColor = NSColor.black.cgColor
        panel.contentView = fillView
        return panel
    }
}

/// AppKit exposes event-monitor handles as `Any`. The monitor is only created and
/// removed on the main actor, and this wrapper lets Swift 6 safely tear it down
/// from an actor-isolated owner's nonisolated deinitializer.
private final class EventMonitorToken: @unchecked Sendable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }
}

private extension NSScreen {
    var panelScreenGeometry: PanelScreenGeometry {
        let insets = safeAreaInsets
        return PanelScreenGeometry(
            frame: frame,
            visibleFrame: visibleFrame,
            safeAreaInsets: PanelSafeAreaInsets(
                top: insets.top,
                left: insets.left,
                bottom: insets.bottom,
                right: insets.right
            ),
            auxiliaryTopLeftArea: self.auxiliaryTopLeftArea,
            auxiliaryTopRightArea: self.auxiliaryTopRightArea
        )
    }
}
