import SwiftUI

public struct MenuBarView: View {
    @ObservedObject var state: AppState
    let onQuit: () -> Void
    let onReinject: () -> Void
    let onUninstall: () -> Void

    public init(state: AppState, onQuit: @escaping () -> Void, onReinject: @escaping () -> Void, onUninstall: @escaping () -> Void) {
        self.state = state
        self.onQuit = onQuit
        self.onReinject = onReinject
        self.onUninstall = onUninstall
    }

    public var body: some View {
        VStack(alignment: .leading) {
            if state.isEmpty {
                Text("No active sessions")
            } else {
                if state.workingCount > 0 { Text("Working: \(state.workingCount)") }
                if state.askCount > 0     { Text("Ask: \(state.askCount)") }
                if state.doneCount > 0    { Text("Done: \(state.doneCount)") }
            }
            Divider()
            Button("Re-install hooks", action: onReinject)
            Button("Uninstall hooks", action: onUninstall)
            Divider()
            Button("Quit", action: onQuit)
        }
    }
}
