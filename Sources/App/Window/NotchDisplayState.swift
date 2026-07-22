import CoreGraphics
import CodexNotchCore
import Observation

/// Live hardware-notch characteristics for the screen currently hosting the panel.
/// SwiftUI can observe this state to keep the top neck opaque while leaving the
/// menu-bar shoulders transparent.
@MainActor
@Observable
final class NotchDisplayState {
    private(set) var neckWidth: CGFloat
    private(set) var reservedTopHeight: CGFloat
    private(set) var hasHardwareNotch: Bool

    init(
        neckWidth: CGFloat = 0,
        reservedTopHeight: CGFloat = 0,
        hasHardwareNotch: Bool = false
    ) {
        self.neckWidth = neckWidth
        self.reservedTopHeight = reservedTopHeight
        self.hasHardwareNotch = hasHardwareNotch
    }

    func update(with metrics: PanelNotchMetrics) {
        neckWidth = metrics.neckWidth
        reservedTopHeight = metrics.reservedTopHeight
        hasHardwareNotch = metrics.hasHardwareNotch
    }
}
