import AppKit
import SwiftUI

@MainActor
enum DashboardPreviewExporter {
    enum Presentation {
        case compact
        case expanded

        var flag: String {
            switch self {
            case .compact: "--export-compact-preview"
            case .expanded: "--export-preview"
            }
        }

        var size: CGSize {
            switch self {
            case .compact: CGSize(width: 185, height: 50)
            case .expanded: CGSize(width: 720, height: 552)
            }
        }
    }

    struct Request {
        let destination: URL
        let presentation: Presentation
        let includesBackdrop: Bool
        let celebrationPreviewElapsed: TimeInterval?
    }

    enum ExportError: Error {
        case missingBitmap
        case pngEncodingFailed
    }

    static func request(from arguments: [String]) -> Request? {
        let definitions: [(String, Presentation, Bool, TimeInterval?)] = [
            ("--export-celebration-preview-board", .compact, true, 0.24),
            ("--export-compact-preview-board", .compact, true, nil),
            ("--export-preview-board", .expanded, true, nil),
            (Presentation.compact.flag, .compact, false, nil),
            (Presentation.expanded.flag, .expanded, false, nil)
        ]

        for (flag, presentation, includesBackdrop, celebrationPreviewElapsed) in definitions {
            guard let flagIndex = arguments.firstIndex(of: flag),
                  arguments.indices.contains(flagIndex + 1) else {
                continue
            }

            return Request(
                destination: URL(fileURLWithPath: arguments[flagIndex + 1]),
                presentation: presentation,
                includesBackdrop: includesBackdrop,
                celebrationPreviewElapsed: celebrationPreviewElapsed
            )
        }

        return nil
    }

    static func export(
        store: DashboardStore,
        presentation: Presentation,
        includesBackdrop: Bool = false,
        celebrationPreviewElapsed: TimeInterval? = nil,
        to destination: URL
    ) throws {
        let size = includesBackdrop
            ? previewBoardSize(for: presentation)
            : presentation.size
        let content = AnyView(Group {
            if includesBackdrop {
                NotchPreviewBoard(
                    store: store,
                    presentation: presentation,
                    celebrationPreviewElapsed: celebrationPreviewElapsed
                )
            } else {
                NotchPreviewSurface(
                    store: store,
                    presentation: presentation,
                    celebrationPreviewElapsed: celebrationPreviewElapsed
                )
            }
        }
            .frame(width: size.width, height: size.height)
            .preferredColorScheme(.dark))

        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = NSRect(origin: .zero, size: size)
        hostingView.appearance = NSAppearance(named: .darkAqua)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.layoutSubtreeIfNeeded()

        guard let bitmap = hostingView.bitmapImageRepForCachingDisplay(
            in: hostingView.bounds
        ) else {
            throw ExportError.missingBitmap
        }
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)

        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            throw ExportError.pngEncodingFailed
        }

        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try png.write(to: destination, options: .atomic)
    }

    private static func previewBoardSize(for presentation: Presentation) -> CGSize {
        switch presentation {
        case .compact: CGSize(width: 420, height: 90)
        case .expanded: CGSize(width: 820, height: 600)
        }
    }
}

private struct NotchPreviewBoard: View {
    let store: DashboardStore
    let presentation: DashboardPreviewExporter.Presentation
    let celebrationPreviewElapsed: TimeInterval?

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [
                    Color(red: 0.29, green: 0.31, blue: 0.35),
                    Color(red: 0.17, green: 0.19, blue: 0.23)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 32)

            NotchPreviewSurface(
                store: store,
                presentation: presentation,
                celebrationPreviewElapsed: celebrationPreviewElapsed
            )
            .frame(
                width: presentation.size.width,
                height: presentation.size.height
            )
        }
    }
}

private struct NotchPreviewSurface: View {
    let store: DashboardStore
    let presentation: DashboardPreviewExporter.Presentation
    let celebrationPreviewElapsed: TimeInterval?

    private let neckWidth: CGFloat = 185
    private let reservedTopHeight: CGFloat = 32

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear

            Rectangle()
                .fill(Color.black)
                .frame(width: neckWidth, height: reservedTopHeight)

            bodySurface
                .offset(y: reservedTopHeight)
        }
    }

    @ViewBuilder
    private var bodySurface: some View {
        switch presentation {
        case .compact:
            CompactStatusView(
                store: store,
                presence: celebrationPreviewElapsed == nil
                    ? .needsAttention(1)
                    : .working(4),
                completionCelebration: celebrationPreviewElapsed.map { _ in
                    CompletionCelebrationEvent(
                        id: 1,
                        completedCount: 1,
                        remainingActiveCount: 4,
                        projectSummary: "Codex Notch"
                    )
                },
                celebrationPreviewElapsed: celebrationPreviewElapsed,
                neckWidth: neckWidth,
                hasHardwareNotch: true,
                onExpand: {}
            )
            .frame(width: 185, height: 18)

        case .expanded:
            DashboardView(
                store: store,
                neckWidth: neckWidth,
                hasHardwareNotch: true
            )
            .frame(width: 720, height: 520)
        }
    }
}
