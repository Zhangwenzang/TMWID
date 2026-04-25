import SwiftUI
import Tmwid

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

        sound = SoundPlayer()
    }
}
