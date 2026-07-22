import CoreGraphics
import Foundation

/// The two frame configurations used by the notch panel.
public enum PanelPresentation: Sendable, Equatable {
    case compact
    case expanded
}

/// Whether the app should add a visible surface below the physical notch.
/// Dormancy is intentionally modeled as window visibility instead of a
/// zero-height frame so AppKit never has to host an invalid interaction target.
public enum CompactPanelPresence: Sendable, Equatable {
    case dormant
    case unavailable
    case needsAttention(Int)
    case working(Int)
    case recentlyInterrupted(Int)
    case recentlyFinished(Int)

    public var isVisible: Bool {
        self != .dormant
    }
}

/// Resolves the single highest-priority state allowed to occupy the compact
/// notch surface. Quiet and historical states deliberately resolve to dormant.
public struct CompactPanelPresencePolicy: Sendable {
    public let completionVisibilityDuration: TimeInterval

    public init(completionVisibilityDuration: TimeInterval = 4) {
        self.completionVisibilityDuration = max(0, completionVisibilityDuration)
    }

    public func resolve(
        refreshFailed: Bool,
        needsAttentionCount: Int,
        workingCount: Int,
        completedActivityDates: [Date],
        interruptedActivityDates: [Date],
        now: Date = .now
    ) -> CompactPanelPresence {
        if refreshFailed {
            return .unavailable
        }

        let attentionCount = max(0, needsAttentionCount)
        if attentionCount > 0 {
            return .needsAttention(attentionCount)
        }

        let activeCount = max(0, workingCount)
        if activeCount > 0 {
            return .working(activeCount)
        }

        let recentlyInterruptedCount = recentCount(
            in: interruptedActivityDates,
            relativeTo: now
        )
        if recentlyInterruptedCount > 0 {
            return .recentlyInterrupted(recentlyInterruptedCount)
        }

        let recentlyFinishedCount = recentCount(
            in: completedActivityDates,
            relativeTo: now
        )
        if recentlyFinishedCount > 0 {
            return .recentlyFinished(recentlyFinishedCount)
        }

        return .dormant
    }

    private func recentCount(in dates: [Date], relativeTo now: Date) -> Int {
        dates.reduce(into: 0) { count, date in
            let age = now.timeIntervalSince(date)
            if age >= 0, age < completionVisibilityDuration {
                count += 1
            }
        }
    }
}

/// Decides whether a lifecycle state change represents a real, user-visible
/// completion. Keeping this rule separate from notification preferences lets
/// the compact notch celebrate once without replaying terminal tasks observed
/// during launch or source recovery.
public struct CompletionCelebrationPolicy: Sendable {
    public init() {}

    public func shouldCelebrate(
        previousState: CodexTaskDisplayState?,
        currentState: CodexTaskDisplayState,
        isRecent: Bool
    ) -> Bool {
        guard isRecent else { return false }

        switch (previousState, currentState) {
        case (.working?, .completed), (.needsAttention?, .completed):
            return true
        case (.none, _),
             (.completed?, _),
             (.interrupted?, _),
             (.idle?, _),
             (.unverified?, _),
             (.stale?, _),
             (.working?, _),
             (.needsAttention?, _):
            return false
        }
    }
}

/// A platform-neutral representation of the safe-area values supplied by `NSScreen`.
public struct PanelSafeAreaInsets: Sendable, Equatable {
    public var top: CGFloat
    public var left: CGFloat
    public var bottom: CGFloat
    public var right: CGFloat

    public init(
        top: CGFloat = 0,
        left: CGFloat = 0,
        bottom: CGFloat = 0,
        right: CGFloat = 0
    ) {
        self.top = top
        self.left = left
        self.bottom = bottom
        self.right = right
    }

    public static let zero = PanelSafeAreaInsets()
}

/// The subset of `NSScreen` geometry needed to position a panel.
///
/// Keeping this type free of AppKit makes the placement rules deterministic and
/// straightforward to exercise with synthetic multi-display arrangements.
public struct PanelScreenGeometry: Sendable {
    public var frame: CGRect
    public var visibleFrame: CGRect
    public var safeAreaInsets: PanelSafeAreaInsets
    public var auxiliaryTopLeftArea: CGRect?
    public var auxiliaryTopRightArea: CGRect?

    public init(
        frame: CGRect,
        visibleFrame: CGRect,
        safeAreaInsets: PanelSafeAreaInsets = .zero,
        auxiliaryTopLeftArea: CGRect? = nil,
        auxiliaryTopRightArea: CGRect? = nil
    ) {
        self.frame = frame
        self.visibleFrame = visibleFrame
        self.safeAreaInsets = safeAreaInsets
        self.auxiliaryTopLeftArea = auxiliaryTopLeftArea
        self.auxiliaryTopRightArea = auxiliaryTopRightArea
    }
}

/// Physical top-edge characteristics derived from a screen's AppKit geometry.
public struct PanelNotchMetrics: Sendable, Equatable {
    public var neckWidth: CGFloat
    public var reservedTopHeight: CGFloat
    public var hasHardwareNotch: Bool

    public init(
        neckWidth: CGFloat,
        reservedTopHeight: CGFloat,
        hasHardwareNotch: Bool
    ) {
        self.neckWidth = neckWidth
        self.reservedTopHeight = reservedTopHeight
        self.hasHardwareNotch = hasHardwareNotch
    }
}

/// Frames for the two-window implementation. The body is always below the
/// reserved top region, so no interactive window covers the menu-bar shoulders.
public struct PanelWindowFrames: Sendable {
    public var totalFrame: CGRect
    public var neckFrame: CGRect?
    public var bodyFrame: CGRect

    public init(totalFrame: CGRect, neckFrame: CGRect?, bodyFrame: CGRect) {
        self.totalFrame = totalFrame
        self.neckFrame = neckFrame
        self.bodyFrame = bodyFrame
    }
}

/// Pure frame calculations for the top-center notch panel.
public struct PanelGeometry: Sendable {
    public struct Metrics: Sendable {
        /// Compact stores the notchless fallback width and resting body height.
        /// On a hardware-notch display its width is replaced by the detected
        /// camera-gap width. Expanded stores its width and fallback body height.
        /// Both body heights are composed with the physical top reservation.
        public var compactSize: CGSize
        public var expandedSize: CGSize
        /// Bounds for a measured expanded body height. `expandedSize.height`
        /// remains the fallback body height until the view reports a value.
        public var expandedMinimumBodyHeight: CGFloat
        public var expandedMaximumBodyHeight: CGFloat
        public var notchRevealHeight: CGFloat
        public var horizontalScreenMargin: CGFloat
        public var bottomScreenMargin: CGFloat

        public init(
            compactSize: CGSize = CGSize(width: 220, height: 18),
            expandedSize: CGSize = CGSize(width: 720, height: 520),
            expandedMinimumBodyHeight: CGFloat = 300,
            expandedMaximumBodyHeight: CGFloat = 520,
            notchRevealHeight: CGFloat = 10,
            horizontalScreenMargin: CGFloat = 16,
            bottomScreenMargin: CGFloat = 16
        ) {
            self.compactSize = compactSize
            self.expandedSize = expandedSize
            self.expandedMinimumBodyHeight = expandedMinimumBodyHeight
            self.expandedMaximumBodyHeight = expandedMaximumBodyHeight
            self.notchRevealHeight = notchRevealHeight
            self.horizontalScreenMargin = horizontalScreenMargin
            self.bottomScreenMargin = bottomScreenMargin
        }

        public static let standard = Metrics()
    }

    public var metrics: Metrics

    public init(metrics: Metrics = .standard) {
        self.metrics = metrics
    }

    /// Returns a frame whose top edge is always attached to the physical screen's
    /// top edge and whose horizontal center follows that screen, including screens
    /// with negative global-coordinate origins.
    public func frame(
        for presentation: PanelPresentation,
        on screen: PanelScreenGeometry,
        expandedBodyHeight: CGFloat? = nil
    ) -> CGRect {
        let screenFrame = usableScreenFrame(from: screen.frame)
        let visibleFrame = usableVisibleFrame(screen.visibleFrame, within: screenFrame)
        let insets = sanitized(screen.safeAreaInsets)
        let notch = notchMetrics(on: screen)
        let requestedSize: CGSize
        switch presentation {
        case .compact:
            let fallbackBodySize = sanitized(metrics.compactSize)
            requestedSize = CGSize(
                width: notch.hasHardwareNotch
                    ? notch.neckWidth
                    : fallbackBodySize.width,
                height: notch.reservedTopHeight + fallbackBodySize.height
            )
        case .expanded:
            let fallbackSize = sanitized(metrics.expandedSize)
            let bodyHeight = resolvedExpandedBodyHeight(
                expandedBodyHeight ?? fallbackSize.height
            )
            requestedSize = CGSize(
                width: fallbackSize.width,
                height: topReservedHeight(on: screen) + bodyHeight
            )
        }

        let horizontalMargin = nonnegative(metrics.horizontalScreenMargin)
        let bottomMargin = nonnegative(metrics.bottomScreenMargin)
        let safeWidth = max(
            1,
            screenFrame.width - insets.left - insets.right
        )
        let availableWidth = max(
            1,
            min(safeWidth, visibleFrame.width) - (horizontalMargin * 2)
        )
        let width = min(requestedSize.width, availableWidth)

        let lowerBoundary = max(
            screenFrame.minY + insets.bottom,
            visibleFrame.minY
        )
        let availableHeight = max(
            1,
            screenFrame.maxY - lowerBoundary - bottomMargin
        )
        let minimumTopHeight = topReservedHeight(on: screen)
            + nonnegative(metrics.notchRevealHeight)
        let desiredHeight = max(requestedSize.height, minimumTopHeight)
        let height = min(desiredHeight, availableHeight)
        let horizontalAnchor = hardwareNotchGap(
            on: screen,
            within: screenFrame
        )?.midX ?? screenFrame.midX

        return CGRect(
            x: horizontalAnchor - (width / 2),
            y: screenFrame.maxY - height,
            width: width,
            height: height
        )
    }

    /// Splits the total top-anchored surface into a narrow hardware-neck window
    /// and an interactive body window whose top edge begins below the obstruction.
    public func windowFrames(
        for presentation: PanelPresentation,
        on screen: PanelScreenGeometry,
        expandedBodyHeight: CGFloat? = nil
    ) -> PanelWindowFrames {
        let totalFrame = frame(
            for: presentation,
            on: screen,
            expandedBodyHeight: expandedBodyHeight
        )
        let notch = notchMetrics(on: screen)
        let reservedHeight = min(
            notch.reservedTopHeight,
            max(0, totalFrame.height - 1)
        )
        let bodyFrame = CGRect(
            x: totalFrame.minX,
            y: totalFrame.minY,
            width: totalFrame.width,
            height: max(1, totalFrame.height - reservedHeight)
        )

        let neckFrame: CGRect?
        if notch.hasHardwareNotch,
           let gap = hardwareNotchGap(on: screen, within: screen.frame),
           reservedHeight > 0 {
            neckFrame = CGRect(
                x: gap.minX,
                y: totalFrame.maxY - reservedHeight,
                width: gap.width,
                height: reservedHeight
            )
        } else {
            neckFrame = nil
        }

        return PanelWindowFrames(
            totalFrame: totalFrame,
            neckFrame: neckFrame,
            bodyFrame: bodyFrame
        )
    }

    /// The portion at the top that can be occupied by a menu bar or camera housing.
    /// Views can use this to keep interactive content below the physical obstruction.
    public func topReservedHeight(on screen: PanelScreenGeometry) -> CGFloat {
        notchMetrics(on: screen).reservedTopHeight
    }

    /// Derives the real camera-housing gap from the two unobscured top areas that
    /// AppKit reports. Supplying only a safe-area inset is not enough to claim a
    /// hardware notch because a normal menu bar can produce the same top spacing.
    public func notchMetrics(on screen: PanelScreenGeometry) -> PanelNotchMetrics {
        let screenFrame = usableScreenFrame(from: screen.frame)
        let visibleFrame = usableVisibleFrame(screen.visibleFrame, within: screenFrame)
        let menuBarHeight = max(0, screenFrame.maxY - visibleFrame.maxY)
        let safeAreaHeight = nonnegative(screen.safeAreaInsets.top)
        var reservedTopHeight = max(safeAreaHeight, menuBarHeight)

        guard let gap = hardwareNotchGap(on: screen, within: screenFrame) else {
            return PanelNotchMetrics(
                neckWidth: 0,
                reservedTopHeight: reservedTopHeight,
                hasHardwareNotch: false
            )
        }

        reservedTopHeight = max(
            reservedTopHeight,
            gap.leftArea.height,
            gap.rightArea.height
        )

        let hasHardwareNotch = reservedTopHeight > 0

        return PanelNotchMetrics(
            neckWidth: hasHardwareNotch ? gap.width : 0,
            reservedTopHeight: reservedTopHeight,
            hasHardwareNotch: hasHardwareNotch
        )
    }

    /// Sanitizes and clamps a height measured by the expanded SwiftUI surface.
    /// This is intentionally a body-window height: the reserved camera/menu-bar
    /// region is composed separately so the panel's top attachment cannot drift.
    public func resolvedExpandedBodyHeight(_ requestedHeight: CGFloat) -> CGFloat {
        let configuredMinimum = nonnegative(metrics.expandedMinimumBodyHeight)
        let configuredMaximum = nonnegative(metrics.expandedMaximumBodyHeight)
        let lowerBound = min(configuredMinimum, configuredMaximum)
        let upperBound = max(configuredMinimum, configuredMaximum)
        let fallbackBodyHeight = max(
            lowerBound,
            sanitized(metrics.expandedSize).height
        )
        let sanitizedRequest = requestedHeight.isFinite
            ? max(0, requestedHeight)
            : fallbackBodyHeight

        return min(max(sanitizedRequest, lowerBound), upperBound)
    }

    private func usableScreenFrame(from frame: CGRect) -> CGRect {
        guard frame.width.isFinite,
              frame.height.isFinite,
              frame.minX.isFinite,
              frame.minY.isFinite,
              frame.width > 0,
              frame.height > 0 else {
            return CGRect(x: 0, y: 0, width: 1, height: 1)
        }

        return frame.standardized
    }

    private func usableVisibleFrame(_ visibleFrame: CGRect, within screenFrame: CGRect) -> CGRect {
        guard visibleFrame.width.isFinite,
              visibleFrame.height.isFinite,
              visibleFrame.minX.isFinite,
              visibleFrame.minY.isFinite,
              visibleFrame.width > 0,
              visibleFrame.height > 0 else {
            return screenFrame
        }

        let intersection = screenFrame.intersection(visibleFrame.standardized)
        return intersection.isNull || intersection.isEmpty ? screenFrame : intersection
    }

    private func usableAuxiliaryArea(_ area: CGRect?, within screenFrame: CGRect) -> CGRect? {
        guard let area,
              area.width.isFinite,
              area.height.isFinite,
              area.minX.isFinite,
              area.minY.isFinite,
              area.width > 0,
              area.height > 0 else {
            return nil
        }

        let intersection = screenFrame.intersection(area.standardized)
        guard !intersection.isNull,
              !intersection.isEmpty,
              abs(intersection.maxY - screenFrame.maxY) <= 1 else {
            return nil
        }

        return intersection
    }

    private func hardwareNotchGap(
        on screen: PanelScreenGeometry,
        within rawScreenFrame: CGRect
    ) -> HardwareNotchGap? {
        let screenFrame = usableScreenFrame(from: rawScreenFrame)
        guard let leftArea = usableAuxiliaryArea(
            screen.auxiliaryTopLeftArea,
            within: screenFrame
        ), let rightArea = usableAuxiliaryArea(
            screen.auxiliaryTopRightArea,
            within: screenFrame
        ) else {
            return nil
        }

        let width = rightArea.minX - leftArea.maxX
        let containsDisplayCenter = leftArea.maxX < screenFrame.midX
            && rightArea.minX > screenFrame.midX
        guard width.isFinite, width > 0, containsDisplayCenter else {
            return nil
        }

        return HardwareNotchGap(
            minX: leftArea.maxX,
            width: width,
            leftArea: leftArea,
            rightArea: rightArea
        )
    }

    private func sanitized(_ size: CGSize) -> CGSize {
        CGSize(
            width: size.width.isFinite ? max(1, size.width) : 1,
            height: size.height.isFinite ? max(1, size.height) : 1
        )
    }

    private func sanitized(_ insets: PanelSafeAreaInsets) -> PanelSafeAreaInsets {
        PanelSafeAreaInsets(
            top: nonnegative(insets.top),
            left: nonnegative(insets.left),
            bottom: nonnegative(insets.bottom),
            right: nonnegative(insets.right)
        )
    }

    private func nonnegative(_ value: CGFloat) -> CGFloat {
        value.isFinite ? max(0, value) : 0
    }
}

private struct HardwareNotchGap {
    let minX: CGFloat
    let width: CGFloat
    let leftArea: CGRect
    let rightArea: CGRect

    var midX: CGFloat {
        minX + (width / 2)
    }
}
