import SwiftUI
import CodexNotchCore

struct DashboardView: View {
    let store: DashboardStore
    let neckWidth: CGFloat
    let hasHardwareNotch: Bool
    let onPreferredBodyHeight: (CGFloat) -> Void
    let onCollapse: () -> Void
    let onOpenSettings: () -> Void

    @State private var lastReportedBodyHeight: CGFloat = 0

    init(
        store: DashboardStore,
        neckWidth: CGFloat = 185,
        hasHardwareNotch: Bool = true,
        onPreferredBodyHeight: @escaping (CGFloat) -> Void = { _ in },
        onCollapse: @escaping () -> Void = {},
        onOpenSettings: @escaping () -> Void = {}
    ) {
        self.store = store
        self.neckWidth = neckWidth
        self.hasHardwareNotch = hasHardwareNotch
        self.onPreferredBodyHeight = onPreferredBodyHeight
        self.onCollapse = onCollapse
        self.onOpenSettings = onOpenSettings
    }

    private let flareHeight: CGFloat = 18
    private let headerHeight: CGFloat = 50

    private var hasVisibleTasks: Bool {
        !store.needsAttentionTasks.isEmpty ||
            !store.workingTasks.isEmpty ||
            !store.recentlyFinishedTasks.isEmpty ||
            !store.unverifiedTasks.isEmpty ||
            !store.otherTasks.isEmpty
    }

    private var displayedHealth: CodexSourceHealth {
        if store.lastRefreshFailedAt != nil {
            return .unavailable("The latest refresh failed")
        }
        return store.snapshot.health
    }

    var body: some View {
        GeometryReader { geometry in
            let contentTop = NotchDropShape.bodyTop(
                in: geometry.size.height,
                flareHeight: flareHeight,
                hasHardwareNotch: hasHardwareNotch
            )
            let topPadding = contentTop + (hasHardwareNotch ? 3 : 8)
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

                VStack(spacing: 0) {
                    header

                    Divider()
                        .overlay(Color.white.opacity(0.10))

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 11) {
                            sourceStatus

                            if let usageLimits = store.snapshot.usageLimits {
                                UsageLimitsView(limits: usageLimits)
                            }

                            if hasVisibleTasks {
                                taskSection(
                                    title: "Needs you",
                                    tasks: store.needsAttentionTasks,
                                    tint: StatusBadgeKind.needsAttention.tint
                                )

                                taskSection(
                                    title: "Working",
                                    tasks: store.workingTasks,
                                    tint: StatusBadgeKind.working.tint
                                )

                                taskSection(
                                    title: "Recently finished",
                                    tasks: store.recentlyFinishedTasks,
                                    tint: StatusBadgeKind.completed.tint
                                )

                                taskSection(
                                    title: "Recent activity · status unverified",
                                    tasks: store.unverifiedTasks,
                                    tint: StatusBadgeKind.unverified.tint
                                )

                                taskSection(
                                    title: "Quiet",
                                    tasks: store.otherTasks,
                                    tint: StatusBadgeKind.stale.tint
                                )
                            } else {
                                emptyState
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background {
                            GeometryReader { contentGeometry in
                                Color.clear.preference(
                                    key: DashboardContentHeightPreferenceKey.self,
                                    value: contentGeometry.size.height
                                )
                            }
                        }
                    }
                    .scrollIndicators(.automatic)
                }
                .padding(.top, topPadding)
                .clipShape(shell)

            }
            .onPreferenceChange(DashboardContentHeightPreferenceKey.self) { contentHeight in
                let preferredHeight = ceil(
                    topPadding + headerHeight + 1 + contentHeight
                )
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

    private var header: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(headerTint)
                .frame(width: 8, height: 8)
                .shadow(color: headerTint.opacity(0.55), radius: 5)

            VStack(alignment: .leading, spacing: 1) {
                Text("Codex")
                    .font(.system(size: 15, weight: .semibold))

                Text(activeSummary)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.58))
                    .monospacedDigit()
            }

            Spacer()

            if store.privacyMode {
                StatusBadge(.privacy)
            }

            if store.quietMode {
                StatusBadge(.quiet)
            }

            DashboardHeaderButton(
                systemImage: "arrow.clockwise",
                help: "Refresh now",
                isBusy: store.isRefreshing
            ) {
                Task {
                    await store.refresh()
                }
            }
            .disabled(store.isRefreshing)

            DashboardHeaderButton(
                systemImage: "gearshape.fill",
                help: "Open settings",
                action: onOpenSettings
            )

            DashboardHeaderButton(
                systemImage: "chevron.up",
                help: "Collapse dashboard",
                action: onCollapse
            )
        }
        .padding(.horizontal, 15)
        .frame(height: headerHeight)
    }

    private var sourceStatus: some View {
        HStack(spacing: 8) {
            StatusBadge(StatusBadgeKind(sourceHealth: displayedHealth))

            if store.lastRefreshFailedAt != nil {
                Text("Refresh failed · showing the last snapshot")
                    .foregroundStyle(StatusBadgeKind.unavailable.tint)
            } else {
                HStack(spacing: 3) {
                    Text("Updated")
                    Text(store.snapshot.generatedAt, style: .relative)
                }
                .foregroundStyle(Color.white.opacity(0.56))
            }

            Spacer()
        }
        .font(.system(size: 11, weight: .medium))
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func taskSection(
        title: String,
        tasks: [CodexTaskSnapshot],
        tint: Color
    ) -> some View {
        if !tasks.isEmpty {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 7) {
                    Capsule()
                        .fill(tint)
                        .frame(width: 15, height: 3)

                    Text(title.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.61))
                        .tracking(0.65)

                    Text("\(tasks.count)")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.43))
                        .monospacedDigit()
                }

                VStack(spacing: 0) {
                    ForEach(tasks) { task in
                        TaskRowView(
                            task: task,
                            privacyMode: store.privacyMode,
                            onOpen: {
                                store.openTask(task)
                            }
                        )

                        if task.id != tasks.last?.id {
                            Divider()
                                .overlay(Color.white.opacity(0.075))
                                .padding(.leading, 12)
                        }
                    }
                }
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

    private var emptyState: some View {
        HStack(spacing: 11) {
            Image(systemName: emptyStateImage)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.42))

            VStack(alignment: .leading, spacing: 2) {
                Text(emptyStateTitle)
                    .font(.system(size: 12, weight: .semibold))

                Text(emptyStateMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.58))
            }

            Spacer()

            if store.lastRefreshFailedAt != nil {
                Button("Try again") {
                    Task {
                        await store.refresh()
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(StatusBadgeKind.working.tint)
                .disabled(store.isRefreshing)
            }
        }
        .padding(13)
        .background(Color.white.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var headerTint: Color {
        if store.lastRefreshFailedAt != nil { return StatusBadgeKind.unavailable.tint }
        if store.needsAttentionCount > 0 { return StatusBadgeKind.needsAttention.tint }
        if store.activeTaskCount > 0 { return StatusBadgeKind.working.tint }
        if store.unverifiedTaskCount > 0 { return StatusBadgeKind.unverified.tint }
        if store.staleTaskCount > 0 { return StatusBadgeKind.stale.tint }
        return StatusBadgeKind.idle.tint
    }

    private var activeSummary: String {
        if store.needsAttentionCount > 0 {
            return "\(store.activeTaskCount) active · \(store.needsAttentionCount) need you"
        }
        if store.activeTaskCount > 0 {
            return store.activeTaskCount == 1 ? "1 task working" : "\(store.activeTaskCount) tasks working"
        }
        if store.unverifiedTaskCount > 0 {
            return store.unverifiedTaskCount == 1
                ? "1 recently active · status unverified"
                : "\(store.unverifiedTaskCount) recently active · status unverified"
        }
        if store.staleTaskCount == 1 {
            return "1 quiet task"
        }
        if store.staleTaskCount > 1 {
            return "\(store.staleTaskCount) quiet tasks"
        }
        return "No active tasks"
    }

    private var emptyStateImage: String {
        store.lastRefreshFailedAt == nil ? "checkmark.circle" : "wifi.slash"
    }

    private var emptyStateTitle: String {
        store.lastRefreshFailedAt == nil ? "No active tasks" : "Codex activity unavailable"
    }

    private var emptyStateMessage: String {
        if store.lastRefreshFailedAt != nil {
            return "The last refresh failed. Check Codex, then try again."
        }
        return "New work and requests for attention will appear here."
    }
}

private struct DashboardHeaderButton: View {
    let systemImage: String
    let help: String
    var isBusy = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isBusy {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Image(systemName: systemImage)
                        .font(.system(size: 10, weight: .semibold))
                }
            }
            .foregroundStyle(Color.white.opacity(0.72))
            .frame(width: 28, height: 28)
            .background(Color.white.opacity(0.055), in: Circle())
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }
}

private struct DashboardContentHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

#Preview("Hardware notch · dashboard") {
    DashboardView(
        store: DashboardStore.demo(),
        neckWidth: 185,
        hasHardwareNotch: true
    )
    .frame(width: 720, height: 520)
    .background(Color.gray.opacity(0.4))
}

#Preview("No notch · dashboard") {
    DashboardView(
        store: DashboardStore.demo(),
        neckWidth: 0,
        hasHardwareNotch: false
    )
    .frame(width: 720, height: 520)
    .background(Color.gray.opacity(0.4))
}
