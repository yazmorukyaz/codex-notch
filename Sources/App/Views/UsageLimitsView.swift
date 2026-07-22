import SwiftUI
import CodexNotchCore

struct UsageLimitsView: View {
    let limits: UsageLimitsSnapshot

    init(limits: UsageLimitsSnapshot) {
        self.limits = limits
    }

    private var windows: [UsageWindowSnapshot] {
        [limits.primary, limits.secondary].compactMap { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Label("Usage", systemImage: "bolt.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.68))

                if let planType = limits.planType, !planType.isEmpty {
                    Text(planType)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.43))
                }

                Spacer()

                HStack(spacing: 3) {
                    Text("Updated")
                    Text(limits.capturedAt, style: .relative)
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.46))
            }

            if windows.isEmpty {
                Text("Limit details are unavailable.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.58))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 18) {
                    ForEach(Array(windows.enumerated()), id: \.offset) { index, window in
                        UsageWindowCard(window: window)

                        if index < windows.count - 1 {
                            Divider()
                                .overlay(Color.white.opacity(0.08))
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.075), lineWidth: 0.75)
                .allowsHitTesting(false)
        }
    }
}

private struct UsageWindowCard: View {
    let window: UsageWindowSnapshot

    private var roundedPercent: Int {
        Int(window.usedPercent.rounded())
    }

    private var windowLabel: String {
        switch window.windowMinutes {
        case 7 * 24 * 60:
            return "Weekly"
        case let minutes where minutes.isMultiple(of: 24 * 60):
            let days = minutes / (24 * 60)
            return "\(days)-day"
        case let minutes where minutes.isMultiple(of: 60):
            let hours = minutes / 60
            return "\(hours)-hour"
        default:
            return "\(window.windowMinutes)-minute"
        }
    }

    private var progressTint: Color {
        switch window.usedPercent {
        case 85...:
            return StatusBadgeKind.needsAttention.tint
        case 65...:
            return Color(red: 0.45, green: 0.64, blue: 0.98)
        default:
            return StatusBadgeKind.working.tint
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(windowLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.66))

                Spacer(minLength: 8)

                Text("\(roundedPercent)% used")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.94))
                    .monospacedDigit()
            }

            ProgressView(value: window.usedPercent, total: 100)
                .progressViewStyle(.linear)
                .tint(progressTint)
                .controlSize(.small)

            if let resetsAt = window.resetsAt {
                HStack(spacing: 3) {
                    Text("Resets")
                    Text(resetsAt, style: .relative)
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.48))
            } else {
                Text("Reset time unavailable")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.48))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(windowLabel) limit")
        .accessibilityValue("\(roundedPercent) percent used")
    }
}
