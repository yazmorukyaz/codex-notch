import SwiftUI
import CodexNotchCore

struct CompactStatusView: View {
    let store: DashboardStore
    let presence: CompactPanelPresence
    let completionCelebration: CompletionCelebrationEvent?
    let celebrationPreviewElapsed: TimeInterval?
    let attentionPreviewElapsed: TimeInterval?
    let neckWidth: CGFloat
    let hasHardwareNotch: Bool
    let onExpand: () -> Void

    @State private var isHovering = false

    init(
        store: DashboardStore,
        presence: CompactPanelPresence,
        completionCelebration: CompletionCelebrationEvent? = nil,
        celebrationPreviewElapsed: TimeInterval? = nil,
        attentionPreviewElapsed: TimeInterval? = nil,
        neckWidth: CGFloat = 185,
        hasHardwareNotch: Bool = true,
        onExpand: @escaping () -> Void
    ) {
        self.store = store
        self.presence = presence
        self.completionCelebration = completionCelebration
        self.celebrationPreviewElapsed = celebrationPreviewElapsed
        self.attentionPreviewElapsed = attentionPreviewElapsed
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
            bottomCornerRadius: isAttention ? 13 : 9,
            hasHardwareNotch: hasHardwareNotch
        )
    }

    private var isAttention: Bool {
        if case .needsAttention = presence { return true }
        return false
    }

    var body: some View {
        ZStack {
            if presence.isVisible {
                shell.fill(Color.black)

                Button(action: onExpand) {
                    Group {
                        if case .needsAttention(let count) = presence {
                            ApprovalRobotAttentionView(
                                count: count,
                                tint: summary.tint,
                                isHovering: isHovering,
                                previewElapsed: attentionPreviewElapsed
                            )
                        } else {
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
                        }
                    }
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

private struct ApprovalRobotAttentionView: View {
    let count: Int
    let tint: Color
    let isHovering: Bool
    let previewElapsed: TimeInterval?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt = Date.now

    var body: some View {
        Group {
            if let previewElapsed {
                animatedFrame(at: previewElapsed)
            } else if reduceMotion {
                frame(
                    shake: 0,
                    robotLift: 0,
                    signScale: 1,
                    glowOpacity: 0.16
                )
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                    let elapsed = max(0, context.date.timeIntervalSince(startedAt))
                    animatedFrame(at: elapsed)
                }
            }
        }
        .onAppear {
            startedAt = .now
        }
    }

    private func animatedFrame(at elapsed: TimeInterval) -> some View {
        let cycle = elapsed.truncatingRemainder(dividingBy: 7.5)
        let entrance = min(1, elapsed / 0.38)
        let knockWindow = cycle < 1.15 ? 1 - (cycle / 1.15) : 0
        let shake = sin(cycle * 34) * 2.2 * knockWindow * entrance
        let lift = -abs(sin(cycle * 16)) * 2.4 * knockWindow
        let pulse = (sin(elapsed * 4.8) + 1) / 2

        return frame(
            shake: CGFloat(shake),
            robotLift: CGFloat(lift + ((1 - entrance) * -22)),
            signScale: CGFloat(0.96 + (pulse * 0.08)),
            glowOpacity: 0.10 + (pulse * 0.13)
        )
    }

    private func frame(
        shake: CGFloat,
        robotLift: CGFloat,
        signScale: CGFloat,
        glowOpacity: Double
    ) -> some View {
        ZStack {
            tint.opacity(glowOpacity)

            HStack(spacing: 7) {
                ApprovalRobotMascot(tint: tint)
                    .frame(width: 34, height: 36)
                    .offset(x: shake, y: robotLift)

                VStack(alignment: .leading, spacing: 1) {
                    Text("APPROVE?")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .tracking(0.35)
                        .scaleEffect(signScale, anchor: .leading)

                    Text(
                        count == 1
                            ? "1 task needs you"
                            : "\(count) tasks need you"
                    )
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(
                        Color.white.opacity(isHovering ? 0.92 : 0.72)
                    )
                    .monospacedDigit()
                    .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(tint.opacity(0.92))
            }
            .padding(.leading, 9)
            .padding(.trailing, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(tint.opacity(glowOpacity * 1.8), lineWidth: 1)
                .padding(1)
        }
    }
}

private struct ApprovalRobotMascot: View {
    let tint: Color

    var body: some View {
        ZStack {
            Capsule()
                .fill(tint.opacity(0.32))
                .frame(width: 25, height: 5)
                .offset(y: 14)

            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.95),
                            Color.white.opacity(0.68)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 27, height: 23)
                .overlay {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.black.opacity(0.88))
                        .frame(width: 21, height: 12)
                        .overlay {
                            HStack(spacing: 6) {
                                Circle().fill(tint)
                                Circle().fill(tint)
                            }
                            .frame(width: 12, height: 3.5)
                        }
                        .offset(y: -1)
                }
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(Color.white.opacity(0.82))
                        .frame(width: 2, height: 6)
                        .offset(y: -5)
                        .overlay(alignment: .top) {
                            Circle()
                                .fill(tint)
                                .frame(width: 4, height: 4)
                                .offset(y: -8)
                        }
                }

            Capsule()
                .fill(Color.white.opacity(0.8))
                .frame(width: 4, height: 13)
                .rotationEffect(.degrees(-38), anchor: .bottom)
                .offset(x: 15, y: 4)

            Circle()
                .fill(tint)
                .frame(width: 6, height: 6)
                .offset(x: 20, y: -3)
        }
        .shadow(color: tint.opacity(0.55), radius: 5)
        .accessibilityHidden(true)
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
