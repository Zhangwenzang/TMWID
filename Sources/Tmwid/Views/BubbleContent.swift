import SwiftUI
import AppKit

/// NSVisualEffectView wrapper for behind-window blur.
/// Requires host NSWindow to have .titled styleMask (borderless doesn't support behind-window blending).
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = .active
        v.isEmphasized = true
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

struct BubbleContent: View {
    @ObservedObject var state: AppState
    var onMinimize: (() -> Void)?
    var onStatusTap: ((StatusKind) -> Void)?
    var onSessionTap: ((SessionState) -> Void)?
    var onHover: (() -> Void)?
    var onSizeChange: (() -> Void)?
    var activator: SessionActivator?
    @State private var isHovered = false
    @State private var isButtonHovered = false
    @State private var expandedStatus: StatusKind?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 14) {
                    if state.workingCount > 0 {
                        StatusItemView(kind: .working, count: state.workingCount, onTap: {
                            onStatusTap?(.working)
                        }, onHover: { hovering in
                            if hovering { expandedStatus = .working }
                        })
                    }
                    if state.askCount > 0 {
                        StatusItemView(kind: .ask, count: state.askCount, onTap: {
                            onStatusTap?(.ask)
                        }, onHover: { hovering in
                            if hovering { expandedStatus = .ask }
                        })
                    }
                    if state.doneCount > 0 {
                        StatusItemView(kind: .done, count: state.doneCount, onTap: {
                            onStatusTap?(.done)
                        }, onHover: { hovering in
                            if hovering { expandedStatus = .done }
                        })
                    }
                    if state.apiErrCount > 0 {
                        StatusItemView(kind: .apiErr, count: state.apiErrCount, onTap: {
                            onStatusTap?(.apiErr)
                        }, onHover: { hovering in
                            if hovering { expandedStatus = .apiErr }
                        })
                    }
                }

                if let status = expandedStatus, let activator = activator {
                    Divider()
                        .background(Color.white.opacity(0.1))
                        .padding(.top, 10)

                    SessionListView(
                        sessions: state.sessions(for: status),
                        activator: activator,
                        onTap: { session in onSessionTap?(session) }
                    )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                ZStack {
                    VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                    Color(red: 30/255, green: 30/255, blue: 40/255).opacity(0.45)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .onChange(of: expandedStatus) { _ in
                onSizeChange?()
            }

            // Minimize button — top-right of the bubble
            Button(action: { onMinimize?() }) {
                Text("\u{2212}")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .frame(width: 22, height: 22)
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
            .onHover { hovering in isButtonHovered = hovering }
            .opacity(isHovered ? 1 : 0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .padding(.top, 2)
            .padding(.trailing, 2)
        }
        .onHover { hovering in
            isHovered = hovering
            if hovering { onHover?() }
            if !hovering { expandedStatus = nil }
        }
    }
}
