import SwiftUI

struct NotchRootView: View {
    let runtime: AppRuntime
    let displayState: NotchDisplayState?

    init(runtime: AppRuntime) {
        self.runtime = runtime
        self.displayState = nil
    }

    init(runtime: AppRuntime, displayState: NotchDisplayState) {
        self.runtime = runtime
        self.displayState = displayState
    }

    private var neckWidth: CGFloat {
        displayState?.neckWidth ?? 0
    }

    private var hasHardwareNotch: Bool {
        displayState?.hasHardwareNotch ?? false
    }

    var body: some View {
        ZStack(alignment: .top) {
            switch runtime.surface {
            case .compact:
                CompactStatusView(
                    store: runtime.store,
                    presence: runtime.compactPresence,
                    completionCelebration: runtime.completionCelebration,
                    neckWidth: neckWidth,
                    hasHardwareNotch: hasHardwareNotch,
                    onExpand: {
                        runtime.showDashboard()
                    }
                )

            case .dashboard:
                DashboardView(
                    store: runtime.store,
                    neckWidth: neckWidth,
                    hasHardwareNotch: hasHardwareNotch,
                    onPreferredBodyHeight: { height in
                        runtime.updateExpandedBodyHeight(
                            height,
                            for: .dashboard
                        )
                    },
                    onCollapse: {
                        runtime.showCompact()
                    },
                    onOpenSettings: {
                        runtime.showSettings()
                    }
                )

            case .settings:
                SettingsView(
                    store: runtime.store,
                    neckWidth: neckWidth,
                    hasHardwareNotch: hasHardwareNotch,
                    notificationPermissionDenied: runtime.notificationPermissionDenied,
                    onNotificationsChange: { enabled in
                        runtime.setNotificationsEnabled(enabled)
                    },
                    onPreviewCompletion: {
                        runtime.previewCompletionFeedback()
                    },
                    onPreferredBodyHeight: { height in
                        runtime.updateExpandedBodyHeight(
                            height,
                            for: .settings
                        )
                    },
                    onDismiss: {
                        runtime.dismissSettings()
                    }
                )
            }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .top
        )
        .preferredColorScheme(.dark)
    }
}
