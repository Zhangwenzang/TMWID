import SwiftUI
import AppKit

public struct SessionListView: View {
    let sessions: [SessionState]
    let activator: SessionActivator
    var onTap: ((SessionState) -> Void)?

    public init(sessions: [SessionState], activator: SessionActivator, onTap: ((SessionState) -> Void)? = nil) {
        self.sessions = sessions
        self.activator = activator
        self.onTap = onTap
    }

    public var body: some View {
        VStack(spacing: 1) {
            ForEach(sessions) { session in
                SessionRowView(session: session, activator: activator)
                    .contentShape(Rectangle())
                    .onTapGesture { onTap?(session) }
            }
        }
        .padding(.top, 10)
        .frame(width: 180)
    }
}

struct SessionRowView: View {
    let session: SessionState
    let activator: SessionActivator
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            if let icon = activator.appIcon(for: session.pid) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(session.sessionId)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(projectName(from: session.cwd))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(isHovered ? Color.white.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onHover { hovering in isHovered = hovering }
    }

    private func projectName(from path: String) -> String {
        URL(fileURLWithPath: path).lastPathComponent
    }
}
