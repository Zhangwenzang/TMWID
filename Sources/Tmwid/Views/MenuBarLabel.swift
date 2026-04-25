import SwiftUI

public struct MenuBarLabel: View {
    @ObservedObject var state: AppState

    public init(state: AppState) {
        self.state = state
    }

    public var body: some View {
        if state.isEmpty {
            Image(systemName: "hare")
        } else {
            HStack(spacing: 6) {
                if state.workingCount > 0 {
                    StatusItemView(kind: .working, count: state.workingCount, size: 18)
                }
                if state.askCount > 0 {
                    StatusItemView(kind: .ask, count: state.askCount, size: 18)
                }
                if state.doneCount > 0 {
                    StatusItemView(kind: .done, count: state.doneCount, size: 18)
                }
            }
        }
    }
}
