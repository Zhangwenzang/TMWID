import SwiftUI
import Tmwid
import AppKit

@main
struct TmwidApp: App {
    @StateObject private var state = AppState()
    @AppStorage("soundEnabled") private var soundEnabled = true
    @AppStorage("bubbleEnabled") private var bubbleEnabled = true
    @State private var watcher: StateFileWatcher?
    @State private var health: HealthChecker?
    @State private var bubble: BubbleWindowController?
    @State private var injector: SettingsInjector?
    @State private var sound: SoundPlayer?

    private let paths = Paths()

    init() {
        // Prevent duplicate instances
        let dominated = NSRunningApplication.runningApplications(
            withBundleIdentifier: Bundle.main.bundleIdentifier ?? "com.tmwid.app"
        ).filter { $0 != NSRunningApplication.current }

        if let existing = dominated.first {
            existing.activate()
            // Exit immediately — another instance is already running
            Darwin.exit(0)
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                state: state,
                onQuit: {
                    try? injector?.uninstall()
                    NSApplication.shared.terminate(nil)
                },
                onBubbleToggle: { enabled in
                    if enabled {
                        bubble?.restoreFromMenuBar()
                    } else {
                        bubble?.minimizeToMenuBar()
                    }
                }
            )
        } label: {
            MenuBarLabel(state: state)
                .task { setupOnce() }
        }
        .menuBarExtraStyle(.menu)
        .onChange(of: state.sessions) { _ in
            sound?.playIfNeeded(
                currentSessions: state.sessions,
                enabled: soundEnabled
            )
            if bubbleEnabled {
                bubble?.showIfNeeded()
            }
        }
    }

    private func setupOnce() {
        let inj = SettingsInjector(paths: paths)
        try? inj.install()
        injector = inj

        let w = StateFileWatcher(directory: paths.stateDir)
        w.onChange = { sessions in
            Task { @MainActor in state.update(with: sessions) }
        }
        w.start()
        watcher = w

        let h = HealthChecker(directory: paths.stateDir)
        h.startPeriodic()
        health = h

        let b = BubbleWindowController(state: state)
        b.onMinimize = {
            bubbleEnabled = false
        }
        bubble = b

        let s = SoundPlayer()
        s.playIfNeeded(currentSessions: state.sessions, enabled: false)
        sound = s
    }
}
