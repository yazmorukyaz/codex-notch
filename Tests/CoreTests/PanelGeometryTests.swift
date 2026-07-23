import XCTest
@testable import CodexNotchCore

final class PanelGeometryTests: XCTestCase {
    private let geometry = PanelGeometry()

    func testCompactFrameIncludesCameraSafeAreaAndReveal() {
        let screen = PanelScreenGeometry(
            frame: CGRect(x: 0, y: 0, width: 1_512, height: 982),
            visibleFrame: CGRect(x: 0, y: 0, width: 1_512, height: 944),
            safeAreaInsets: PanelSafeAreaInsets(top: 38),
            auxiliaryTopLeftArea: CGRect(x: 0, y: 944, width: 650, height: 38),
            auxiliaryTopRightArea: CGRect(x: 862, y: 944, width: 650, height: 38)
        )

        let frame = geometry.frame(for: .compact, on: screen)
        let windows = geometry.windowFrames(for: .compact, on: screen)
        let notch = geometry.notchMetrics(on: screen)

        assertRect(frame, equals: CGRect(x: 650, y: 926, width: 212, height: 56))
        XCTAssertEqual(frame.maxY, screen.frame.maxY)
        XCTAssertEqual(geometry.topReservedHeight(on: screen), 38)
        XCTAssertEqual(notch.neckWidth, 212)
        XCTAssertEqual(notch.reservedTopHeight, 38)
        XCTAssertTrue(notch.hasHardwareNotch)
        XCTAssertEqual(frame.height - notch.reservedTopHeight, 18)
        assertRect(
            windows.neckFrame!,
            equals: CGRect(x: 650, y: 944, width: 212, height: 38)
        )
        assertRect(
            windows.bodyFrame,
            equals: CGRect(x: 650, y: 926, width: 212, height: 18)
        )
        XCTAssertEqual(windows.bodyFrame.minX, windows.neckFrame?.minX)
        XCTAssertEqual(windows.bodyFrame.width, windows.neckFrame?.width)
        XCTAssertEqual(windows.bodyFrame.maxY, windows.neckFrame?.minY)
    }

    func testExpandedFrameRemainsCenteredOnNotchedScreen() {
        let screen = PanelScreenGeometry(
            frame: CGRect(x: 0, y: 0, width: 1_512, height: 982),
            visibleFrame: CGRect(x: 0, y: 0, width: 1_512, height: 944),
            safeAreaInsets: PanelSafeAreaInsets(top: 38),
            auxiliaryTopLeftArea: CGRect(x: 0, y: 944, width: 650, height: 38),
            auxiliaryTopRightArea: CGRect(x: 862, y: 944, width: 650, height: 38)
        )

        let frame = geometry.frame(for: .expanded, on: screen)
        let windows = geometry.windowFrames(for: .expanded, on: screen)

        assertRect(frame, equals: CGRect(x: 396, y: 424, width: 720, height: 558))
        assertRect(
            windows.bodyFrame,
            equals: CGRect(x: 396, y: 424, width: 720, height: 520)
        )
        XCTAssertEqual(frame.midX, screen.frame.midX)
        XCTAssertEqual(frame.maxY, screen.frame.maxY)
        XCTAssertEqual(windows.bodyFrame.maxY, 944)
    }

    func testMeasuredExpandedBodyHeightComposesWithReservedNotchHeight() {
        let screen = PanelScreenGeometry(
            frame: CGRect(x: 0, y: 0, width: 1_728, height: 1_117),
            visibleFrame: CGRect(x: 0, y: 0, width: 1_728, height: 1_085),
            safeAreaInsets: PanelSafeAreaInsets(top: 32),
            auxiliaryTopLeftArea: CGRect(x: 0, y: 1_085, width: 771, height: 32),
            auxiliaryTopRightArea: CGRect(x: 956, y: 1_085, width: 772, height: 32)
        )

        let windows = geometry.windowFrames(
            for: .expanded,
            on: screen,
            expandedBodyHeight: 412
        )

        XCTAssertEqual(windows.totalFrame.height, 444)
        XCTAssertEqual(windows.bodyFrame.height, 412)
        XCTAssertEqual(windows.totalFrame.maxY, screen.frame.maxY)
        XCTAssertEqual(windows.bodyFrame.maxY, screen.visibleFrame.maxY)
        XCTAssertEqual(windows.bodyFrame.maxY, windows.neckFrame?.minY)
    }

    func testMeasuredExpandedBodyHeightClampsToConfiguredBounds() {
        let adaptiveGeometry = PanelGeometry(
            metrics: PanelGeometry.Metrics(
                expandedMinimumBodyHeight: 300,
                expandedMaximumBodyHeight: 520
            )
        )
        let screen = PanelScreenGeometry(
            frame: CGRect(x: 0, y: 0, width: 1_728, height: 1_117),
            visibleFrame: CGRect(x: 0, y: 0, width: 1_728, height: 1_085),
            safeAreaInsets: PanelSafeAreaInsets(top: 32),
            auxiliaryTopLeftArea: CGRect(x: 0, y: 1_085, width: 771, height: 32),
            auxiliaryTopRightArea: CGRect(x: 956, y: 1_085, width: 772, height: 32)
        )

        let minimum = adaptiveGeometry.windowFrames(
            for: .expanded,
            on: screen,
            expandedBodyHeight: 120
        )
        let maximum = adaptiveGeometry.windowFrames(
            for: .expanded,
            on: screen,
            expandedBodyHeight: 900
        )

        XCTAssertEqual(minimum.bodyFrame.height, 300)
        XCTAssertEqual(minimum.totalFrame.height, 332)
        XCTAssertEqual(maximum.bodyFrame.height, 520)
        XCTAssertEqual(maximum.totalFrame.height, 552)
        XCTAssertEqual(minimum.totalFrame.maxY, maximum.totalFrame.maxY)
        XCTAssertEqual(minimum.bodyFrame.maxY, maximum.bodyFrame.maxY)
    }

    func testNotchlessDisplayUsesCompactConfiguredHeight() {
        let screen = PanelScreenGeometry(
            frame: CGRect(x: 0, y: 0, width: 1_440, height: 900),
            visibleFrame: CGRect(x: 0, y: 48, width: 1_440, height: 827)
        )

        let frame = geometry.frame(for: .compact, on: screen)
        let windows = geometry.windowFrames(for: .compact, on: screen)
        let notch = geometry.notchMetrics(on: screen)

        assertRect(frame, equals: CGRect(x: 610, y: 857, width: 220, height: 43))
        XCTAssertEqual(geometry.topReservedHeight(on: screen), 25)
        XCTAssertEqual(notch.neckWidth, 0)
        XCTAssertEqual(notch.reservedTopHeight, 25)
        XCTAssertFalse(notch.hasHardwareNotch)
        XCTAssertNil(windows.neckFrame)
        assertRect(
            windows.bodyFrame,
            equals: CGRect(x: 610, y: 857, width: 220, height: 18)
        )
        XCTAssertEqual(windows.bodyFrame.maxY, screen.visibleFrame.maxY)
    }

    func testExternalDisplayWithNegativeOriginUsesGlobalCoordinates() {
        let screen = PanelScreenGeometry(
            frame: CGRect(x: -1_920, y: 0, width: 1_920, height: 1_080),
            visibleFrame: CGRect(x: -1_920, y: 0, width: 1_920, height: 1_055)
        )

        let compactFrame = geometry.frame(for: .compact, on: screen)
        let expandedFrame = geometry.frame(for: .expanded, on: screen)

        assertRect(compactFrame, equals: CGRect(x: -1_070, y: 1_037, width: 220, height: 43))
        assertRect(expandedFrame, equals: CGRect(x: -1_320, y: 535, width: 720, height: 545))
        XCTAssertEqual(compactFrame.midX, screen.frame.midX)
        XCTAssertEqual(expandedFrame.maxY, screen.frame.maxY)
    }

    func testDisplayAbovePrimaryPreservesVerticalOrigin() {
        let screen = PanelScreenGeometry(
            frame: CGRect(x: -2_560, y: 1_080, width: 2_560, height: 1_440),
            visibleFrame: CGRect(x: -2_560, y: 1_080, width: 2_560, height: 1_415)
        )

        let frame = geometry.frame(for: .compact, on: screen)

        assertRect(frame, equals: CGRect(x: -1_390, y: 2_477, width: 220, height: 43))
        XCTAssertEqual(frame.maxY, 2_520)
    }

    func testExpandedFrameClampsToSmallVisibleDisplayArea() {
        let screen = PanelScreenGeometry(
            frame: CGRect(x: 0, y: 0, width: 600, height: 400),
            visibleFrame: CGRect(x: 40, y: 40, width: 560, height: 335)
        )

        let frame = geometry.frame(for: .expanded, on: screen)

        assertRect(frame, equals: CGRect(x: 36, y: 56, width: 528, height: 344))
        XCTAssertEqual(frame.midX, screen.frame.midX)
        XCTAssertGreaterThanOrEqual(frame.minY, screen.visibleFrame.minY)
    }

    func testSafeAreaInsetsConstrainExpandedWidthAndBottom() {
        let screen = PanelScreenGeometry(
            frame: CGRect(x: 100, y: -500, width: 500, height: 400),
            visibleFrame: CGRect(x: 100, y: -480, width: 500, height: 355),
            safeAreaInsets: PanelSafeAreaInsets(top: 30, left: 30, bottom: 40, right: 30)
        )

        let frame = geometry.frame(for: .expanded, on: screen)

        assertRect(frame, equals: CGRect(x: 146, y: -444, width: 408, height: 344))
        XCTAssertEqual(frame.maxY, screen.frame.maxY)
        XCTAssertGreaterThanOrEqual(frame.minY, screen.frame.minY + 40)
    }

    func testSafeAreaWithoutAuxiliaryAreasDoesNotClaimHardwareNotch() {
        let screen = PanelScreenGeometry(
            frame: CGRect(x: 0, y: 0, width: 1_512, height: 982),
            visibleFrame: CGRect(x: 0, y: 0, width: 1_512, height: 944),
            safeAreaInsets: PanelSafeAreaInsets(top: 38)
        )

        let notch = geometry.notchMetrics(on: screen)

        XCTAssertEqual(notch.neckWidth, 0)
        XCTAssertEqual(notch.reservedTopHeight, 38)
        XCTAssertFalse(notch.hasHardwareNotch)
    }

    func testOnlyOneAuxiliaryAreaDoesNotClaimHardwareNotch() {
        let screen = PanelScreenGeometry(
            frame: CGRect(x: 0, y: 0, width: 1_512, height: 982),
            visibleFrame: CGRect(x: 0, y: 0, width: 1_512, height: 944),
            safeAreaInsets: PanelSafeAreaInsets(top: 38),
            auxiliaryTopLeftArea: CGRect(x: 0, y: 944, width: 650, height: 38)
        )

        let notch = geometry.notchMetrics(on: screen)

        XCTAssertEqual(notch.neckWidth, 0)
        XCTAssertEqual(notch.reservedTopHeight, 38)
        XCTAssertFalse(notch.hasHardwareNotch)
    }

    func testHardwareNotchDerivationSupportsNegativeDisplayOrigin() {
        let screen = PanelScreenGeometry(
            frame: CGRect(x: -1_728, y: 0, width: 1_728, height: 1_117),
            visibleFrame: CGRect(x: -1_728, y: 0, width: 1_728, height: 1_079),
            safeAreaInsets: PanelSafeAreaInsets(top: 38),
            auxiliaryTopLeftArea: CGRect(x: -1_728, y: 1_079, width: 748, height: 38),
            auxiliaryTopRightArea: CGRect(x: -748, y: 1_079, width: 748, height: 38)
        )

        let notch = geometry.notchMetrics(on: screen)
        let frame = geometry.frame(for: .compact, on: screen)
        let windows = geometry.windowFrames(for: .compact, on: screen)

        XCTAssertEqual(notch.neckWidth, 232)
        XCTAssertEqual(notch.reservedTopHeight, 38)
        XCTAssertTrue(notch.hasHardwareNotch)
        assertRect(frame, equals: CGRect(x: -980, y: 1_061, width: 232, height: 56))
        assertRect(
            windows.neckFrame!,
            equals: CGRect(x: -980, y: 1_079, width: 232, height: 38)
        )
        assertRect(
            windows.bodyFrame,
            equals: CGRect(x: -980, y: 1_061, width: 232, height: 18)
        )
        XCTAssertEqual(windows.bodyFrame.minX, windows.neckFrame?.minX)
        XCTAssertEqual(windows.bodyFrame.width, windows.neckFrame?.width)
        XCTAssertEqual(windows.bodyFrame.maxY, windows.neckFrame?.minY)
        XCTAssertEqual(frame.midX, screen.frame.midX)
    }

    func testHardwareGapItselfAnchorsFractionalDisplayCenter() {
        let screen = PanelScreenGeometry(
            frame: CGRect(x: 0, y: 0, width: 1_728, height: 1_117),
            visibleFrame: CGRect(x: 0, y: 0, width: 1_728, height: 1_085),
            safeAreaInsets: PanelSafeAreaInsets(top: 32),
            auxiliaryTopLeftArea: CGRect(x: 0, y: 1_085, width: 771, height: 32),
            auxiliaryTopRightArea: CGRect(x: 956, y: 1_085, width: 772, height: 32)
        )

        let frame = geometry.frame(for: .compact, on: screen)
        let windows = geometry.windowFrames(for: .compact, on: screen)

        assertRect(
            frame,
            equals: CGRect(x: 771, y: 1_067, width: 185, height: 50)
        )
        assertRect(
            windows.neckFrame!,
            equals: CGRect(x: 771, y: 1_085, width: 185, height: 32)
        )
        assertRect(
            windows.bodyFrame,
            equals: CGRect(x: 771, y: 1_067, width: 185, height: 18)
        )
        XCTAssertEqual(frame.midX, 863.5)
        XCTAssertEqual(windows.bodyFrame.minX, windows.neckFrame?.minX)
        XCTAssertEqual(windows.bodyFrame.width, windows.neckFrame?.width)
        XCTAssertEqual(windows.bodyFrame.maxY, windows.neckFrame?.minY)
    }

    func testAttentionCompactHeightExpandsOnlyTheBodyBelowHardwareNotch() {
        let screen = PanelScreenGeometry(
            frame: CGRect(x: 0, y: 0, width: 1_728, height: 1_117),
            visibleFrame: CGRect(x: 0, y: 0, width: 1_728, height: 1_085),
            safeAreaInsets: PanelSafeAreaInsets(top: 32),
            auxiliaryTopLeftArea: CGRect(x: 0, y: 1_085, width: 771, height: 32),
            auxiliaryTopRightArea: CGRect(x: 956, y: 1_085, width: 772, height: 32)
        )

        let windows = geometry.windowFrames(
            for: .compact,
            on: screen,
            compactBodyHeight: 54
        )

        XCTAssertEqual(windows.totalFrame.height, 86)
        XCTAssertEqual(windows.neckFrame?.height, 32)
        XCTAssertEqual(windows.bodyFrame.height, 54)
        XCTAssertEqual(windows.bodyFrame.maxY, windows.neckFrame?.minY)
    }

    func testCompactPresenceKeepsQuietStatesDormant() {
        let policy = CompactPanelPresencePolicy()
        let now = Date(timeIntervalSinceReferenceDate: 1_000)

        XCTAssertEqual(
            policy.resolve(
                refreshFailed: false,
                needsAttentionCount: 0,
                workingCount: 0,
                completedActivityDates: [],
                interruptedActivityDates: [],
                now: now
            ),
            .dormant
        )
        XCTAssertFalse(CompactPanelPresence.dormant.isVisible)
    }

    func testCompactPresencePrioritizesUnavailableAttentionAndWorking() {
        let policy = CompactPanelPresencePolicy()
        let now = Date(timeIntervalSinceReferenceDate: 1_000)
        let recentCompletion = now.addingTimeInterval(-1)

        XCTAssertEqual(
            policy.resolve(
                refreshFailed: true,
                needsAttentionCount: 2,
                workingCount: 3,
                completedActivityDates: [recentCompletion],
                interruptedActivityDates: [],
                now: now
            ),
            .unavailable
        )
        XCTAssertEqual(
            policy.resolve(
                refreshFailed: false,
                needsAttentionCount: 2,
                workingCount: 3,
                completedActivityDates: [recentCompletion],
                interruptedActivityDates: [],
                now: now
            ),
            .needsAttention(2)
        )
        XCTAssertEqual(
            policy.resolve(
                refreshFailed: false,
                needsAttentionCount: 0,
                workingCount: 3,
                completedActivityDates: [recentCompletion],
                interruptedActivityDates: [],
                now: now
            ),
            .working(3)
        )
    }

    func testCompactPresenceShowsCompletionOnlyInsideGraceWindow() {
        let policy = CompactPanelPresencePolicy(completionVisibilityDuration: 4)
        let now = Date(timeIntervalSinceReferenceDate: 1_000)

        XCTAssertEqual(
            policy.resolve(
                refreshFailed: false,
                needsAttentionCount: 0,
                workingCount: 0,
                completedActivityDates: [now.addingTimeInterval(-3.999)],
                interruptedActivityDates: [],
                now: now
            ),
            .recentlyFinished(1)
        )
        XCTAssertEqual(
            policy.resolve(
                refreshFailed: false,
                needsAttentionCount: 0,
                workingCount: 0,
                completedActivityDates: [now.addingTimeInterval(-4)],
                interruptedActivityDates: [],
                now: now
            ),
            .dormant
        )
    }

    func testCompactPresenceNaturalSequenceReturnsToDormant() {
        let policy = CompactPanelPresencePolicy(completionVisibilityDuration: 4)
        let startedAt = Date(timeIntervalSinceReferenceDate: 1_000)

        XCTAssertEqual(
            policy.resolve(
                refreshFailed: false,
                needsAttentionCount: 0,
                workingCount: 1,
                completedActivityDates: [],
                interruptedActivityDates: [],
                now: startedAt
            ),
            .working(1)
        )
        XCTAssertEqual(
            policy.resolve(
                refreshFailed: false,
                needsAttentionCount: 1,
                workingCount: 0,
                completedActivityDates: [],
                interruptedActivityDates: [],
                now: startedAt
            ),
            .needsAttention(1)
        )
        XCTAssertEqual(
            policy.resolve(
                refreshFailed: false,
                needsAttentionCount: 0,
                workingCount: 0,
                completedActivityDates: [startedAt],
                interruptedActivityDates: [],
                now: startedAt.addingTimeInterval(1)
            ),
            .recentlyFinished(1)
        )
        XCTAssertEqual(
            policy.resolve(
                refreshFailed: false,
                needsAttentionCount: 0,
                workingCount: 0,
                completedActivityDates: [startedAt],
                interruptedActivityDates: [],
                now: startedAt.addingTimeInterval(4)
            ),
            .dormant
        )
    }

    func testCompactPresenceDoesNotMislabelInterruptedWorkAsFinished() {
        let policy = CompactPanelPresencePolicy(completionVisibilityDuration: 4)
        let now = Date(timeIntervalSinceReferenceDate: 1_000)

        XCTAssertEqual(
            policy.resolve(
                refreshFailed: false,
                needsAttentionCount: 0,
                workingCount: 0,
                completedActivityDates: [],
                interruptedActivityDates: [now.addingTimeInterval(-1)],
                now: now
            ),
            .recentlyInterrupted(1)
        )
    }

    func testCompletionCelebrationOnlyAcceptsRecentActiveToCompletedTransitions() {
        let policy = CompletionCelebrationPolicy()

        XCTAssertTrue(
            policy.shouldCelebrate(
                previousState: .working,
                currentState: .completed,
                isRecent: true
            )
        )
        XCTAssertTrue(
            policy.shouldCelebrate(
                previousState: .needsAttention,
                currentState: .completed,
                isRecent: true
            )
        )
        XCTAssertFalse(
            policy.shouldCelebrate(
                previousState: nil,
                currentState: .completed,
                isRecent: true
            ),
            "A completed task present on launch must not replay a celebration."
        )
        XCTAssertFalse(
            policy.shouldCelebrate(
                previousState: .completed,
                currentState: .completed,
                isRecent: true
            ),
            "Repeated completed snapshots must not restart the animation."
        )
        XCTAssertFalse(
            policy.shouldCelebrate(
                previousState: .working,
                currentState: .interrupted,
                isRecent: true
            )
        )
        XCTAssertFalse(
            policy.shouldCelebrate(
                previousState: .working,
                currentState: .completed,
                isRecent: false
            )
        )
    }

    private func assertRect(
        _ actual: CGRect,
        equals expected: CGRect,
        accuracy: CGFloat = 0.001,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(actual.origin.x, expected.origin.x, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(actual.origin.y, expected.origin.y, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(actual.size.width, expected.size.width, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(actual.size.height, expected.size.height, accuracy: accuracy, file: file, line: line)
    }
}
