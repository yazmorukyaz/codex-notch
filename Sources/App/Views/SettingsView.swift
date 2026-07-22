import SwiftUI
import CodexNotchCore

struct SettingsView: View {
    @Bindable var store: DashboardStore
    let neckWidth: CGFloat
    let hasHardwareNotch: Bool
    let notificationPermissionDenied: Bool
    let onNotificationsChange: (Bool) -> Void
    let onPreferredBodyHeight: (CGFloat) -> Void
    let onDismiss: () -> Void

    @State private var lastReportedBodyHeight: CGFloat = 0

    init(
        store: DashboardStore,
        neckWidth: CGFloat = 185,
        hasHardwareNotch: Bool = true,
        notificationPermissionDenied: Bool = false,
        onNotificationsChange: @escaping (Bool) -> Void = { _ in },
        onPreferredBodyHeight: @escaping (CGFloat) -> Void = { _ in },
        onDismiss: @escaping () -> Void = {}
    ) {
        self.store = store
        self.neckWidth = neckWidth
        self.hasHardwareNotch = hasHardwareNotch
        self.notificationPermissionDenied = notificationPermissionDenied
        self.onNotificationsChange = onNotificationsChange
        self.onPreferredBodyHeight = onPreferredBodyHeight
        self.onDismiss = onDismiss
    }

    private let flareHeight: CGFloat = 18

    private var displayedHealth: CodexSourceHealth {
        if store.lastRefreshFailedAt != nil {
            return .unavailable("The latest refresh failed")
        }
        return store.snapshot.health
    }

    private var notificationsBinding: Binding<Bool> {
        Binding(
            get: { store.notificationsEnabled },
            set: { isEnabled in
                onNotificationsChange(isEnabled)
            }
        )
    }

    var body: some View {
        GeometryReader { geometry in
            let contentTop = NotchDropShape.bodyTop(
                in: geometry.size.height,
                flareHeight: flareHeight,
                hasHardwareNotch: hasHardwareNotch
            )
            let shell = NotchDropShape(
                neckWidth: neckWidth,
                flareHeight: flareHeight,
                outerTopCornerRadius: 20,
                bottomCornerRadius: 20,
                hasHardwareNotch: hasHardwareNotch
            )

            ZStack(alignment: .top) {
                shell
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.045, green: 0.049, blue: 0.055),
                                Color(red: 0.018, green: 0.020, blue: 0.024),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Settings")
                                .font(.system(size: 16, weight: .semibold))

                            Text("Choose what the notch can reveal and interrupt you for.")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.white.opacity(0.58))
                        }

                        Spacer()

                        Button(action: onDismiss) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.72))
                                .frame(width: 28, height: 28)
                                .background(Color.white.opacity(0.055), in: Circle())
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Close settings")
                        .accessibilityLabel("Close settings")
                    }

                    VStack(spacing: 0) {
                        SettingToggleRow(
                            title: "Notifications",
                            detail: "Alert only when a task finishes or needs you.",
                            systemImage: "bell.fill",
                            isOn: notificationsBinding
                        )

                        if notificationPermissionDenied {
                            HStack(spacing: 7) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text("Notifications are blocked in System Settings.")
                            }
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(StatusBadgeKind.needsAttention.tint)
                            .padding(.horizontal, 13)
                            .padding(.bottom, 10)
                        }

                        Divider()
                            .overlay(Color.white.opacity(0.08))

                        SettingToggleRow(
                            title: "Quiet mode",
                            detail: "Keep monitoring, but suppress enabled notifications.",
                            systemImage: "moon.fill",
                            isOn: $store.quietMode
                        )

                        Divider()
                            .overlay(Color.white.opacity(0.08))

                        SettingToggleRow(
                            title: "Privacy mode",
                            detail: "Hide task, project, and activity details in the panel.",
                            systemImage: "eye.slash.fill",
                            isOn: $store.privacyMode
                        )
                    }
                    .background(Color.white.opacity(0.035))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.075), lineWidth: 0.75)
                            .allowsHitTesting(false)
                    }

                    HStack(spacing: 10) {
                        Text("Source")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.60))

                        StatusBadge(StatusBadgeKind(sourceHealth: displayedHealth))

                        HStack(spacing: 3) {
                            Text("Updated")
                            Text(store.snapshot.generatedAt, style: .relative)
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.50))

                        Spacer()

                        Button {
                            Task {
                                await store.refresh()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                if store.isRefreshing {
                                    ProgressView()
                                        .controlSize(.mini)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                }

                                Text("Refresh")
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(StatusBadgeKind.working.tint)
                        }
                        .buttonStyle(.plain)
                        .disabled(store.isRefreshing)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
                .padding(.top, contentTop + (hasHardwareNotch ? 9 : 14))
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
                .background {
                    GeometryReader { contentGeometry in
                        Color.clear.preference(
                            key: SettingsContentHeightPreferenceKey.self,
                            value: contentGeometry.size.height
                        )
                    }
                }

            }
            .frame(
                width: geometry.size.width,
                height: geometry.size.height,
                alignment: .top
            )
            .onPreferenceChange(SettingsContentHeightPreferenceKey.self) { height in
                let preferredHeight = ceil(height)
                guard preferredHeight > 0,
                      abs(preferredHeight - lastReportedBodyHeight) >= 1 else {
                    return
                }

                lastReportedBodyHeight = preferredHeight
                onPreferredBodyHeight(preferredHeight)
            }
        }
        .foregroundStyle(Color.white.opacity(0.96))
        .background(Color.clear)
        .preferredColorScheme(.dark)
        .onAppear {
            store.startPolling()
        }
    }
}

private struct SettingToggleRow: View {
    let title: String
    let detail: String
    let systemImage: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(StatusBadgeKind.working.tint)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))

                Text(detail)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
    }
}

private struct SettingsContentHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

#Preview("Hardware notch · settings") {
    SettingsView(
        store: DashboardStore.demo(),
        neckWidth: 185,
        hasHardwareNotch: true
    )
    .frame(width: 720, height: 420)
    .background(Color.gray.opacity(0.4))
}
