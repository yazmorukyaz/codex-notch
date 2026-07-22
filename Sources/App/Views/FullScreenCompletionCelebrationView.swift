import SwiftUI

struct FullScreenCompletionCelebrationView: View {
    let event: CompletionCelebrationEvent
    let previewElapsed: TimeInterval?
    let forcesReducedMotion: Bool?

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var startedAt = Date.now

    private let particles: [ScreenConfettiParticle]

    init(
        event: CompletionCelebrationEvent,
        previewElapsed: TimeInterval? = nil,
        forcesReducedMotion: Bool? = nil
    ) {
        self.event = event
        self.previewElapsed = previewElapsed
        self.forcesReducedMotion = forcesReducedMotion
        self.particles = Self.makeParticles(
            eventID: event.id,
            count: event.remainingActiveCount == 0 ? 180 : 144
        )
    }

    var body: some View {
        Group {
            if let previewElapsed {
                celebrationFrame(at: previewElapsed)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
                    celebrationFrame(
                        at: max(0, context.date.timeIntervalSince(startedAt))
                    )
                }
            }
        }
        .background(Color.clear)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            startedAt = .now
        }
    }

    private func celebrationFrame(at elapsed: TimeInterval) -> some View {
        GeometryReader { proxy in
            let reduceMotion = forcesReducedMotion ?? accessibilityReduceMotion
            let badgeOpacity = reduceMotion
                ? 1.0
                : ramp(elapsed, from: 0.04, to: 0.20)
                    * (1 - ramp(elapsed, from: 1.72, to: 2.22))
            let badgeScale = reduceMotion
                ? 1.0
                : 0.92 + (0.08 * springProgress(elapsed))
            let flashOpacity = reduceMotion
                ? 0.0
                : 0.055
                    * ramp(elapsed, from: 0, to: 0.06)
                    * (1 - ramp(elapsed, from: 0.16, to: 0.48))

            ZStack {
                Color(red: 0.31, green: 0.87, blue: 0.55)
                    .opacity(flashOpacity)

                if !reduceMotion {
                    particleField(
                        size: proxy.size,
                        elapsed: elapsed
                    )
                }

                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        Color(red: 0.31, green: 0.78, blue: 0.49)
                            .opacity(0.32 * badgeOpacity),
                        lineWidth: 3
                    )
                    .padding(10)

                completionBadge
                    .opacity(badgeOpacity)
                    .scaleEffect(badgeScale)
                    .position(
                        x: proxy.size.width / 2,
                        y: proxy.size.height * 0.42
                    )
            }
        }
    }

    private var completionBadge: some View {
        HStack(spacing: 13) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.31, green: 0.78, blue: 0.49))
                    .frame(width: 38, height: 38)

                Image(systemName: "checkmark")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Color.black.opacity(0.88))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white)

                Text(event.projectSummary)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.55, green: 0.90, blue: 0.67))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(activitySummary)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.62))
            }
            .frame(width: 270, alignment: .leading)
        }
        .padding(.horizontal, 18)
        .frame(height: 82)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.88))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                }
        )
        .shadow(color: Color.black.opacity(0.36), radius: 28, y: 12)
    }

    private var title: String {
        if event.remainingActiveCount == 0 {
            return "All done"
        }
        if event.completedCount == 1 {
            return "Task finished"
        }
        return "\(event.completedCount) tasks finished"
    }

    private var activitySummary: String {
        if event.remainingActiveCount == 0 {
            return "Everything is complete"
        }
        return event.remainingActiveCount == 1
            ? "1 task still working"
            : "\(event.remainingActiveCount) tasks still working"
    }

    private func particleField(
        size: CGSize,
        elapsed: TimeInterval
    ) -> some View {
        ZStack {
            ForEach(particles.indices, id: \.self) { index in
                let particle = particles[index]
                let state = particleState(
                    particle,
                    size: size,
                    elapsed: elapsed
                )

                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(color(at: particle.colorIndex))
                    .frame(width: particle.width, height: particle.height)
                    .rotationEffect(.radians(state.rotation))
                    .position(x: state.x, y: state.y)
                    .opacity(state.opacity)
            }
        }
    }

    private func particleState(
        _ particle: ScreenConfettiParticle,
        size: CGSize,
        elapsed: TimeInterval
    ) -> ScreenConfettiParticleState {
        let time = max(0, elapsed - particle.delay)
        let xVelocity = particle.fan
            * size.width
            * particle.horizontalVelocity
        let horizontalTravel = time > 0
            ? xVelocity * (1 - exp(-particle.drag * time)) / particle.drag
            : 0
        let wobble = particle.wobble
            * sin(particle.phase + (particle.frequency * time))
        let x = (size.width / 2) + horizontalTravel + wobble

        let verticalVelocity = size.height * particle.verticalVelocity
        let gravity = size.height * particle.gravity
        let y = 28
            + (verticalVelocity * time)
            + (0.5 * gravity * time * time)
        let opacity = time > 0 && y < size.height + 80
            ? ramp(time, from: 0, to: 0.05)
                * (1 - ramp(time, from: 1.40, to: 2.16))
            : 0

        return ScreenConfettiParticleState(
            x: x,
            y: y,
            rotation: particle.initialRotation + (particle.spin * time),
            opacity: opacity
        )
    }

    private func color(at index: Int) -> Color {
        let palette = [
            Color(red: 0.31, green: 0.78, blue: 0.49),
            Color(red: 0.38, green: 0.66, blue: 1.00),
            Color(red: 0.98, green: 0.99, blue: 1.00),
            Color(red: 1.00, green: 0.79, blue: 0.34),
            Color(red: 0.82, green: 0.45, blue: 0.98),
            Color(red: 1.00, green: 0.43, blue: 0.55)
        ]
        return palette[index % palette.count]
    }

    private func ramp(
        _ value: TimeInterval,
        from lowerBound: TimeInterval,
        to upperBound: TimeInterval
    ) -> Double {
        guard upperBound > lowerBound else { return value >= upperBound ? 1 : 0 }
        return min(1, max(0, (value - lowerBound) / (upperBound - lowerBound)))
    }

    private func springProgress(_ elapsed: TimeInterval) -> Double {
        let progress = ramp(elapsed, from: 0.04, to: 0.38)
        return 1 - (pow(2, -9 * progress) * cos(progress * .pi * 4.5))
    }

    private static func makeParticles(
        eventID: Int,
        count: Int
    ) -> [ScreenConfettiParticle] {
        (0..<count).map { index in
            let fanJitter = (unit(eventID: eventID, index: index, salt: 0) - 0.5)
                * (1.2 / Double(count))
            let fan = min(
                1,
                max(-1, ((Double(index) + 0.5) / Double(count) * 2) - 1 + fanJitter)
            )
            let spinDirection = unit(eventID: eventID, index: index, salt: 9) > 0.5
                ? 1.0
                : -1.0

            return ScreenConfettiParticle(
                fan: fan,
                delay: unit(eventID: eventID, index: index, salt: 1) * 0.18,
                horizontalVelocity: 0.52
                    + (unit(eventID: eventID, index: index, salt: 2) * 0.18),
                verticalVelocity: 0.08
                    + (0.22 * (1 - abs(fan)))
                    + (unit(eventID: eventID, index: index, salt: 3) * 0.08),
                drag: 0.48
                    + (unit(eventID: eventID, index: index, salt: 4) * 0.20),
                gravity: 0.32
                    + (unit(eventID: eventID, index: index, salt: 5) * 0.10),
                wobble: 10
                    + (unit(eventID: eventID, index: index, salt: 6) * 28),
                phase: unit(eventID: eventID, index: index, salt: 7) * .pi * 2,
                frequency: 5
                    + (unit(eventID: eventID, index: index, salt: 8) * 5),
                initialRotation: unit(eventID: eventID, index: index, salt: 10)
                    * .pi
                    * 2,
                spin: spinDirection
                    * (4 + (unit(eventID: eventID, index: index, salt: 11) * 7)),
                width: 4
                    + (unit(eventID: eventID, index: index, salt: 12) * 3),
                height: 8
                    + (unit(eventID: eventID, index: index, salt: 13) * 7),
                colorIndex: Int(unit(eventID: eventID, index: index, salt: 14) * 6)
            )
        }
    }

    private static func unit(eventID: Int, index: Int, salt: Int) -> Double {
        var value = UInt32(truncatingIfNeeded: eventID)
            &+ (UInt32(truncatingIfNeeded: index + 1) &* 0x9E37_79B9)
            &+ (UInt32(truncatingIfNeeded: salt + 1) &* 0x85EB_CA6B)
        value ^= value >> 16
        value &*= 0x7FEB_352D
        value ^= value >> 15
        value &*= 0x846C_A68B
        value ^= value >> 16
        return Double(value) / Double(UInt32.max)
    }
}

private struct ScreenConfettiParticle {
    let fan: Double
    let delay: Double
    let horizontalVelocity: Double
    let verticalVelocity: Double
    let drag: Double
    let gravity: Double
    let wobble: Double
    let phase: Double
    let frequency: Double
    let initialRotation: Double
    let spin: Double
    let width: Double
    let height: Double
    let colorIndex: Int
}

private struct ScreenConfettiParticleState {
    let x: Double
    let y: Double
    let rotation: Double
    let opacity: Double
}
