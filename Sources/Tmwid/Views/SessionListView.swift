import SwiftUI
import AppKit

struct SessionListView: View {
    let sessions: [SessionState]
    let activator: SessionActivator
    var onSessionTap: ((SessionState) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(sessions, id: \.sessionId) { session in
                SessionRow(session: session, activator: activator, onTap: { onSessionTap?(session) })
            }
        }
        .padding(.top, 8)
    }
}

struct SessionRow: View {
    let session: SessionState
    let activator: SessionActivator
    var onTap: (() -> Void)?
    @State private var appIcon: NSImage?

    var body: some View {
        HStack(spacing: 8) {
            if let icon = appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .cornerRadius(4)
            } else {
                Color.gray.opacity(0.3)
                    .frame(width: 20, height: 20)
                    .cornerRadius(4)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(session.sessionId)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text((session.cwd as NSString).lastPathComponent)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
        .onAppear { appIcon = activator.getAppIcon(for: session.pid) }
    }
}
