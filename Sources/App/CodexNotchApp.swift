import AppKit
import SwiftUI

@main
struct CodexNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(runtime: appDelegate.runtime)
        } label: {
            MenuBarLabel(runtime: appDelegate.runtime)
        }
        .menuBarExtraStyle(.menu)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let runtime = AppRuntime()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)

        if let request = CompletionScreenPreviewExporter.request(
            from: ProcessInfo.processInfo.arguments
        ) {
            do {
                try CompletionScreenPreviewExporter.export(request: request)
                print("Exported screen celebration preview to \(request.destination.path)")
            } catch {
                fputs("Screen celebration preview export failed: \(error)\n", stderr)
            }
            NSApplication.shared.terminate(nil)
            return
        }

        if let request = DashboardPreviewExporter.request(
            from: ProcessInfo.processInfo.arguments
        ) {
            do {
                try DashboardPreviewExporter.export(
                    store: runtime.store,
                    presentation: request.presentation,
                    includesBackdrop: request.includesBackdrop,
                    celebrationPreviewElapsed: request.celebrationPreviewElapsed,
                    to: request.destination
                )
                print("Exported Codex Notch preview to \(request.destination.path)")
            } catch {
                fputs("Codex Notch preview export failed: \(error)\n", stderr)
            }
            NSApplication.shared.terminate(nil)
            return
        }

        if let destination = DashboardDiagnosticsExporter.destination(
            from: ProcessInfo.processInfo.arguments
        ) {
            Task {
                await runtime.store.refresh()
                do {
                    try DashboardDiagnosticsExporter.export(
                        snapshot: runtime.store.snapshot,
                        to: destination
                    )
                    print("Exported sanitized live summary to \(destination.path)")
                } catch {
                    fputs("Codex Notch summary export failed: \(error)\n", stderr)
                }
                NSApplication.shared.terminate(nil)
            }
            return
        }

        runtime.start()

        if ProcessInfo.processInfo.arguments.contains(
            "--smoke-test-screen-celebration"
        ) {
            Task { @MainActor in
                do {
                    try await Task.sleep(for: .seconds(3))
                } catch {
                    return
                }
                NSApplication.shared.terminate(nil)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        runtime.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

private struct MenuBarLabel: View {
    let runtime: AppRuntime

    var body: some View {
        Image(systemName: symbolName)
            .accessibilityLabel("Codex Notch")
    }

    private var symbolName: String {
        if runtime.store.needsAttentionCount > 0 {
            return "exclamationmark.bubble.fill"
        }
        if runtime.store.activeTaskCount > 0 {
            return "circle.dotted"
        }
        if runtime.store.unverifiedTaskCount > 0 {
            return "questionmark.circle"
        }
        if runtime.store.staleTaskCount > 0 {
            return "clock"
        }
        return "sparkles"
    }
}

private struct MenuBarContent: View {
    let runtime: AppRuntime

    var body: some View {
        Button("Open Dashboard") {
            runtime.showDashboard()
        }
        .keyboardShortcut("o")

        Button("Open Codex") {
            CodexHandoff.openApplication()
        }

        Divider()

        Text(runtime.summaryText)

        Toggle("Privacy Mode", isOn: Binding(
            get: { runtime.store.privacyMode },
            set: { runtime.store.privacyMode = $0 }
        ))

        Toggle("Quiet Mode", isOn: Binding(
            get: { runtime.store.quietMode },
            set: { runtime.store.quietMode = $0 }
        ))

        Button("Refresh Now") {
            Task {
                await runtime.store.refresh()
            }
        }
        .disabled(runtime.store.isRefreshing)

        Divider()

        Button("Quit Codex Notch") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
