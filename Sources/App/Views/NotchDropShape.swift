import SwiftUI

/// The body half of a two-window notch shell. AppKit owns the mouse-transparent
/// camera-gap bridge; this path begins at that bridge's lower edge and flares
/// into the interactive surface while keeping its upper shoulders transparent.
struct NotchDropShape: Shape {
    let neckWidth: CGFloat
    let flareHeight: CGFloat
    let outerTopCornerRadius: CGFloat
    let bottomCornerRadius: CGFloat
    let hasHardwareNotch: Bool

    init(
        neckWidth: CGFloat,
        flareHeight: CGFloat = 12,
        outerTopCornerRadius: CGFloat = 14,
        bottomCornerRadius: CGFloat = 16,
        hasHardwareNotch: Bool
    ) {
        self.neckWidth = neckWidth
        self.flareHeight = flareHeight
        self.outerTopCornerRadius = outerTopCornerRadius
        self.bottomCornerRadius = bottomCornerRadius
        self.hasHardwareNotch = hasHardwareNotch
    }

    func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }

        // A zero-flare compact surface is a flush continuation of the physical
        // camera housing: square at the seam, rounded only at the bottom.
        if !hasHardwareNotch || flareHeight <= 0 {
            return conventionalTopPanelPath(in: rect)
        }

        let bodyTop = Self.bodyTop(
            in: rect.height,
            flareHeight: flareHeight,
            hasHardwareNotch: true
        ) + rect.minY
        let usableNeckWidth = min(
            max(1, neckWidth),
            max(1, rect.width - 24)
        )
        let neckLeft = rect.midX - (usableNeckWidth / 2)
        let neckRight = rect.midX + (usableNeckWidth / 2)
        let availableShoulder = max(0, (rect.width - usableNeckWidth) / 2)
        let flareWidth = min(max(18, flareHeight * 1.65), availableShoulder)
        let outerTopRadius = resolvedOuterTopRadius(
            in: rect,
            bodyTop: bodyTop,
            availableShoulder: availableShoulder
        )
        let flareLeft = max(rect.minX + outerTopRadius, neckLeft - flareWidth)
        let flareRight = min(rect.maxX - outerTopRadius, neckRight + flareWidth)
        let bottomRadius = resolvedBottomRadius(in: rect, bodyTop: bodyTop)

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: bodyTop + outerTopRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + outerTopRadius, y: bodyTop),
            control: CGPoint(x: rect.minX, y: bodyTop)
        )
        path.addLine(to: CGPoint(x: flareLeft, y: bodyTop))
        path.addCurve(
            to: CGPoint(x: neckLeft, y: rect.minY),
            control1: CGPoint(x: flareLeft + (flareWidth * 0.48), y: bodyTop),
            control2: CGPoint(x: neckLeft, y: rect.minY + (max(0, bodyTop - rect.minY) * 0.42))
        )
        path.addLine(to: CGPoint(x: neckRight, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: flareRight, y: bodyTop),
            control1: CGPoint(x: neckRight, y: rect.minY + (max(0, bodyTop - rect.minY) * 0.42)),
            control2: CGPoint(x: flareRight - (flareWidth * 0.48), y: bodyTop)
        )
        path.addLine(to: CGPoint(x: rect.maxX - outerTopRadius, y: bodyTop))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: bodyTop + outerTopRadius),
            control: CGPoint(x: rect.maxX, y: bodyTop)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - bottomRadius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + bottomRadius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - bottomRadius),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: bodyTop + outerTopRadius))
        path.closeSubpath()
        return path
    }

    /// The first y-coordinate where full-width content may begin.
    static func bodyTop(
        in totalHeight: CGFloat,
        flareHeight: CGFloat,
        hasHardwareNotch: Bool
    ) -> CGFloat {
        let safeHeight = max(0, totalHeight)
        guard hasHardwareNotch else { return 0 }

        return min(
            safeHeight,
            max(0, flareHeight)
        )
    }

    private func conventionalTopPanelPath(in rect: CGRect) -> Path {
        let radius = min(
            max(0, bottomCornerRadius),
            rect.width / 2,
            rect.height
        )

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - radius),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }

    private func resolvedBottomRadius(in rect: CGRect, bodyTop: CGFloat) -> CGFloat {
        min(
            max(0, bottomCornerRadius),
            rect.width / 2,
            max(0, rect.maxY - bodyTop) / 2
        )
    }

    private func resolvedOuterTopRadius(
        in rect: CGRect,
        bodyTop: CGFloat,
        availableShoulder: CGFloat
    ) -> CGFloat {
        min(
            max(0, outerTopCornerRadius),
            rect.width / 2,
            max(0, rect.maxY - bodyTop) / 2,
            availableShoulder
        )
    }
}
