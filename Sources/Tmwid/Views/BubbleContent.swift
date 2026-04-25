import SwiftUI

struct BubbleContent: View {
    @ObservedObject var state: AppState

    var body: some View {
        HStack(spacing: 14) {
            if state.workingCount > 0 {
                StatusItemView(kind: .working, count: state.workingCount)
            }
            if state.askCount > 0 {
                StatusItemView(kind: .ask, count: state.askCount)
            }
            if state.doneCount > 0 {
                StatusItemView(kind: .done, count: state.doneCount)
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
    }
}
