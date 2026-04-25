import SwiftUI

struct BubbleContent: View {
    @ObservedObject var state: AppState
    var onMinimize: (() -> Void)?
    @State private var isHovered = false
    @State private var isButtonHovered = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
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
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            // Minimize button - visible on hover
            Button(action: { onMinimize?() }) {
                Text("\u{2212}") // minus sign
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 20, height: 20)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(isButtonHovered ? 0.25 : 0.15))
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isButtonHovered = hovering
            }
            .opacity(isHovered ? 1 : 0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .padding(.top, 4)
            .padding(.trailing, 4)
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
