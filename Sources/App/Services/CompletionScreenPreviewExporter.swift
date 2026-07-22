import AppKit
import SwiftUI

@MainActor
enum CompletionScreenPreviewExporter {
    struct Request {
        let destination: URL
        let reducesMotion: Bool
    }

    enum ExportError: Error {
        case missingBitmap
        case pngEncodingFailed
    }

    private static let size = CGSize(width: 1_512, height: 982)

    static func request(from arguments: [String]) -> Request? {
        let definitions = [
            ("--export-screen-celebration-preview", false),
            ("--export-screen-celebration-reduced-motion-preview", true)
        ]

        for (flag, reducesMotion) in definitions {
            guard let flagIndex = arguments.firstIndex(of: flag),
                  arguments.indices.contains(flagIndex + 1) else {
                continue
            }

            return Request(
                destination: URL(fileURLWithPath: arguments[flagIndex + 1]),
                reducesMotion: reducesMotion
            )
        }

        return nil
    }

    static func export(request: Request) throws {
        let content = AnyView(
            ScreenPreviewBackdrop()
                .overlay {
                    FullScreenCompletionCelebrationView(
                        event: CompletionCelebrationEvent(
                            id: 42,
                            completedCount: 1,
                            remainingActiveCount: 4,
                            projectSummary: "Codex Notch"
                        ),
                        previewElapsed: request.reducesMotion ? 0.7 : 0.82,
                        forcesReducedMotion: request.reducesMotion
                    )
                }
                .frame(width: size.width, height: size.height)
                .preferredColorScheme(.dark)
        )

        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = NSRect(origin: .zero, size: size)
        hostingView.appearance = NSAppearance(named: .darkAqua)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.layoutSubtreeIfNeeded()

        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw ExportError.missingBitmap
        }
        bitmap.size = size
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)

        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            throw ExportError.pngEncodingFailed
        }

        try FileManager.default.createDirectory(
            at: request.destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try png.write(to: request.destination, options: .atomic)
    }
}

private struct ScreenPreviewBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.11, green: 0.13, blue: 0.17),
                    Color(red: 0.035, green: 0.045, blue: 0.065)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Circle().fill(Color.red.opacity(0.75)).frame(width: 10, height: 10)
                    Circle().fill(Color.yellow.opacity(0.75)).frame(width: 10, height: 10)
                    Circle().fill(Color.green.opacity(0.75)).frame(width: 10, height: 10)
                    Spacer()
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 320, height: 18)
                    Spacer()
                }
                .padding(.horizontal, 18)
                .frame(height: 42)
                .background(Color.black.opacity(0.28))

                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 17) {
                        ForEach(0..<8, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(index == 2 ? 0.18 : 0.08))
                                .frame(width: index == 2 ? 154 : 126, height: 11)
                        }
                        Spacer()
                    }
                    .padding(24)
                    .frame(width: 220)
                    .background(Color.black.opacity(0.18))

                    VStack(alignment: .leading, spacing: 18) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.14))
                            .frame(width: 420, height: 24)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.07))
                            .frame(maxWidth: .infinity)
                            .frame(height: 13)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.07))
                            .frame(width: 680, height: 13)
                        Spacer()
                    }
                    .padding(42)
                }
            }

            VStack {
                RoundedRectangle(cornerRadius: 0)
                    .fill(Color.black)
                    .frame(width: 185, height: 32)
                Spacer()
            }
        }
    }
}
