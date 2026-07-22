import SwiftUI
import CodexNotchCore

struct CompactStatusView: View {
    let store: DashboardStore
    let presence: CompactPanelPresence
    let completionCelebration: CompletionCelebrationEvent?
    let celebrationPreviewElapsed: TimeInterval?
    let neckWidth: CGFloat
    let hasHardwareNotch: Bool
    let onExpand: () -> Void

    @State private var isHovering = false

    init(
        store: DashboardStore,
        presence: CompactPanelPresence,
        completionCelebration: CompletionCelebrationEvent? = nil,
        celebrationPreviewElapsed: TimeInterval? = nil,
        neckWidth: CGFloat = 185,
        hasHardwareNotch: Bool = true,
        onExpand: @escaping () -> Void
    ) {
        self.store = store
        self.presence = presence
        self.completionCelebration = completionCelebration
        self.celebrationPreviewElapsed = celebrationPreviewElapsed
        self.neckWidth = neckWidth
        self.hasHardwareNotch = hasHardwareNotch
        self.onExpand = onExpand
    }

    private var summary: CompactSummary {
        switch presence {
        case .unavailable:
            return CompactSummary(
                text: "Offline",
                tint: StatusBadgeKind.unavailable.tint
            )
        case .needsAttention(let count):
            return CompactSummary(
                text: countLabel(count, singular: "needs you", plural: "need you"),
                tint: StatusBadgeKind.needsAttention.tint
            )
        case .working(let count):
            return CompactSummary(
                text: countLabel(count, singular: "working", plural: "working"),
                tint: StatusBadgeKind.working.tint
            )
        case .recentlyInterrupted(let count):
            return CompactSummary(
                text: countLabel(count, singular: "stopped", plural: "stopped"),
                tint: StatusBadgeKind.interrupted.tint
            )
        case .recentlyFinished(let count):
            return CompactSummary(
                text: countLabel(count, singular: "finished", plural: "finished"),
                tint: StatusBadgeKind.completed.tint
            )
        case .dormant:
            return CompactSummary(
                text: "Codex",
                tint: StatusBadgeKind.idle.tint
            )
        }
    }

    private var accessibilitySummary: String {
        if let completionCelebration {
            var parts = [
                completionCelebration.completedCount == 1
                    ? "Task finished"
                    : "\(completionCelebration.completedCount) tasks finished"
            ]
            parts.append(completionCelebration.projectSummary)
            if completionCelebration.remainingActiveCount > 0 {
                parts.append(
                    completionCelebration.remainingActiveCount == 1
                        ? "1 task still active"
                        : "\(completionCelebration.remainingActiveCount) tasks still active"
                )
            }
            parts.append("Open the Codex dashboard")
            return parts.joined(separator: ", ")
        }

        var parts = ["Codex", summary.text]

        if store.unverifiedTaskCount > 0 {
            parts.append("\(store.unverifiedTaskCount) recent tasks have unverified status")
        }

        if store.staleTaskCount > 0 {
            parts.append("\(store.staleTaskCount) quiet tasks")
        }

        if store.quietMode {
            parts.append("quiet mode on")
        }

        return parts.joined(separator: ", ")
    }

    private var shell: NotchDropShape {
        NotchDropShape(
            neckWidth: neckWidth,
            flareHeight: 0,
            outerTopCornerRadius: 0,
            bottomCornerRadius: 9,
            hasHardwareNotch: hasHardwareNotch
        )
    }

    var body: some View {
        ZStack {
            if presence.isVisible {
                shell.fill(Color.black)

                Button(action: onExpand) {
                    HStack(spacing: 5.5) {
                        Circle()
                            .fill(summary.tint)
                            .frame(width: 4.5, height: 4.5)

                        Text(summary.text)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(
                                Color.white.opacity(isHovering ? 0.94 : 0.84)
                            )
                            .monospacedDigit()
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 9)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilitySummary)
                .accessibilityHint("Shows the Codex dashboard")
                .onHover { hovering in
                    isHovering = hovering
                }

                if let completionCelebration {
                    CompletionCelebrationLayer(
                        event: completionCelebration,
                        previewElapsed: celebrationPreviewElapsed
                    )
                        .id(completionCelebration.id)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
        }
        .clipShape(shell)
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .help("Show Codex activity")
        .preferredColorScheme(.dark)
        .onAppear {
            store.startPolling()
        }
    }

    private func countLabel(
        _ count: Int,
        singular: String,
        plural: String
    ) -> String {
        "\(count) \(count == 1 ? singular : plural)"
    }
}

private struct CompletionCelebrationLayer: View {
    let event: CompletionCelebrationEvent
    let previewElapsed: TimeInterval?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt = Date.now

    private let completedTint = StatusBadgeKind.completed.tint
    private let confetti = [
        CompletionConfettiPiece(id: 0, drift: -17, lift: 4.7, drop: 3.8, delay: 0.00, rotation: -210, width: 1.2, height: 3.0, color: .green),
        CompletionConfettiPiece(id: 1, drift: -13, lift: 3.6, drop: 4.4, delay: 0.04, rotation: 240, width: 1.4, height: 2.5, color: .white),
        CompletionConfettiPiece(id: 2, drift: -9, lift: 5.1, drop: 3.2, delay: 0.01, rotation: -180, width: 1.2, height: 3.4, color: .blue),
        CompletionConfettiPiece(id: 3, drift: -5, lift: 3.8, drop: 4.0, delay: 0.08, rotation: 300, width: 1.4, height: 2.4, color: .green),
        CompletionConfettiPiece(id: 4, drift: -2, lift: 4.8, drop: 3.6, delay: 0.12, rotation: -260, width: 1.1, height: 2.7, color: .white),
        CompletionConfettiPiece(id: 5, drift: 3, lift: 4.3, drop: 4.0, delay: 0.03, rotation: 230, width: 1.3, height: 3.1, color: .green),
        CompletionConfettiPiece(id: 6, drift: 6, lift: 5.0, drop: 3.2, delay: 0.10, rotation: -310, width: 1.2, height: 2.6, color: .blue),
        CompletionConfettiPiece(id: 7, drift: 10, lift: 3.8, drop: 4.4, delay: 0.05, rotation: 280, width: 1.4, height: 3.2, color: .green),
        CompletionConfettiPiece(id: 8, drift: 14, lift: 4.6, drop: 3.8, delay: 0.07, rotation: -240, width: 1.1, height: 2.8, color: .white),
        CompletionConfettiPiece(id: 9, drift: 18, lift: 3.3, drop: 4.5, delay: 0.13, rotation: 320, width: 1.3, height: 2.5, color: .green)
    ]

    var body: some View {
        Group {
            if let previewElapsed {
                animatedCelebrationFrame(at: previewElapsed)
            } else if reduceMotion {
                celebrationFrame(
                    overlayOpacity: 1,
                    checkScale: 1,
                    glowOpacity: 0,
                    confettiProgress: 1,
                    showConfetti: false
                )
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
                    let elapsed = max(0, context.date.timeIntervalSince(startedAt))
                    animatedCelebrationFrame(at: elapsed)
                }
            }
        }
        .onAppear {
            startedAt = .now
        }
    }

    private func animatedCelebrationFrame(at elapsed: TimeInterval) -> some View {
        let fadeIn = ramp(elapsed, from: 0, to: 0.10)
        let fadeOut = 1 - ramp(elapsed, from: 1.47, to: 1.67)
        let overlayOpacity = fadeIn * fadeOut
        let checkProgress = ramp(elapsed, from: 0.067, to: 0.333)
        let confettiProgress = ramp(elapsed, from: 0.08, to: 0.72)
        let glowOpacity = 0.12
            * ramp(elapsed, from: 0.067, to: 0.22)
            * (1 - ramp(elapsed, from: 0.47, to: 0.90))

        return celebrationFrame(
            overlayOpacity: overlayOpacity,
            checkScale: springScale(checkProgress),
            glowOpacity: glowOpacity,
            confettiProgress: confettiProgress,
            showConfetti: elapsed >= 0.08 && elapsed <= 0.78
        )
    }

    private func celebrationFrame(
        overlayOpacity: Double,
        checkScale: Double,
        glowOpacity: Double,
        confettiProgress: Double,
        showConfetti: Bool
    ) -> some View {
        ZStack {
            Color.black
                .opacity(overlayOpacity)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [completedTint, completedTint.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 17
                    )
                )
                .frame(width: 34, height: 34)
                .opacity(glowOpacity)
                .offset(x: -28)

            HStack(spacing: 5) {
                ZStack {
                    if showConfetti {
                        ForEach(confetti) { piece in
                            let localProgress = ramp(
                                confettiProgress,
                                from: piece.delay,
                                to: min(1, piece.delay + 0.82)
                            )
                            let distanceProgress = 1 - pow(1 - localProgress, 3)
                            let verticalOffset = -piece.lift * sin(localProgress * .pi)
                                + piece.drop * localProgress * localProgress
                            let particleOpacity = ramp(localProgress, from: 0, to: 0.08)
                                * (1 - ramp(localProgress, from: 0.72, to: 1))

                            RoundedRectangle(cornerRadius: 0.45, style: .continuous)
                                .fill(confettiColor(piece.color))
                                .frame(width: piece.width, height: piece.height)
                                .rotationEffect(.degrees(piece.rotation * localProgress))
                                .offset(
                                    x: CGFloat(piece.drift * distanceProgress),
                                    y: CGFloat(verticalOffset)
                                )
                                .opacity(particleOpacity * overlayOpacity)
                        }
                    }

                    ZStack {
                        Circle()
                            .fill(completedTint)

                        Image(systemName: "checkmark")
                            .font(.system(size: 5.6, weight: .black))
                            .foregroundStyle(Color.black.opacity(0.92))
                    }
                    .frame(width: 10, height: 10)
                    .scaleEffect(CGFloat(checkScale))
                }
                .frame(width: 10, height: 10)

                Text(event.completedCount == 1 ? "Finished" : "\(event.completedCount) finished")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .opacity(overlayOpacity)
        }
    }

    private func ramp(_ value: Double, from start: Double, to end: Double) -> Double {
        guard end > start else { return value >= end ? 1 : 0 }
        return min(1, max(0, (value - start) / (end - start)))
    }

    private func springScale(_ progress: Double) -> Double {
        guard progress < 1 else { return 1 }
        return 1 - (0.38 * exp(-7.4 * progress) * cos(13.2 * progress))
    }

    private func confettiColor(_ color: CompletionConfettiColor) -> Color {
        switch color {
        case .green:
            completedTint.opacity(0.94)
        case .white:
            Color.white.opacity(0.90)
        case .blue:
            StatusBadgeKind.working.tint.opacity(0.92)
        }
    }
}

private struct CompletionConfettiPiece: Identifiable {
    let id: Int
    let drift: Double
    let lift: Double
    let drop: Double
    let delay: Double
    let rotation: Double
    let width: CGFloat
    let height: CGFloat
    let color: CompletionConfettiColor
}

private enum CompletionConfettiColor {
    case green
    case white
    case blue
}

private struct CompactSummary {
    let text: String
    let tint: Color
}

#Preview("Hardware notch · resting") {
    CompactStatusView(
        store: DashboardStore.demo(),
        presence: .working(2),
        neckWidth: 185,
        hasHardwareNotch: true,
        onExpand: {}
    )
    .frame(width: 185, height: 18)
    .background(Color.gray.opacity(0.4))
}

#Preview("No notch · resting") {
    CompactStatusView(
        store: DashboardStore.demo(),
        presence: .needsAttention(1),
        neckWidth: 0,
        hasHardwareNotch: false,
        onExpand: {}
    )
    .frame(width: 220, height: 18)
    .background(Color.gray.opacity(0.4))
}

#Preview("Completion confetti") {
    CompactStatusView(
        store: DashboardStore.demo(),
        presence: .working(4),
        completionCelebration: CompletionCelebrationEvent(
            id: 1,
            completedCount: 1,
            remainingActiveCount: 4,
            projectSummary: "Codex Notch"
        ),
        neckWidth: 185,
        hasHardwareNotch: true,
        onExpand: {}
    )
    .frame(width: 185, height: 18)
    .background(Color.gray.opacity(0.4))
}
