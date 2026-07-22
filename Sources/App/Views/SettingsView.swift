import SwiftUI
import CodexNotchCore

struct SettingsView: View {
    @Bindable var store: DashboardStore
    let neckWidth: CGFloat
    let hasHardwareNotch: Bool
    let notificationPermissionDenied: Bool
    let onNotificationsChange: (Bool) -> Void
    let onPreviewCompletion: () -> Void
    let onPreferredBodyHeight: (CGFloat) -> Void
    let onDismiss: () -> Void

    @State private var lastReportedBodyHeight: CGFloat = 0

    init(
        store: DashboardStore,
        neckWidth: CGFloat = 185,
        hasHardwareNotch: Bool = true,
        notificationPermissionDenied: Bool = false,
        onNotificationsChange: @escaping (Bool) -> Void = { _ in },
        onPreviewCompletion: @escaping () -> Void = {},
        onPreferredBodyHeight: @escaping (CGFloat) -> Void = { _ in },
        onDismiss: @escaping () -> Void = {}
    ) {
        self.store = store
        self.neckWidth = neckWidth
        self.hasHardwareNotch = hasHardwareNotch
        self.notificationPermissionDenied = notificationPermissionDenied
        self.onNotificationsChange = onNotificationsChange
        self.onPreviewCompletion = onPreviewCompletion
        self.onPreferredBodyHeight = onPreferredBodyHeight
        self.onDismiss = onDismiss
    }

    private let flareHeight: CGFloat = 18
    private let minimumBodyHeight: CGFloat = 460

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

                VStack(alignment: .leading, spacing: 14) {
                    settingsHeader

                    HStack(alignment: .top, spacing: 12) {
                        alertsAndPrivacySection
                        completionFeedbackSection
                    }

                    sourceFooter
                }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)
                    .padding(.top, contentTop + (hasHardwareNotch ? 9 : 14))
                    .frame(maxWidth: 684)
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
                let preferredHeight = max(minimumBodyHeight, ceil(height))
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

    private var settingsHeader: some View {
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
    }

    private var alertsAndPrivacySection: some View {
        SettingsSection(title: "Alerts & privacy") {
            VStack(spacing: 0) {
                SettingToggleRow(
                    title: "Notifications",
                    detail: "Task finishes or needs you.",
                    systemImage: "bell.fill",
                    isOn: notificationsBinding
                )

                if notificationPermissionDenied {
                    Text("Notifications are blocked in System Settings.")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(StatusBadgeKind.needsAttention.tint)
                        .padding(.horizontal, 11)
                        .padding(.bottom, 8)
                }

                settingsDivider

                SettingToggleRow(
                    title: "Quiet mode",
                    detail: "Suppress standard notifications.",
                    systemImage: "moon.fill",
                    isOn: $store.quietMode
                )

                settingsDivider

                SettingToggleRow(
                    title: "Urgent alerts in Quiet Mode",
                    detail: "Allow approval and answer alerts.",
                    systemImage: "exclamationmark.bubble.fill",
                    isOn: $store.urgentAlertsInQuietMode
                )

                settingsDivider

                SettingToggleRow(
                    title: "Privacy mode",
                    detail: "Hide task and project details.",
                    systemImage: "eye.slash.fill",
                    isOn: $store.privacyMode
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var completionFeedbackSection: some View {
        SettingsSection(title: "Completion feedback") {
            VStack(spacing: 0) {
                CompactPickerRow(
                    title: "Completion effect",
                    systemImage: "sparkles"
                ) {
                    Picker("Completion effect", selection: $store.completionEffect) {
                        Text("Full screen").tag(CompletionEffect.fullScreen)
                        Text("Notch").tag(CompletionEffect.notchOnly)
                        Text("Off").tag(CompletionEffect.off)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }

                settingsDivider

                CompactPickerRow(
                    title: "While Codex is active",
                    systemImage: "macwindow.on.rectangle"
                ) {
                    Picker(
                        "While Codex is active",
                        selection: $store.codexActiveCompletionBehavior
                    ) {
                        Text("Keep").tag(CodexActiveCompletionBehavior.keepSelectedEffect)
                        Text("Notch").tag(CodexActiveCompletionBehavior.notchOnly)
                        Text("Hide").tag(CodexActiveCompletionBehavior.hide)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .disabled(store.completionEffect == .off)
                }

                settingsDivider

                HStack(spacing: 10) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(StatusBadgeKind.working.tint)
                        .frame(width: 18)

                    Text("Preview animation")
                        .font(.system(size: 11, weight: .medium))

                    Spacer()

                    Button("Preview", action: onPreviewCompletion)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(store.completionEffect == .off)
                        .accessibilityIdentifier("settings.previewAnimation")
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 10)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var sourceFooter: some View {
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
                Task { await store.refresh() }
            } label: {
                HStack(spacing: 6) {
                    if store.isRefreshing {
                        ProgressView().controlSize(.mini)
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

    private var settingsDivider: some View {
        Divider().overlay(Color.white.opacity(0.08))
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.60))

            content
                .background(Color.white.opacity(0.035))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.075), lineWidth: 0.75)
                        .allowsHitTesting(false)
                }
        }
    }
}

private struct CompactPickerRow<Control: View>: View {
    let title: String
    let systemImage: String
    let control: Control

    init(
        title: String,
        systemImage: String,
        @ViewBuilder control: () -> Control
    ) {
        self.title = title
        self.systemImage = systemImage
        self.control = control()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.90))

            control
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
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
    .frame(width: 720, height: 520)
    .background(Color.gray.opacity(0.4))
}
