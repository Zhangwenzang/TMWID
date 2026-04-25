import SwiftUI
import Tmwid

@main
struct TmwidApp: App {
    @StateObject private var state = AppState()
    @State private var watcher: StateFileWatcher?
    @State private var health: HealthChecker?
    @State private var bubble: BubbleWindowController?
    @State private var injector: SettingsInjector?

    private let paths = Paths()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                state: state,
                onQuit: { NSApplication.shared.terminate(nil) },
                onReinject: { try? injector?.install() },
                onUninstall: { try? injector?.uninstall() }
            )
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.menu)
        .onChange(of: state.sessions) { _ in
            bubble?.showIfNeeded()
        }
    }

    private var menuBarLabel: some View {
        Text(labelText)
            .task { setupOnce() }
    }

    private var labelText: String {
        if state.isEmpty { return "\u{1F4A4}" }
        var parts: [String] = []
        if state.workingCount > 0 { parts.append("\u{2699}\(state.workingCount)") }
        if state.askCount > 0     { parts.append("\u{2753}\(state.askCount)") }
        if state.doneCount > 0    { parts.append("\u{2713}\(state.doneCount)") }
        return parts.joined(separator: " ")
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

        bubble = BubbleWindowController(state: state)
    }
}
