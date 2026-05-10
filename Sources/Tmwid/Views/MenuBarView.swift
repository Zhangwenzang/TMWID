import SwiftUI

public struct MenuBarView: View {
    @ObservedObject var state: AppState
    @AppStorage("soundEnabled") var soundEnabled = true
    @AppStorage("bubbleEnabled") var bubbleEnabled = true
    let onQuit: () -> Void
    let onBubbleToggle: (Bool) -> Void

    public init(
        state: AppState,
        onQuit: @escaping () -> Void,
        onBubbleToggle: @escaping (Bool) -> Void
    ) {
        self.state = state
        self.onQuit = onQuit
        self.onBubbleToggle = onBubbleToggle
    }

    public var body: some View {
        VStack(alignment: .leading) {
            if state.isEmpty {
                Text("暂无活跃会话")
            } else {
                if state.workingCount > 0 { Text("工作中: \(state.workingCount)") }
                if state.askCount > 0     { Text("举手中: \(state.askCount)") }
                if state.doneCount > 0    { Text("摸鱼中: \(state.doneCount)") }
                if state.apiErrCount > 0  { Text("接口异常: \(state.apiErrCount)") }
            }
            Divider()
            Toggle("声音", isOn: $soundEnabled)
            Toggle("浮窗", isOn: $bubbleEnabled)
                .onChange(of: bubbleEnabled) { newValue in
                    onBubbleToggle(newValue)
                }
            Divider()
            Button("退出", action: onQuit)
        }
    }
}
